-- Interface language: English or Russian whatever the client speaks, chosen in the window.
-- Plural forms are resolved here, the client would pick them by its own language.
local _, ns = ...

ns.LOCALES = {}
ns.LANGUAGES = { "enUS", "ruRU" }
local current = "enUS"

ns.L = setmetatable({}, {
	__index = function(_, key)
		local value = ns.LOCALES[current][key]
		if value == nil then
			value = ns.LOCALES.enUS[key]
		end
		return value or key
	end,
})

function ns.Language()
	return current
end

function ns.SetLanguage(code)
	if ns.LOCALES[code] then
		current = code
	end
end

function ns.DefaultLanguage()
	return GetLocale() == "ruRU" and "ruRU" or "enUS"
end

local function pick(count, forms)
	if current == "ruRU" and #forms >= 3 then
		local tens, last = count % 100, count % 10
		if last == 1 and tens ~= 11 then
			return forms[1]
		elseif last >= 2 and last <= 4 and (tens < 12 or tens > 14) then
			return forms[2]
		end
		return forms[3]
	end
	return count == 1 and forms[1] or (forms[2] or forms[1])
end

-- L[key] formatted; every "|4one:few:many;" takes the form for the number right before it.
function ns.Format(key, ...)
	local text = ns.L[key]:format(...)
	return (text:gsub("(%d+)(%s*)|4([^;]*);", function(number, space, list)
		local forms = {}
		for form in (list .. ":"):gmatch("([^:]*):") do
			forms[#forms + 1] = form
		end
		return number .. space .. pick(tonumber(number), forms)
	end))
end
