-- Addon object, saved data and helpers that read the client.
local ADDON_NAME, ns = ...
local Util = ns.Util

local addon = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")
ns.addon = addon

ns.DEFAULTS = {
	profile = {
		minimap = { hide = false },
		sound = true,
		debug = false,
		firstRunShown = false,
		point = nil,
	},
	char = {
		duty = false,
		prices = {},
		disabled = {},
		pay = "A",
		helpers = true,
		deals = {},
		pendingReports = {},
	},
	global = {
		realms = {},
	},
}

ns.Usable = Util.Usable

function ns.Print(...)
	print("|cffffb21aPortaxi|r", ...)
end

function ns.Debug(...)
	if ns.db and ns.db.profile.debug then
		print("|cffffb21aPortaxi|r", ...)
	end
end

-- Per realm storage: ledger, live bans, reports received by an admin.
function ns.RealmData()
	local realm = GetRealmName() or "?"
	local realms = ns.db.global.realms
	local data = realms[realm]
	if not data then
		data = { ledger = ns.Ledger.New(), bans = { version = 0, list = {} }, reports = {} }
		realms[realm] = data
	end
	return data
end

function ns.Now()
	return GetServerTime()
end

function ns.Faction()
	return UnitFactionGroup("player") == "Horde" and "H" or "A"
end

function ns.InInstance()
	local inInstance = IsInInstance()
	return inInstance and true or false
end

-- Forever names are "Given Family" and unique per region; other clients use "Name-Realm".
function ns.QualifiedUnitName(unit)
	local getName = UnitNameUnmodified or UnitName
	local name, qualifier = getName(unit)
	if not Util.Usable(name) or name == "" then
		return nil
	end
	if Util.Usable(qualifier) and qualifier ~= "" and not name:find(" ", 1, true) then
		local regional = RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()
		return name .. (regional and " " or "-") .. qualifier
	end
	return name
end

function ns.MyName()
	return ns.QualifiedUnitName("player")
end

function ns.MyKey()
	return Util.NameKey(ns.MyName())
end

-- "M" mage, "W" warlock, nil for every other class.
function ns.ProviderClass()
	local _, class = UnitClass("player")
	if class == "MAGE" then
		return "M"
	elseif class == "WARLOCK" then
		return "W"
	end
	return nil
end

-- Zone-level map name and id of a unit: caves and sub-maps roll up to their zone, so the player,
-- group members and offers all name a place the same way.
function ns.UnitZone(unit)
	local mapID = C_Map.GetBestMapForUnit(unit)
	if not Util.Usable(mapID) or not mapID then
		return nil
	end
	local info = C_Map.GetMapInfo(mapID)
	local guard = 0
	while info and info.mapType and info.mapType > Enum.UIMapType.Zone and info.parentMapID and info.parentMapID ~= 0 and guard < 8 do
		local parent = C_Map.GetMapInfo(info.parentMapID)
		if not parent then
			break
		end
		mapID = info.parentMapID
		info = parent
		guard = guard + 1
	end
	if not info then
		return nil
	end
	return info.name, mapID
end

-- Player's zone name, subzone name and zone map id.
function ns.Zone()
	local zone, zoneID = ns.UnitZone("player")
	if not zone or zone == "" then
		zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
	end
	local sub = GetSubZoneText() or ""
	if not Util.Usable(zone) then
		zone = ""
	end
	if not Util.Usable(sub) or sub == zone then
		sub = ""
	end
	return zone, sub, zoneID
end

function ns.SpellName(spellID)
	if C_Spell and C_Spell.GetSpellName then
		local name = C_Spell.GetSpellName(spellID)
		if name then
			return name
		end
	end
	if GetSpellInfo then
		return (GetSpellInfo(spellID))
	end
	return nil
end

function ns.KnowsSpell(spellID)
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		return C_SpellBook.IsSpellKnown(spellID) and true or false
	end
	return IsSpellKnown and IsSpellKnown(spellID) and true or false
end

function ns.ItemCount(itemID)
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(itemID) or 0
	end
	return GetItemCount and GetItemCount(itemID) or 0
