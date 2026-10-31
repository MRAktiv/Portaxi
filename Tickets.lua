-- Paper tickets over the game: the buyer's trip from station to station with the rating at the end,
-- a new order for the provider, the cast ticket with the secure spell button, and the trade check.
local _, ns = ...
local addon, L, Util, Theme, Proto = ns.addon, ns.L, ns.Util, ns.Theme, ns.Proto
local C = Theme.C

local Tickets = addon:NewModule("Tickets", "AceEvent-3.0", "AceTimer-3.0")
ns.Tickets = Tickets

local W, STUB = 440, 118
local MAIN = W - STUB
local BUYER_LINK, SELLER_LINK = C.buyerLink, C.sellerLink
local PAPER = Theme.RGB("E8D6B0")
local ARROW = " |T" .. Theme.MEDIA .. "arrow:16:16:0:0:32:32:0:32:0:32:120:92:62|t "
local TRADE_SHOW_FOR = 8

function Tickets:OnEnable()
	self:RegisterMessage("PORTAXI_TRADE_CHECK", "OnTradeCheck")
	self:ScheduleRepeatingTimer("Refresh", 1)
	ns.UI:Safe(function()
		self.cast = self.cast or self:NewTicket("PortaxiCastTicket", true)
	end)
end

-- Ticket skeleton --------------------------------------------------------------------------

local function stationRow(parent)
	local route = CreateFrame("Frame", nil, parent)
	route:SetSize(MAIN - 32, 28)
	route.stations, route.lines, route.labels = {}, {}, {}
	local step = (MAIN - 32 - 12) / 4
	for index = 1, 5 do
		local x = 6 + (index - 1) * step
		local outer = Theme.Disc(route, 12, C.inkLine, "ARTWORK")
		outer:SetPoint("CENTER", route, "TOPLEFT", x, -6)
		local inner = Theme.Disc(route, 7, PAPER, "OVERLAY")
		inner:SetPoint("CENTER", outer)
		local ring = route:CreateTexture(nil, "OVERLAY")
		ring:SetTexture(Theme.SKIN .. "ring")
		ring:SetSize(19, 19)
		ring:SetPoint("CENTER", outer)
		ring:SetVertexColor(unpack(C.sealRing))
		route.stations[index] = { outer = outer, inner = inner, ring = ring }
		local label = Theme.Text(route, "bold", 9, C.inkSoft, "CENTER", true)
		label:SetPoint("TOP", route, "TOPLEFT", x, -15)
		route.labels[index] = label
		if index < 5 then
			local line = route:CreateTexture(nil, "BORDER")
			line:SetHeight(2)
			line:SetPoint("LEFT", route, "TOPLEFT", x + 6, -6)
			line:SetWidth(step - 12)
			route.lines[index] = line
		end
	end
	function route:Set(labels, now)
		for index, station in ipairs(self.stations) do
			self.labels[index]:SetText(labels[index])
			self.labels[index]:SetTextColor(unpack(index == now and C.ink or C.inkSoft))
			if index < now then
				station.outer:SetVertexColor(unpack(C.ink))
				station.inner:SetVertexColor(unpack(C.ink))
			elseif index == now then
				station.outer:SetVertexColor(unpack(C.ink))
				station.inner:SetVertexColor(unpack(C.seal))
			else
				station.outer:SetVertexColor(unpack(C.inkLine))
				station.inner:SetVertexColor(unpack(PAPER))
			end
			station.ring:SetShown(index == now)
			if self.lines[index] then
				self.lines[index]:SetColorTexture(unpack(index < now and C.ink or C.inkLine))
			end
		end
	end
	return route
end

