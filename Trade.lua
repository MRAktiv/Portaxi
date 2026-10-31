-- Finished trades by money: the balance moved by exactly what the window showed. Works in every
-- client language, with no reliance on the "trade complete" message text.
local _, ns = ...
local addon = ns.addon

local Trade = addon:NewModule("Trade", "AceEvent-3.0")
ns.Trade = Trade

local SETTLE = 10

function Trade:OnEnable()
	self:RegisterEvent("TRADE_SHOW")
	self:RegisterEvent("TRADE_CLOSED")
	self:RegisterEvent("PLAYER_MONEY")
	for _, event in ipairs({ "TRADE_MONEY_CHANGED", "PLAYER_TRADE_MONEY", "TRADE_ACCEPT_UPDATE", "TRADE_UPDATE" }) do
		self:RegisterEvent(event, "Snapshot")
	end
end

function Trade:TRADE_SHOW()
	self.session = { partner = ns.QualifiedUnitName("NPC"), before = GetMoney(), give = 0, get = 0, open = true }
	self:SendMessage("PORTAXI_TRADE_OPEN", self.session.partner)
end

function Trade:Snapshot()
	local session = self.session
	if session and session.open then
		session.give = GetPlayerTradeMoney() or 0
		session.get = GetTargetTradeMoney() or 0
	end
end

function Trade:TRADE_CLOSED()
	local session = self.session
	if session and session.open then
		session.open, session.closedAt = false, GetTime()
	end
end

function Trade:PLAYER_MONEY()
	local session = self.session
	if not session or not session.partner or session.give == session.get then
		return
	end
	if not session.open and GetTime() - session.closedAt > SETTLE then
		self.session = nil
		return
	end
	if GetMoney() - session.before == session.get - session.give then
		self.session = nil
		self:SendMessage("PORTAXI_TRADE_DONE", session.partner, session.give, session.get)
	end
end