end

-- Shared start of the known portal names up to its last space ("Portal: "); nil when the client words them differently.
function ns.PortalPrefix()
	local prefix, count = nil, 0
	for code in pairs(ns.DESTS) do
		local name = ns.SpellName(ns.DestSpell(code))
		if name then
			count = count + 1
			if not prefix then
				prefix = name
			else
				local length = 0
				while length < #prefix and prefix:byte(length + 1) == name:byte(length + 1) do
					length = length + 1
				end
				prefix = prefix:sub(1, length)
			end
		end
	end
	return count >= 2 and prefix and prefix:match("^(.*%s)") or nil
end

function ns.SpellIcon(spellID)
	if C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(spellID)
	end
	return GetSpellTexture and GetSpellTexture(spellID) or nil
end

-- Portal spell of a destination code for the player's faction: a known portal or "S<spellID>".
function ns.DestSpell(code)
	local dest = ns.DESTS[code]
	if dest then
		return type(dest.spell) == "table" and dest.spell[ns.Faction() or "A"] or dest.spell
	end
	return tonumber(code:match("^S(%d+)$"))
end

-- City name: known portals in the window language, other portals from the spell name.
function ns.DestName(code)
	if ns.DESTS[code] then
		return ns.L["DEST_" .. code]
	end
	local spellID = ns.DestSpell(code)
	local name = spellID and ns.SpellName(spellID)
	if not name then
		return code
	end
	local prefix = ns.PortalPrefix()
	if prefix and #name > #prefix and name:sub(1, #prefix) == prefix then
		return name:sub(#prefix + 1)
	end
	return name
end

-- A code another player may offer: a summon, a portal of this client's table, or another spell named like the portals.
function ns.IsOfferCode(code)
	if code == "*" or ns.DESTS[code] then
		return true
	end
	local spellID = ns.DestSpell(code)
	for known in pairs(ns.DESTS) do
		if ns.DestSpell(known) == spellID then
			return false
		end
	end
	local name, prefix = spellID and ns.SpellName(spellID), ns.PortalPrefix()
	return name ~= nil and prefix ~= nil and #name > #prefix and name:sub(1, #prefix) == prefix
end

-- Portal arrival check: "Stormwind City" contains "Stormwind"; compared in lower case both ways.
function ns.SamePlace(zone, dest)
	if not (Util.Usable(zone) and zone ~= "" and dest and dest ~= "") then
		return false
	end
	local a, b = Util.Lower(zone), Util.Lower(dest)
	return a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil
end

-- At a portal destination: known portals by the zone map id, other portals by name.
function ns.AtDest(code, zone, zoneID)
	local dest = ns.DESTS[code]
	if dest then
		return zoneID ~= nil and zoneID == dest.map
	end
	return ns.SamePlace(zone, ns.DestName(code))
end

-- Same zone: by map id when both sides have one (zone names follow each client's language), else by name.
function ns.SameZone(zoneA, idA, zoneB, idB)
	if idA and idB then
		return idA == idB
	end
	return ns.SamePlace(zoneA, zoneB)
end

-- Unit token of a group member by name, or nil.
function ns.GroupUnit(name)
	for index = 1, 4 do
		local unit = "party" .. index
		if UnitExists(unit) and Util.SameName(ns.QualifiedUnitName(unit), name) then
			return unit
		end
	end
	if IsInRaid() then
		for index = 1, 40 do
			local unit = "raid" .. index
			if UnitExists(unit) and Util.SameName(ns.QualifiedUnitName(unit), name) then
				return unit
			end
		end
	end
	return nil
end

function ns.Money(copper)
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
		return C_CurrencyInfo.GetCoinTextureString(copper)
	end
	local gold, silver = Util.Coins(copper)
	return silver > 0 and (gold .. "g " .. silver .. "s") or (gold .. "g")
end

function ns.PlayAlert()
	if ns.db.profile.sound and PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then
		PlaySound(SOUNDKIT.READY_CHECK, "Master")
	end
end
