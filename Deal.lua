-- One trip from both sides. Buyer: order, answer, invite, arrival, payment. Provider: request,
-- accept and invite, delivery seen on the buyer's zone, payment. Each side confirms its own half.
local _, ns = ...
local addon, Util, Proto = ns.addon, ns.Util, ns.Proto

local Deal = addon:NewModule("Deal", "AceEvent-3.0", "AceTimer-3.0")
ns.Deal = Deal

Deal.ANSWER_WAIT = 30
Deal.INVITE_WAIT = 120
Deal.TTL = 20 * 60
Deal.SUMMON_ARRIVE = 300
Deal.DONE_KEEP = 300
Deal.MAX_INCOMING = 5
local POLL = 2

Deal.sales = {}

function Deal:OnEnable()
	self:RegisterEvent("PARTY_INVITE_REQUEST", "OnInvite")
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRoster")
	self:RegisterEvent("CONFIRM_SUMMON", "OnSummon")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Check")
	self:RegisterEvent("ZONE_CHANGED", "Check")
	self:RegisterMessage("PORTAXI_TRADE_DONE", "OnTrade")
	self:ScheduleRepeatingTimer("Poll", POLL)
end

-- Summon popups name the warlock; some clients give only the first part of "Given Family".
local function sameOrFirst(short, full)
	if Util.SameName(short, full) then
		return true
	end
	local first = Util.Usable(full) and full:match("^(%S+) ")
	return first ~= nil and Util.SameName(short, first)
end

-- Buyer side ---------------------------------------------------------------------------------

function Deal:SetBuy(state)
	self.buy.state = state
	self.buy.changed = GetTime()
	self:SendMessage("PORTAXI_BUY")
end

-- provider: board entry (name, price, zone, sub, pay); code: destination or "*"; alternatives: next in line.
function Deal:Order(provider, code, alternatives)
	if self.buy and self.buy.state ~= "done" then
		self:Cancel()
	end
	local zone, sub = ns.Zone()
	local buy = {
		deal = Util.NewID(8), provider = provider.name, code = code, kind = code == "*" and "S" or "P", price = provider.price,
		pay = provider.pay, pzone = provider.zone, pmap = provider.map, psub = provider.sub, paid = 0, since = GetTime(), alternatives = alternatives or {},
	}
	self.buy = buy
	ns.Net:Whisper(provider.name, Proto.EncodeRequest({ deal = buy.deal, code = code, price = buy.price, level = UnitLevel("player"), zone = zone, sub = sub, cls = select(2, UnitClass("player")) }))
	self:ScheduleTimer(function()
		if self.buy == buy and buy.state == "sent" then
			self:SetBuy("noanswer")
		end
	end, Deal.ANSWER_WAIT)
	self:SetBuy("sent")
	return buy
end

function Deal:OrderNext()
	local buy = self.buy
	local nextOne = buy and table.remove(buy.alternatives, 1)
	if nextOne then
		self:Order(nextOne, buy.code, buy.alternatives)
	end
	return nextOne
end

function Deal:Cancel()
	local buy = self.buy
	if not buy then
		return
	end
	if buy.state ~= "done" then
		ns.Net:Whisper(buy.provider, Proto.EncodeAnswer("Z", buy.deal))
	end
	self.buy = nil
	self:SendMessage("PORTAXI_BUY")
end

function Deal:OnInvite(_, name)
	local buy = self.buy
	if buy and buy.state == "accepted" and Util.Usable(name) and sameOrFirst(name, buy.provider) and GetTime() - buy.changed <= Deal.INVITE_WAIT then
		AcceptGroup()
		StaticPopup_Hide("PARTY_INVITE")
	end
end

function Deal:OnSummon()
	local buy = self.buy
	if not buy or buy.kind ~= "S" or not C_SummonInfo then
		return
	end
	local summoner = C_SummonInfo.GetSummonConfirmSummoner()
	if Util.Usable(summoner) and summoner and sameOrFirst(summoner, buy.provider) then
		buy.summoned = GetTime()
		self:SendMessage("PORTAXI_BUY")
	end
end