-- Main part on the left, stub on the right behind a dashed line. secure adds a spell button.
function Tickets:NewTicket(name, secure)
	local t = CreateFrame("Frame", name, UIParent)
	t:SetSize(W, 150)
	t:SetFrameStrata("HIGH")
	t:SetClampedToScreen(true)
	t:EnableMouse(true)
	t:SetMovable(true)
	t:RegisterForDrag("LeftButton")
	t:SetScript("OnDragStart", function(frame)
		if not InCombatLockdown() then
			frame:StartMoving()
		end
	end)
	t:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
	end)
	Theme.Paper(t)
	t:Hide()
	for index = 0, 30 do
		local dash = t:CreateTexture(nil, "BORDER")
		dash:SetColorTexture(unpack(C.inkLine))
		dash:SetSize(1, 4)
		dash:SetPoint("TOPLEFT", MAIN, -14 - index * 9)
		t["dash" .. index] = dash
	end
	t.label = Theme.Text(t, "bold", 10, C.inkSoft, nil, true)
	t.label:SetPoint("TOPLEFT", 18, -14)
	t.to = Theme.Text(t, "title", 26, C.ink, nil, true)
	t.to:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -3)
	t.to:SetWidth(MAIN - 30)
	t.who = Theme.Text(t, "bold", 13, BUYER_LINK, nil, true)
	t.from = Theme.Text(t, "body", 11.5, C.inkSoft, nil, true)
	t.from:SetWidth(MAIN - 30)
	t.route = stationRow(t)
	t.msg = Theme.Text(t, "body", 12.5, C.inkText, nil, true)
	t.msg:SetWidth(MAIN - 34)
	t.msg:SetWordWrap(true)
	t.stars = Theme.Stars(t, 22, 4, true)
	t.chips = {}
	for index, tag in ipairs({ "FAST", "POLITE", "SLOW", "PRICEY" }) do
		local chip = CreateFrame("Button", nil, t)
		chip:SetSize(80, 22)
		chip.bit = Proto.TAGS[tag]
		chip.tag = tag
		chip.on = Theme.Fill(chip, C.ink, "ARTWORK")
		chip.on:Hide()
		Theme.Border(chip, C.inkLine)
		chip.label = Theme.Text(chip, "bold", 11, C.inkSoft, "CENTER", true)
		chip.label:SetPoint("CENTER", 0, 0)
		chip.label:SetText(L["TAG_" .. tag])
		t.chips[index] = chip
	end
	t.ok = Theme.Button(t, "", "primary", 130, 30)
	t.no = Theme.Button(t, "", "dark", 110, 30)
	if secure then
		t.cast = Theme.Button(t, "", "primary", 200, 32, true)
	end
	t.stubLabel = Theme.Text(t, "bold", 10, C.inkSoft, "CENTER", true)
	t.stubLabel:SetPoint("TOP", t, "TOPLEFT", MAIN + STUB / 2, -14)
	t.stubLabel:SetWidth(STUB - 10)
	t.price = Theme.Text(t, "title", 30, C.ink, "CENTER", true)
	t.price:SetPoint("TOP", t.stubLabel, "BOTTOM", 0, -6)
	t.price:SetWidth(STUB - 10)
	t.timer = Theme.Text(t, "title", 24, C.seal, "CENTER", true)
	t.timer:SetPoint("TOP", t.price, "BOTTOM", 0, -6)
	t.stubNote = Theme.Text(t, "bold", 9.5, C.inkSoft, "CENTER", true)
	t.stubNote:SetWordWrap(true)
	t.stubNote:SetWidth(STUB - 10)
	t.stubOk = Theme.Button(t, "", "primary", STUB - 24, 30)
	t.stubOk:SetPoint("BOTTOM", t, "BOTTOMLEFT", MAIN + STUB / 2, 50)
	t.stubNo = Theme.Button(t, "", "dark", STUB - 24, 30)
	t.stubNo:SetPoint("BOTTOM", t, "BOTTOMLEFT", MAIN + STUB / 2, 14)
	return t
end

