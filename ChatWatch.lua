-- Portal and summon requests in public chat, for mages and warlocks on duty.
local _, ns = ...
local Util = ns.Util

local ChatWatch = {}
ns.ChatWatch = ChatWatch

ChatWatch.TTL = 120
ChatWatch.MAX = 6

-- Words of a message: runs of ASCII letters and digits or of UTF-8 multibyte characters.
local function tokens(text)
	local list = {}
	for word in text:gmatch("[%w\128-\255]+") do
		list[#list + 1] = word
	end
	return list
end

local function matches(word, pattern)
	if pattern:sub(-1) == "*" then
		local stem = pattern:sub(1, -2)
		return word:sub(1, #stem) == stem
	end
	return word == pattern
end

local function any(words, patterns)
	for _, word in ipairs(words) do
		for _, pattern in ipairs(patterns) do
			if matches(word, pattern) then
				return true
			end
		end
	end
	return false
end

-- Returns { kind = "P" or "S", code = destination or nil } or nil.
function ChatWatch.Parse(text, words)
	if not Util.Usable(text) or type(text) ~= "string" or text == "" then
		return nil
	end
	words = words or ns.WORDS
	local original = tokens(text)
	local lower = tokens(Util.Lower(text))
	if any(lower, words.sell) then
		return nil
	end
	local kind
	if any(lower, words.portal) then
		kind = "P"
	elseif any(lower, words.summon) then
		kind = "S"
	else
		return nil
	end
	local code
	if kind == "P" then
		for dest, patterns in pairs(words.dest) do
			if any(lower, patterns) then
				code = dest
				break
			end
		end
		if not code then
			for dest, patterns in pairs(words.destUpper) do
				if any(original, patterns) then
					code = dest
					break
				end
			end
		end
	end
	return { kind = kind, code = code }
end

-- Keeps the newest request per player, newest first, at most MAX. cls is the sender's class file, if known.
function ChatWatch.Add(list, sender, parsed, text, channel, now, cls)
	for index = #list, 1, -1 do
		if Util.SameName(list[index].sender, sender) then
			table.remove(list, index)
		end
	end
	table.insert(list, 1, { sender = sender, kind = parsed.kind, code = parsed.code, text = text, channel = channel, at = now, cls = cls })
	while #list > ChatWatch.MAX do
		list[#list] = nil
	end
end

function ChatWatch.Expire(list, now)
	for index = #list, 1, -1 do
		if now - list[index].at > ChatWatch.TTL then
			table.remove(list, index)
		end
	end
end

function ChatWatch.Remove(list, sender)
	for index = #list, 1, -1 do
		if Util.SameName(list[index].sender, sender) then
			table.remove(list, index)
		end
	end
end