function Deal:CheckBuy()
	local buy = self.buy
	if not buy or buy.state ~= "grouped" then
		return
	end
	if not buy.arrived then
		local zone, _, zoneID = ns.Zone()
		if buy.kind == "P" then
			buy.arrived = ns.AtDest(buy.code, zone, zoneID) and not ns.AtDest(buy.code, buy.startZone, buy.startZoneID)
		else
			buy.arrived = buy.summoned ~= nil and GetTime() - buy.summoned <= Deal.SUMMON_ARRIVE and ns.SameZone(zone, zoneID, buy.pzone, buy.pmap)
				and not ns.SameZone(buy.startZone, buy.startZoneID, buy.pzone, buy.pmap)
		end
		if buy.arrived then
			self:SendMessage("PORTAXI_BUY")
		end
	end
	if buy.arrived and buy.paid >= buy.price then
		ns.Net:SendConfirm({
			deal = buy.deal, role = "B", provider = buy.provider, buyer = ns.MyName(), kind = buy.kind, code = buy.code, price = buy.price,
			paid = buy.paid, blevel = UnitLevel("player"), time = ns.Now(),
		})
		ns.db.char.deals[buy.deal] = { provider = buy.provider, code = buy.code, kind = buy.kind, price = buy.price, time = ns.Now() }
		self:SetBuy("done")
	end
end

-- Pending rating: the newest finished purchase of the last day without stars.
function Deal:Unrated()
	local best, bestDeal
	for deal, entry in pairs(ns.db.char.deals) do
		if not entry.rated and ns.Now() - entry.time <= ns.Ledger.REVIEW_SPAN and (not best or entry.time > best.time) then
			best, bestDeal = entry, deal
		end
	end
	return bestDeal, best
end

function Deal:Rate(deal, stars, tags)
	local entry = ns.db.char.deals[deal]
	if not entry or entry.rated then
		return false
	end
	entry.rated, entry.stars, entry.tags = true, stars, tags or 0
	ns.Net:SendReview(deal, stars, tags)
	if self.buy and self.buy.deal == deal then
		self.buy = nil
	end
	self:SendMessage("PORTAXI_BUY")
	return true
end

function Deal:Later()
	if self.buy and self.buy.state == "done" then
		self.buy = nil
		self:SendMessage("PORTAXI_BUY")
	end
end

-- Provider side ------------------------------------------------------------------------------

local function offered(code)
	for _, known in ipairs(ns.Duty:Codes()) do
		if known == code then
			return ns.Duty:Enabled(code)
		end
	end
	return false
end

-- One waiting order per player: a new one replaces his last, so one player cannot fill every slot.
function Deal:OnRequest(sender, request)
	if self.sales[request.deal] then
		return
	end
	for deal, sale in pairs(self.sales) do
		if sale.state == "incoming" and Util.SameName(sale.buyer, sender) then
			self.sales[deal] = nil
			self:SendMessage("PORTAXI_SALES")
		end
	end
	local reason
	if not ns.Duty:OnDuty() then
		reason = "off"
	elseif not offered(request.code) then
		reason = "route"
	elseif request.price < ns.Duty:Price(request.code) then
		reason = "price"
	else
		local incoming = 0
		for _, sale in pairs(self.sales) do
			incoming = incoming + (sale.state == "incoming" and 1 or 0)
		end
		if incoming >= Deal.MAX_INCOMING then
			reason = "busy"
		end
	end
	if reason then
		ns.Net:Whisper(sender, Proto.EncodeAnswer("D", request.deal, reason))
		return
	end
	local sale = {
		deal = request.deal, buyer = sender, code = request.code, kind = request.code == "*" and "S" or "P", price = request.price,
		level = request.level, cls = request.cls, zone = request.zone, sub = request.sub, state = "incoming", since = GetTime(), paid = 0,
	}
	self.sales[sale.deal] = sale
	ns.PlayAlert()
	self:ScheduleTimer(function()
		if self.sales[sale.deal] == sale and sale.state == "incoming" then
			self:Decline(sale.deal, "timeout")
		end
	end, Deal.ANSWER_WAIT)
	self:SendMessage("PORTAXI_SALES", sale)
end

function Deal:Accept(deal)
	local sale = self.sales[deal]
	if not sale or sale.state ~= "incoming" then
		return false
	end
	sale.state, sale.changed = "accepted", GetTime()
	ns.Net:Whisper(sale.buyer, Proto.EncodeAnswer("A", deal))
	C_PartyInfo.InviteUnit(sale.buyer)
	self:SendMessage("PORTAXI_SALES", sale)
	self:OnRoster()
	return true
end

function Deal:Decline(deal, reason)
	local sale = self.sales[deal]
	if not sale then
		return
	end
	ns.Net:Whisper(sale.buyer, Proto.EncodeAnswer("D", deal, reason or "busy"))
	self.sales[deal] = nil
	self:SendMessage("PORTAXI_SALES")
end

function Deal:Invite(name)
	C_PartyInfo.InviteUnit(name)
end

