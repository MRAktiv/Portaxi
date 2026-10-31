-- "My run": what a mage or warlock on duty offers, sent to the channel every minute and on changes.
local _, ns = ...
local addon, Proto = ns.addon, ns.Proto

local Duty = addon:NewModule("Duty", "AceEvent-3.0", "AceTimer-3.0")
ns.Duty = Duty

local OFFER_EVERY = 60
local CHANGE_DELAY = 2
Duty.DEFAULT_PRICE = 50000

function Duty:OnEnable()
	for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "SPELLS_CHANGED", "PLAYER_LEVEL_UP" }) do
		self:RegisterEvent(event, "Changed")
	end
	self:ScheduleRepeatingTimer("Tick", OFFER_EVERY)
end

local function spellBookEntry(index)
	if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
		local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
		local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, bank)
		if ok and type(info) == "table" then
			return info.spellID or info.actionID
		end
		return nil
	end
	if GetSpellBookItemInfo then
		local ok, _, spellID = pcall(GetSpellBookItemInfo, index, BOOKTYPE_SPELL or "spell")
		return ok and spellID or nil
	end
	return nil
end

-- Portals beyond the known ones: spells whose name starts like the client's own portal names.
function Duty:ExtraPortals()
	local prefix = ns.PortalPrefix()
	if not prefix then
		return {}
	end
	local known = {}
	for _, dest in pairs(ns.DESTS) do
		for _, spellID in pairs(type(dest.spell) == "table" and dest.spell or { dest.spell }) do
			known[spellID] = true
		end
	end
	local list, empty = {}, 0
	for index = 1, 500 do
		local spellID = spellBookEntry(index)
		if not spellID then
			empty = empty + 1
			if empty >= 30 then
				break
			end
		else
			empty = 0
			local name = not known[spellID] and ns.SpellName(spellID)
			if name and #name > #prefix and name:sub(1, #prefix) == prefix then
				list[#list + 1] = spellID
				known[spellID] = true
			end
		end
	end
	return list
end

-- Codes this character can serve: known portals it learned, other portals, or "*" for a warlock.
function Duty:Codes()
	local class = ns.ProviderClass()
	if class == "W" then
		return ns.KnowsSpell(ns.SUMMON_SPELL) and { "*" } or {}
	elseif class ~= "M" then
		return {}
	end
	local list = {}
	for _, code in ipairs(ns.DEST_ORDER[ns.Faction()]) do
		if ns.KnowsSpell(ns.DestSpell(code)) then
			list[#list + 1] = code
		end
	end
	for _, spellID in ipairs(self:ExtraPortals()) do
		list[#list + 1] = "S" .. spellID
	end
	return list
end

function Duty:Price(code)
	return ns.db.char.prices[code] or Duty.DEFAULT_PRICE
end

function Duty:SetPrice(code, copper)
	ns.db.char.prices[code] = math.max(1, math.floor(copper))
	self:Changed()
end

function Duty:Enabled(code)
	return not ns.db.char.disabled[code]
end

function Duty:SetEnabled(code, enabled)
	ns.db.char.disabled[code] = not enabled or nil
	self:Changed()
end

function Duty:SetPay(pay)
	ns.db.char.pay = pay
	self:Changed()
end

function Duty:SetHelpers(value)
	ns.db.char.helpers = value
	self:Changed()
end

function Duty:OnDuty()
	return ns.db.char.duty and ns.ProviderClass() ~= nil
end

-- Nil when there is nothing to offer: wrong class, no learned spell, everything switched off.
function Duty:BuildOffer()
	local class = ns.ProviderClass()
	if not class then
		return nil
	end
	local items = {}
	for _, code in ipairs(self:Codes()) do
		if self:Enabled(code) then
			items[#items + 1] = { code = code, price = self:Price(code) }
		end
	end
	if #items == 0 then
		return nil
	end
	local zone, sub, zoneID = ns.Zone()
	if zone == "" then
		return nil
	end
	return {
		cls = class, fac = ns.Faction(), level = UnitLevel("player"), zone = zone, sub = sub, map = zoneID,
		pay = ns.db.char.pay, helpers = class == "W" and ns.db.char.helpers or false, items = items,
	}
end

function Duty:SetDuty(value)
	ns.db.char.duty = value and true or false
	if value then
		ns.db.char.runTrips, ns.db.char.runEarned = 0, 0
		self:SendOffer()
	else
		ns.Net:Broadcast(Proto.EncodeOff())
	end
	self:SendMessage("PORTAXI_DUTY")
end

function Duty:SendOffer()
	if not self:OnDuty() then
		return false
	end
	local offer = self:BuildOffer()
	if not offer then
		return false
	end
	self.lastOffer = offer
	return ns.Net:Broadcast(Proto.EncodeOffer(offer))
end

function Duty:Tick()
	self:SendOffer()
end

-- Price, zone or spell changes go out after a short pause so a burst of events sends one offer.
function Duty:Changed()
	if self.changeTimer then
		self:CancelTimer(self.changeTimer)
	end
	self.changeTimer = self:ScheduleTimer(function()
		self.changeTimer = nil
		self:SendOffer()
		self:SendMessage("PORTAXI_DUTY")
	end, CHANGE_DELAY)
end

function Duty:Reagents()
	local class = ns.ProviderClass()
	if class == "M" then
		return ns.ItemCount(ns.PORTAL_RUNE)
	elseif class == "W" then
		return ns.ItemCount(ns.SOUL_SHARD)
	end
	return nil
end

-- Asks the group for two clickers; a party message needs the player's click.
function Duty:CallHelpers()
	if not IsInGroup() then
		ns.Print(ns.L["HELPERS_NO_GROUP"])
		return
	end
	local zone, sub = ns.Zone()
	local text = ns.L["HELPERS_TEXT"]:format(sub ~= "" and sub or zone)
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	pcall(send, text, IsInRaid() and "RAID" or "PARTY")
end