-- Lays out the main column top to bottom from the parts given; hides the rest.
local function layout(t, spec)
	local y = -14
	t.label:SetText(spec.label or "")
	y = y - 14
	t.to:SetShown(spec.to ~= nil)
	if spec.to then
		t.to:SetFont(Theme.FONTS.title, spec.small and 22 or 26, "")
		t.to:SetText(spec.to)
		y = y - (spec.small and 28 or 32)
	end
	t.who:SetShown(spec.who ~= nil)
	if spec.who then
		t.who:ClearAllPoints()
		t.who:SetPoint("TOPLEFT", 18, y - 2)
		t.who:SetText(spec.who)
		t.who:SetTextColor(unpack(spec.whoColor or BUYER_LINK))
		y = y - 18
	end
	t.from:SetShown(spec.from ~= nil)
	if spec.from then
		t.from:ClearAllPoints()
		t.from:SetPoint("TOPLEFT", 18, y)
		t.from:SetText(spec.from)
		y = y - 16
	end
	t.route:SetShown(spec.route ~= nil)
	if spec.route then
		t.route:ClearAllPoints()
		t.route:SetPoint("TOPLEFT", 18, y - 8)
		t.route:Set(spec.route.labels, spec.route.now)
		y = y - 40
	end
	t.msg:SetShown(spec.msg ~= nil)
	if spec.msg then
		t.msg:ClearAllPoints()
		t.msg:SetPoint("TOPLEFT", 18, y - 4)
		t.msg:SetText(spec.msg)
		y = y - 6 - math.max(16, t.msg:GetStringHeight() or 16)
	end
	t.stars:SetShown(spec.stars ~= nil)
	if spec.stars then
		t.stars:ClearAllPoints()
		t.stars:SetPoint("TOPLEFT", 18, y - 6)
		y = y - 32
	end
	for _, chip in ipairs(t.chips) do
		chip:SetShown(spec.chips ~= nil)
	end
	if spec.chips then
		local x = 18
		for _, chip in ipairs(t.chips) do
			local width = chip.label:GetStringWidth() + 18
			chip:SetWidth(width)
			chip:ClearAllPoints()
			chip:SetPoint("TOPLEFT", x, y - 4)
			x = x + width + 6
		end
		y = y - 28
	end
	local buttons = { { t.ok, spec.ok }, { t.no, spec.no } }
	local x = 18
	local hasButton = false
	for _, pair in ipairs(buttons) do
		local button, action = pair[1], pair[2]
		button:SetShown(action ~= nil)
		if action then
			hasButton = true
			button.label:SetText(action[1])
			button:SetWidth(button.label:GetStringWidth() + 36)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", x, y - 8)
			button:SetScript("OnClick", action[2])
			x = x + button:GetWidth() + 8
		end
	end
	if t.cast then
		if not InCombatLockdown() then
			t.cast:SetShown(spec.cast ~= nil)
			if spec.cast then
				t.cast:ClearAllPoints()
				t.cast:SetPoint("TOPLEFT", 18, y - 8)
			end
		end
		if spec.cast then
			hasButton = true
		end
	end
	if hasButton then
		y = y - 44
	end
	t.stubLabel:SetText(spec.stubLabel or "")
	t.price:SetText(spec.price or "")
	t.timer:SetText(spec.timer or "")
	t.stubNote:SetShown(spec.stubNote ~= nil)
	if spec.stubNote then
		t.stubNote:ClearAllPoints()
		t.stubNote:SetPoint("TOP", spec.timer and t.timer or t.price, "BOTTOM", 0, -6)
		t.stubNote:SetText(spec.stubNote)
	end
	for _, pair in ipairs({ { t.stubOk, spec.stubOk }, { t.stubNo, spec.stubNo } }) do
		local button, action = pair[1], pair[2]
		button:SetShown(action ~= nil)
		if action then
			button.label:SetText(action[1])
			button:SetScript("OnClick", action[2])
		end
	end
	if not InCombatLockdown() or not t.cast then
		t:SetHeight(math.max(150, -y + 16))
	end
end

local function countdown(since, wait)
	local left = math.max(0, math.ceil(wait - (GetTime() - since)))
	return string.format("%d:%02d", math.floor(left / 60), left % 60)
end

local function routeLabels(kind)
	return { L["R_ORDER"], L["R_REPLY"], L["R_GROUP"], kind == "S" and L["R_SUMMON"] or L["R_PORTAL"], L["R_PAY"] }
