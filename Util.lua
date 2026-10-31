-- Pure helpers shared by every module: names, text, money. No client calls here.
local _, ns = ...

local Util = {}
ns.Util = Util

-- Secret values arrive from restricted APIs; treat them as missing data.
local issecret = issecretvalue or function()
	return false
end

function Util.Usable(value)
	return value ~= nil and not issecret(value)
end

-- Plain split that keeps empty fields: "a~~b" gives "a", "", "b".
function Util.Split(text, sep)
	local out, start = {}, 1
	while true do
		local index = text:find(sep, start, true)
		if not index then
			out[#out + 1] = text:sub(start)
			return out
		end
		out[#out + 1] = text:sub(start, index - 1)
		start = index + #sep
	end
end

-- Lower case for ASCII and Cyrillic in UTF-8; string.lower leaves Cyrillic as is.
function Util.Lower(text)
	text = text:lower()
	text = text:gsub("\208([\144-\175])", function(byte)
		local code = byte:byte()
		if code < 160 then
			return "\208" .. string.char(code + 32)
		end
		return "\209" .. string.char(code - 32)
	end)
	text = text:gsub("\208\129", "\209\145")
	return text
end

-- Upper case for ASCII and Cyrillic in UTF-8; the board writes places in capitals.
function Util.Upper(text)
	text = text:upper()
	text = text:gsub("\208([\176-\191])", function(byte)
		return "\208" .. string.char(byte:byte() - 32)
	end)
	text = text:gsub("\209([\128-\143])", function(byte)
		return "\208" .. string.char(byte:byte() + 32)
	end)
	text = text:gsub("\209\145", "\208\129")
	return text
end

-- How names compare. Forever names are "Given Family", unique per region: "Ana Forever", "Ana-Forever" and
-- "anaforever" are one player. Other clients write "Name-Realm" and drop the realm for their own realm.
function Util.SetNames(regional, realm)
	Util.regionalNames = regional and true or false
	Util.realmKey = Util.Usable(realm) and realm and Util.Lower((tostring(realm):gsub("[%s%-]", ""))) or nil
end
Util.SetNames(RegionalUniqueNamesEnabled ~= nil, GetRealmName and GetRealmName())

-- Lower case without spaces; Forever drops dashes too, other clients drop only their own realm.
function Util.NameKey(name)
	if not Util.Usable(name) or name == "" then
		return nil
	end
	name = tostring(name)
	if Util.regionalNames then
		return Util.Lower((name:gsub("[%s%-]", "")))
	end
	local base, realm = name:match("^(.-)%-(.+)$")
	if base and base ~= "" and Util.realmKey and Util.Lower((realm:gsub("[%s%-]", ""))) == Util.realmKey then
		name = base
	end
	return Util.Lower((name:gsub("%s", "")))
end

function Util.SameName(a, b)
	local ka, kb = Util.NameKey(a), Util.NameKey(b)
	return ka ~= nil and ka == kb
end

-- Removes the field separators of the protocol from free text.
function Util.Field(value)
	return (tostring(value or ""):gsub("[~;\n\r]", " "))
end

-- Random id from letters and digits; deal ids and query ids.
local ALPHABET = "abcdefghijkmnpqrstuvwxyz23456789"
function Util.NewID(length, random)
	random = random or math.random
	local out = {}
	for index = 1, length do
		local pick = random(1, #ALPHABET)
		out[index] = ALPHABET:sub(pick, pick)
	end
	return table.concat(out)
end

-- Gold, silver and copper parts of a copper amount.
function Util.Coins(copper)
	copper = math.max(0, math.floor(copper or 0))
	return math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
end

function Util.Count(map)
	local count = 0
	for _ in pairs(map or {}) do
		count = count + 1
	end
	return count
end