function Deal:CheckSale(sale)
	if sale.state ~= "grouped" then
		return
	end
	if not sale.delivered then
		local unit = ns.GroupUnit(sale.buyer)
		local where, whereID
		if unit then
			where, whereID = ns.UnitZone(unit)
		end
		if where then
			if sale.kind == "P" then
				sale.delivered = ns.AtDest(sale.code, where, whereID) and not ns.AtDest(sale.code, sale.startZone, sale.startZoneID)
			else
				local mine, _, mineID = ns.Zone()
				sale.delivered = ns.SameZone(where, whereID, mine, mineID) and not ns.SameZone(sale.startZone, sale.startZoneID, mine, mineID)
			end
			if sale.delivered then
				sale.level = UnitLevel(unit) or sale.level
				self:SendMessage("PORTAXI_SALES", sale)
			end
		end
	end
	if sale.delivered and sale.paid >= sale.price then
		ns.Net:SendConfirm({
			deal = sale.deal, role = "P", provider = ns.MyName(), buyer = sale.buyer, kind = sale.kind, code = sale.code, price = sale.price,
			paid = sale.paid, blevel = sale.level, time = ns.Now(),
		})
		sale.state, sale.changed = "done", GetTime()
		local char = ns.db.char
		char.runTrips = (char.runTrips or 0) + 1
		char.runEarned = (char.runEarned or 0) + sale.paid
		self:SendMessage("PORTAXI_SALES", sale)
	end
end

-- Both sides --------------------------------------------------------------------------------

function Deal:OnAnswer(sender, kind, deal, reason)
	local buy = self.buy
	if buy and buy.deal == deal and Util.SameName(sender, buy.provider) then
		if kind == "A" and buy.state == "sent" then
			self:SetBuy("accepted")
			self:OnRoster()
		elseif kind == "D" and (buy.state == "sent" or buy.state == "accepted") then
			buy.reason = reason
			self:SetBuy("declined")
		end
		return
	end
	local sale = self.sales[deal]
	if sale and kind == "Z" and Util.SameName(sender, sale.buyer) and sale.state ~= "done" then
		self.sales[deal] = nil
		self:SendMessage("PORTAXI_SALES")
	end
end

function Deal:OnRoster()
	local buy = self.buy
	if buy and buy.state == "accepted" and ns.GroupUnit(buy.provider) then
		local zone, _, zoneID = ns.Zone()
		buy.startZone, buy.startZoneID = zone, zoneID
		self:SetBuy("grouped")
	end
	for _, sale in pairs(self.sales) do
		if sale.state == "accepted" then
			local unit = ns.GroupUnit(sale.buyer)
			if unit then
				sale.state, sale.changed = "grouped", GetTime()
				local zone, zoneID = ns.UnitZone(unit)
				sale.startZone, sale.startZoneID = zone or sale.zone, zoneID
				self:SendMessage("PORTAXI_SALES", sale)
			end
		end
	end
end

function Deal:OnTrade(_, partner, give, get)
	local buy = self.buy
	if buy and (buy.state == "grouped" or buy.state == "accepted") and Util.SameName(partner, buy.provider) and give > 0 then
		buy.paid = buy.paid + give
		self:SendMessage("PORTAXI_BUY")
	end
	for _, sale in pairs(self.sales) do
		if (sale.state == "grouped" or sale.state == "accepted") and Util.SameName(partner, sale.buyer) and get > 0 then
			sale.paid = sale.paid + get
			self:SendMessage("PORTAXI_TRADE_CHECK", sale, get)
			break
		end
	end
	self:Check()
end

function Deal:Check()
	self:CheckBuy()
	for _, sale in pairs(self.sales) do
		self:CheckSale(sale)
	end
end

function Deal:Poll()
	self:Check()
	local now = GetTime()
	local buy = self.buy
	if buy and buy.state ~= "done" and now - buy.since > Deal.TTL then
		self:SetBuy("expired")
	end
	for deal, sale in pairs(self.sales) do
		if (sale.state == "done" and now - sale.changed > Deal.DONE_KEEP) or (sale.state ~= "done" and now - sale.since > Deal.TTL) then
			self.sales[deal] = nil
			self:SendMessage("PORTAXI_SALES")
		end
	end
	for deal, entry in pairs(ns.db.char.deals) do
		if ns.Now() - entry.time > ns.Ledger.KEEP then
			ns.db.char.deals[deal] = nil
		end
	end
end

-- Active sales in a stable order for the window: incoming first, then by time.
function Deal:SaleList()
	local list = {}
	for _, sale in pairs(self.sales) do
		list[#list + 1] = sale
	end
	table.sort(list, function(a, b)
		if (a.state == "incoming") ~= (b.state == "incoming") then
			return a.state == "incoming"
		end
		return a.since < b.since
	end)
	return list
end