end

function Tickets:Show(t, shown, point)
	if shown and not t:IsShown() then
		t:ClearAllPoints()
		t:SetPoint("TOP", UIParent, "TOP", 0, point)
		t:Show()
	elseif not shown and t:IsShown() then
		t:Hide()
	end
end

-- Buyer ticket -----------------------------------------------------------------------------

function Tickets:BuyerSpec(buy)
	local dest = buy.kind == "P" and ns.DestName(buy.code) or (buy.psub ~= "" and buy.psub or buy.pzone)
	local fare = ns.Money(buy.price)
	local labels = routeLabels(buy.kind)
	local terms = buy.pay == "B" and L["BEFORE_TRIP"] or L["AFTER_TRIP"]
	local state = buy.state
	if state == "sent" then
		return {
			label = L["T_SENT"], to = dest, small = true, who = buy.provider, whoColor = Theme.PaperClassColor(buy.kind == "P" and "M" or "W", BUYER_LINK),
			route = { labels = labels, now = 2 }, stubLabel = L["T_WAIT"], timer = countdown(buy.since, ns.Deal.ANSWER_WAIT),
			stubNo = { L["T_CANCEL"], function()
				ns.Deal:Cancel()
			end },
		}
	elseif state == "accepted" then
		return { label = L["T_ACCEPTED"], route = { labels = labels, now = 3 }, msg = L["MSG_ACCEPTED"]:format(buy.provider),
			stubLabel = L["FARE"], price = fare, stubNote = terms }
	elseif state == "grouped" then
		local unpaid = buy.paid < buy.price
		if buy.arrived or (buy.pay == "B" and unpaid) then
			local msg = buy.arrived and L["MSG_PAY"]:format(fare, buy.provider) or L["MSG_PAY_FIRST"]:format(buy.provider, fare)
			return {
				label = L["T_PAY"], route = { labels = labels, now = buy.arrived and 5 or 4 }, msg = msg,
				ok = { L["T_OPEN_TRADE"], function()
					local unit = ns.GroupUnit(buy.provider)
					if unit then
						InitiateTrade(unit)
					end
				end },
				stubLabel = L["FARE"], price = fare, stubNote = buy.provider,
			}
		end
		local place = buy.psub ~= "" and (buy.pzone .. ", " .. buy.psub) or buy.pzone
		return {
			label = buy.kind == "P" and L["T_GO"] or L["T_SUMMON_WAIT"], route = { labels = labels, now = 4 },
			msg = buy.kind == "P" and L["MSG_GO"]:format(buy.provider, place) or L["MSG_SUMMON"]:format(buy.provider),
			stubLabel = L["FARE"], price = fare, stubNote = terms,
		}
	elseif state == "done" then
		return self:RatingSpec(buy.deal, buy.provider, buy.kind, dest, buy.startZone, buy.paid)
	end
	local titles = { declined = L["T_DECLINED"], noanswer = L["T_NOANSWER"], expired = L["T_EXPIRED"] }
	local nextOne = buy.alternatives[1]
	local reason = state == "declined" and L["REASON_D_" .. (buy.reason or "busy")] or (state == "noanswer" and L["REASON_D_timeout"] or nil)
	local lines = {}
	if reason then
		lines[#lines + 1] = buy.provider .. " " .. reason .. "."
	end
	lines[#lines + 1] = nextOne and L["MSG_NEXT"]:format(nextOne.name) or L["MSG_NOBODY"]
	return {
		label = titles[state] or "", to = dest, small = true, msg = table.concat(lines, " "),
		ok = nextOne and { L["NEXT"], function()
			ns.Deal:OrderNext()
		end } or nil,
		no = { L["CLOSE"], function()
			ns.Deal:Cancel()
		end },
		stubLabel = L["FARE"], price = fare,
	}
end

function Tickets:RatingSpec(deal, provider, kind, dest, fromZone, paid)
	local to = dest
	if kind == "P" and fromZone and fromZone ~= "" then
		to = fromZone .. ARROW .. to
	end
	self.rating = self.rating or {}
	if self.rating.deal ~= deal then
		self.rating = { deal = deal, stars = 5, tags = 0 }
	end
	return {
		label = L["T_DONE"], to = to, small = true, who = provider, whoColor = Theme.PaperClassColor(kind == "P" and "M" or "W", BUYER_LINK), from = L["MSG_DONE"]:format(ns.Money(paid or 0)),
		stars = true, chips = true,
		stubOk = { L["RATE"], function()
			ns.Deal:Rate(deal, self.rating.stars, self.rating.tags)
			self.pendingShown = nil
			self:Refresh()
		end },
		stubNo = { L["LATER"], function()
			ns.Deal:Later()
			self.pendingShown = nil
			self:Refresh()
		end },
	}
end

function Tickets:BuyerTicket()
	if not self.buyer then
		local t = self:NewTicket("PortaxiBuyerTicket")
		for _, star in ipairs(t.stars.stars) do
			star:SetScript("OnClick", function()
				self.rating.stars = star.index
				self:Refresh()
			end)
		end
		for _, chip in ipairs(t.chips) do
			chip:SetScript("OnClick", function()
				local tags = self.rating.tags
				if math.floor(tags / chip.bit) % 2 == 1 then
					self.rating.tags = tags - chip.bit
				else
					self.rating.tags = tags + chip.bit
				end
				self:Refresh()
			end)
		end
		self.buyer = t
	end
	return self.buyer
end

function Tickets:ShowPendingRating()
	local deal = ns.Deal:Unrated()
	self.pendingShown = deal
	self:Refresh()
end

function Tickets:RefreshBuyer()
	local buy = ns.Deal.buy
	local spec
	if buy then
		spec = self:BuyerSpec(buy)
	elseif self.pendingShown then
		local entry = ns.db.char.deals[self.pendingShown]
		if entry and not entry.rated then
			local dest = entry.kind == "P" and ns.DestName(entry.code) or ""
			spec = self:RatingSpec(self.pendingShown, entry.provider, entry.kind, dest, nil, entry.price)
		else
			self.pendingShown = nil
		end
	end
	local t = self:BuyerTicket()
	if spec then
		layout(t, spec)
		if spec.stars then
			t.stars:Set(self.rating.stars, Theme.RGB("C8901E"))
			for _, chip in ipairs(t.chips) do
				local on = math.floor(self.rating.tags / chip.bit) % 2 == 1
				chip.on:SetShown(on)
				chip.label:SetTextColor(unpack(on and C.accent or C.inkSoft))
			end
		end
	end
	self:Show(t, spec ~= nil, -120)
end

-- Provider tickets -------------------------------------------------------------------------

function Tickets:RefreshIncoming()
	if not self.incoming then
		self.incoming = self:NewTicket("PortaxiOrderTicket")
	end
	local t = self.incoming
	local sale
	for _, candidate in ipairs(ns.Deal:SaleList()) do
		if candidate.state == "incoming" then
			sale = candidate
			break
		end
	end
	if sale then
		local zone, sub = ns.Zone()
		local dest = sale.kind == "P" and ns.DestName(sale.code) or (sub ~= "" and sub or zone)
		local place = sale.sub ~= "" and (sale.zone .. ", " .. sale.sub) or sale.zone
		layout(t, {
			label = L["NEW_ORDER"]:format(sale.kind == "P" and L["K_PORTAL"] or L["K_SUMMON"]), to = dest,
			who = L["LEVEL"]:format(sale.buyer, sale.level), whoColor = Theme.PaperClassColor(sale.cls, SELLER_LINK), from = L["WAITS_IN"]:format(place),
			ok = { L["ACCEPT"], function()
				ns.Deal:Accept(sale.deal)
			end },
			no = { L["DECLINE"], function()
				ns.Deal:Decline(sale.deal, "busy")
			end },
			stubLabel = L["FARE"], price = ns.Money(sale.price), timer = countdown(sale.since, ns.Deal.ANSWER_WAIT), stubNote = L["ANSWER_IN"],
		})
	end
	self:Show(t, sale ~= nil, -120)
end

function Tickets:RefreshCast()
	local t = self.cast
	if not t then
		return
	end
	local sale
	for _, candidate in ipairs(ns.Deal:SaleList()) do
		if candidate.state == "grouped" and not candidate.delivered then
			sale = candidate
			break
		end
	end
	if sale then
		local zone, sub = ns.Zone()
		local dest = sale.kind == "P" and ns.DestName(sale.code) or (sub ~= "" and sub or zone)
		layout(t, {
			label = L["BUYER_IN_GROUP"], to = dest, small = true, who = sale.buyer, whoColor = Theme.PaperClassColor(sale.cls, SELLER_LINK), from = L["GOING"],
			cast = true, stubLabel = ns.ProviderClass() == "W" and L["SHARDS"] or L["RUNES"], price = tostring(ns.Duty:Reagents() or 0),
		})
		if not InCombatLockdown() then
			ns.UI:SetCast(t.cast, sale)
			t.cast:SetWidth(t.cast.label:GetStringWidth() + 40)
		end
	end
	if InCombatLockdown() then
		if t:IsShown() ~= (sale ~= nil) then
			ns.UI:Safe(function()
				self:RefreshCast()
			end)
		end
		return
	end
	self:Show(t, sale ~= nil, -280)
end

-- Trade check -----------------------------------------------------------------------------

function Tickets:OnTradeCheck(_, sale, received)
	if not self.trade then
		local t = CreateFrame("Frame", "PortaxiTradeCheck", UIParent)
		t:SetSize(W, 124)
		t:SetFrameStrata("HIGH")
		Theme.Window(t, nil, function()
			t:Hide()
		end)
		t.title = Theme.Text(t, "bold", 10.5, C.head)
		t.title:SetPoint("TOPLEFT", 24, -22)
		t.rows = {}
		for index = 1, 2 do
			local label = Theme.Text(t, "body", 13, C.text)
			label:SetPoint("TOPLEFT", 24, -40 - (index - 1) * 22)
			local value = Theme.Text(t, "title", 17, C.accent, "RIGHT")
			value:SetPoint("TOPRIGHT", -24, -38 - (index - 1) * 22)
			t.rows[index] = { label = label, value = value }
		end
		t.result = Theme.Text(t, "bold", 12, C.green)
		t.result:SetPoint("BOTTOMLEFT", 24, 22)
		t:Hide()
		self.trade = t
	end
	local t = self.trade
	t.title:SetText(Util.Upper(L["TRADE_WITH"]:format(sale.buyer)))
	t.rows[1].label:SetText(L["TRADE_GIVEN"])
	t.rows[1].value:SetText(ns.Money(sale.paid))
	t.rows[2].label:SetText(L["TRADE_DUE"])
	t.rows[2].value:SetText(ns.Money(sale.price))
	local short = sale.price - sale.paid
	t.result:SetText(short <= 0 and L["TRADE_OK"] or L["TRADE_SHORT"]:format(ns.Money(short)))
	t.result:SetTextColor(unpack(short <= 0 and C.green or C.red))
	t:ClearAllPoints()
	t:SetPoint("TOP", UIParent, "TOP", 0, -440)
	t:Show()
	if self.tradeTimer then
		self:CancelTimer(self.tradeTimer)
	end
	self.tradeTimer = self:ScheduleTimer(function()
		t:Hide()
	end, TRADE_SHOW_FOR)
end

-- Labels set when a ticket is built follow a language change.
function Tickets:Relabel()
	for _, t in pairs({ self.buyer, self.incoming, self.cast }) do
		for _, chip in ipairs(t.chips) do
			chip.label:SetText(L["TAG_" .. chip.tag])
		end
	end
	self:Refresh()
end

function Tickets:Refresh()
	if not ns.db then
		return
	end
	self:RefreshBuyer()
	self:RefreshIncoming()
	self:RefreshCast()
end
