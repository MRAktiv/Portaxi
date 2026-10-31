-- Departures window of a fixed size: header with the clock and the language, tabs, the portal and summon boards,
-- the top list, "My run" for mages and warlocks and the admin tab. What does not fit scrolls inside the page.
local _, ns = ...
local addon, L, Util, Theme, Market, Ledger = ns.addon, ns.L, ns.Util, ns.Theme, ns.Market, ns.Ledger
local C = Theme.C

local UI = addon:NewModule("UI", "AceEvent-3.0", "AceTimer-3.0")
ns.UI = UI

local W, H, TOP, X = 520, 620, 110, 26
local SB = 14
local RW = W - 2 * X - SB
local PAGE_H = H - TOP
local BAR_X = W - 18 - 13
local ROW_H, ROW_STEP, PROVIDER_H = 44, 50, 42
local MAX_ROWS, MAX_PROVIDERS = 6, 4
local BOARD_FOOTER, TOP_FOOTER, RUN_FOOTER = 80, 62, 72
local BOARD_HEAD, TOP_HEAD, RUN_HEAD = 24, 60, 58

UI.sel = { P = {}, S = {} }
UI.topKind = "P"

function UI:OnEnable()
	for _, message in ipairs({ "PORTAXI_BOARD", "PORTAXI_LEDGER", "PORTAXI_BANS", "PORTAXI_DUTY", "PORTAXI_SALES", "PORTAXI_CHAT", "PORTAXI_REPORTS", "PORTAXI_BUY" }) do
		self:RegisterMessage(message, "Refresh")
	end
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
	self:ScheduleRepeatingTimer("UpdateClock", 15)
	self:Safe(function()
		self:Frame()
	end)
end

-- Frames holding secure buttons cannot be shown, hidden or moved in combat; such calls wait.
function UI:Safe(fn)
	if InCombatLockdown() then
		self.queued = self.queued or {}
		table.insert(self.queued, fn)
		return false
	end
	fn()
	return true
end

function UI:OnCombatEnd()
	local queued = self.queued
	self.queued = nil
	for _, fn in ipairs(queued or {}) do
		fn()
	end
	self:Refresh()
end

function UI:Toggle()
	self:Safe(function()
		local frame = self:Frame()
		if frame:IsShown() then
			frame:Hide()
		else
			frame:Show()
			self:Refresh()
		end
	end)
end

function UI:Open(tab)
	self:Safe(function()
		local frame = self:Frame()
		frame:Show()
		self:SelectTab(tab or self.tab or "P")
	end)
end

local function decimal(value)
	local text = string.format("%.1f", value)
	if ns.Language() == "ruRU" then
		text = text:gsub("%.", ",")
	end
	return text
end
UI.Decimal = decimal

local function place(zone, sub)
	return sub ~= "" and (zone .. ", " .. sub) or zone
end

-- A dark inset behind part of a page, from the top of the page down to bottom pixels above its end.
local function insetBox(page, bottom)
	local box = CreateFrame("Frame", nil, page)
	box:SetPoint("TOPLEFT", 18, 0)
	box:SetPoint("BOTTOMRIGHT", -18, bottom)
	Theme.Inset(box)
	return box
end

-- Window ---------------------------------------------------------------------------------------

function UI:Frame()
	if self.frame then
		return self.frame
	end
	local f = CreateFrame("Frame", "PortaxiFrame", UIParent)
	self.frame = f
	f:SetSize(W, H)
	local point = ns.db.profile.point
	if point then
		f:SetPoint(point[1], UIParent, point[1], point[2], point[3])
	else
		f:SetPoint("CENTER", -220, 30)
	end
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(frame)
		if not InCombatLockdown() then
			frame:StartMoving()
		end
	end)
	f:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		local anchor, _, _, x, y = frame:GetPoint()
		ns.db.profile.point = { anchor or "CENTER", x or 0, y or 0 }
	end)
	Theme.Window(f, L["TITLE"], function()
		self:Toggle()
	end)
	f:Hide()

	f.heading = Theme.Text(f, "title", 19, C.text)
	f.heading:SetPoint("TOPLEFT", 84, -28)
	f.heading:SetText(L["SUBTITLE"])
	f.where = Theme.Text(f, "body", 11, C.dim)
	f.where:SetPoint("TOPLEFT", 84, -52)
	f.where:SetWidth(W - 84 - 176)

	local clock = CreateFrame("Frame", nil, f)
	clock:SetSize(66, 26)
	clock:SetPoint("TOPRIGHT", -26, -30)
	Theme.Inset(clock)
	clock.text = Theme.Text(clock, "title", 17, C.accent, "CENTER")
	clock.text:SetPoint("CENTER", 0, 1)
	f.clock = clock
	self:BuildLanguage(f)

	f.tabs = {}
	for _, key in ipairs({ "P", "S", "TOP", "RUN", "ADMIN" }) do
		local tab = Theme.Tab(f)
		tab.key = key
		tab:SetScript("OnClick", function()
			self:SelectTab(key)
		end)
		f.tabs[key] = tab
	end

	local content = CreateFrame("Frame", nil, f)
	content:SetPoint("TOPLEFT", 0, -TOP)
	content:SetPoint("BOTTOMRIGHT")
	f.content = content
	f.pages = {
		P = self:BuildDepartures(content, "P"),
		S = self:BuildDepartures(content, "S"),
		TOP = self:BuildTop(content),
		RUN = self:BuildRun(content),
		ADMIN = self:BuildAdmin(content),
	}
	self.tab = "P"
	self:UpdateClock()
	return f
end

function UI:UpdateClock()
	if not self.frame then
		return
	end
	local hours, minutes = GetGameTime()
	self.frame.clock.text:SetText(string.format("%02d:%02d", hours or 0, minutes or 0))
end

-- Language --------------------------------------------------------------------------------

function UI:BuildLanguage(f)
	local button = CreateFrame("Button", nil, f)
	button:SetHeight(26)
	button:SetPoint("TOPRIGHT", -98, -30)
	Theme.Slice(button, "dark", "BACKGROUND")
	local hover = Theme.Slice(button, "dark", "HIGHLIGHT")
	hover:SetBlendMode("ADD")
	hover:SetAlpha(0.25)
	button.flag = button:CreateTexture(nil, "ARTWORK")
	button.flag:SetSize(20, 13)
	button.flag:SetPoint("LEFT", 8, 0)
	button.flag:SetTexCoord(0, 0.75, 0, 1)
	button.flag:SetTexture(Theme.SKIN .. "flag-" .. ns.Language())
	button.code = Theme.Text(button, "bold", 12, C.text)
	button.code:SetPoint("LEFT", 34, 1)
	button.code:SetText(L["LANG_CODE"])
	local arrow = button:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture(Theme.SKIN .. "chevron")
	arrow:SetSize(10, 10)
	arrow:SetPoint("RIGHT", -7, 0)
	arrow:SetVertexColor(unpack(C.accent))
	button:SetWidth(math.floor(button.code:GetStringWidth() + 57 + 0.5))
	button:SetScript("OnClick", function()
		self:ToggleLanguages()
	end)
	f.lang = button
end

function UI:ToggleLanguages()
	local menu = self.langMenu
	if not menu then
		menu = CreateFrame("Frame", nil, self.frame)
		menu:SetFrameStrata("DIALOG")
		menu:SetSize(150, #ns.LANGUAGES * 26 + 10)
		menu:Hide()
		menu:SetPoint("TOPRIGHT", self.frame.lang, "BOTTOMRIGHT", 0, -2)
		Theme.Inset(menu)
		menu.items = {}
		for index, code in ipairs(ns.LANGUAGES) do
			local item = CreateFrame("Button", nil, menu)
			item:SetSize(142, 26)
			item:SetPoint("TOPLEFT", 4, -5 - (index - 1) * 26)
			item.sel = Theme.Fill(item, C.pick)
			local hover = Theme.Fill(item, C.pick, "HIGHLIGHT")
			hover:SetBlendMode("ADD")
			item.flag = item:CreateTexture(nil, "ARTWORK")
			item.flag:SetSize(20, 13)
			item.flag:SetPoint("LEFT", 6, 0)
			item.flag:SetTexCoord(0, 0.75, 0, 1)
			item.flag:SetTexture(Theme.SKIN .. "flag-" .. code)
			item.name = Theme.Text(item, "bold", 12, C.text)
			item.name:SetPoint("LEFT", 34, 1)
			item.name:SetText(ns.LOCALES[code].LANG_NAME)
			item.tick = item:CreateTexture(nil, "OVERLAY")
			item.tick:SetTexture(Theme.SKIN .. "tick")
			item.tick:SetSize(18, 18)
			item.tick:SetPoint("RIGHT", -6, 0)
			item.code = code
			item:SetScript("OnClick", function()
				menu:Hide()
				if code ~= ns.Language() then
					self:SetLanguage(code)
				end
			end)
			menu.items[index] = item
		end
		self.langMenu = menu
	end
	for _, item in ipairs(menu.items) do
		local on = item.code == ns.Language()
		item.sel:SetShown(on)
		item.tick:SetShown(on)
		item.name:SetTextColor(unpack(on and C.text or C.dim))
	end
	menu:SetShown(not menu:IsShown())
end

function UI:SetLanguage(code)
	self:Safe(function()
		ns.db.global.lang = code
		ns.SetLanguage(code)
		self:Rebuild()
	end)
end

-- Labels are set once when the window is built, so another language means a new window.
function UI:Rebuild()
	local old, tab = self.frame, self.tab
	local wasShown = old and old:IsShown()
	if old then
		old:Hide()
	end
	self.frame, self.reasons, self.priceBox, self.langMenu = nil, nil, nil, nil
	local f = self:Frame()
	self.tab = tab or "P"
	if wasShown then
		f:Show()
	end
	if ns.Tickets then
		ns.Tickets:Relabel()
	end
	self:Refresh()
end

-- Tabs ------------------------------------------------------------------------------------

function UI:VisibleTabs()
	local list = { "P", "S", "TOP" }
	if ns.ProviderClass() then
		list[#list + 1] = "RUN"
	end
	if ns.AmAdmin() then
		list[#list + 1] = "ADMIN"
	end
	return list
end

function UI:SelectTab(key)
	self:Safe(function()
		self.tab = key
		self:Refresh()
	end)
end

function UI:LayoutTabs(counts)
	local f = self.frame
	local labels = { P = L["TAB_PORTALS"], S = L["TAB_SUMMON"], TOP = L["TAB_TOP"], RUN = L["TAB_RUN"], ADMIN = L["TAB_ADMIN"] }
	for _, tab in pairs(f.tabs) do
		tab:Hide()
	end
	local visible = self:VisibleTabs()
	local valid = false
	for _, key in ipairs(visible) do
		valid = valid or key == self.tab
	end
	if not valid then
		self.tab = "P"
	end
	local x = 22
	for _, key in ipairs(visible) do
		local tab = f.tabs[key]
		tab.label:SetText(labels[key])
		tab.count:SetText(counts[key] and tostring(counts[key]) or "")
		tab:SetActive(key == self.tab)
		tab:Fit()
		tab:ClearAllPoints()
		if key == "RUN" or key == "ADMIN" then
			tab:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -74)
		else
			tab:SetPoint("TOPLEFT", f, "TOPLEFT", x, -74)
			x = x + tab:GetWidth() + 6
		end
		tab:Show()
	end
	if f.tabs.RUN:IsShown() and f.tabs.ADMIN:IsShown() then
		f.tabs.RUN:ClearAllPoints()
		f.tabs.RUN:SetPoint("TOPRIGHT", f.tabs.ADMIN, "TOPLEFT", -6, 0)
	end
end

-- Data shared by the pages.
function UI:Viewer()
	local zone, sub, zoneID = ns.Zone()
	return { fac = ns.Faction(), zone = zone, sub = sub, map = zoneID, key = ns.MyKey() }
end

function UI:Stats()
	return Ledger.Stats(ns.RealmData().ledger, ns.Now(), ns.IsBanned)
end

-- Each Update* lays out its page and returns the height of what scrolls.
function UI:Refresh()
	local f = self.frame
	if not f or not f:IsShown() then
		if ns.Tickets then
			ns.Tickets:Refresh()
		end
		return
	end
	local stats = self:Stats()
	local viewer = self:Viewer()
	f.where:SetText(place(viewer.zone, viewer.sub))
	local portals = Market.Portals(ns.Net.offers, viewer, stats, ns.IsBanned)
	local summons = Market.Summons(ns.Net.offers, viewer, stats, ns.IsBanned)
	self:LayoutTabs({ P = Market.CountWithProviders(portals), S = #summons })
	if not InCombatLockdown() then
		for key, page in pairs(f.pages) do
			page:SetShown(key == self.tab)
		end
	end
	local height
	if self.tab == "P" then
		height = self:UpdateDepartures(f.pages.P, "P", portals)
	elseif self.tab == "S" then
		height = self:UpdateDepartures(f.pages.S, "S", summons)
	elseif self.tab == "TOP" then
		height = self:UpdateTop(f.pages.TOP, stats)
	elseif self.tab == "RUN" then
		height = self:UpdateRun(f.pages.RUN)
	elseif self.tab == "ADMIN" then
		height = self:UpdateAdmin(f.pages.ADMIN)
	end
	if height then
		f.pages[self.tab].scroll:SetContent(height)
	end
	if ns.Tickets then
		ns.Tickets:Refresh()
	end
end

-- Portal and summon boards -----------------------------------------------------------------

local COL = { name = 54, count = 264, price = 298, lamp = 362, status = 381 }

local function header(page, text, x, justify)
	local label = Theme.Text(page, "bold", 10, C.head, justify)
	if justify == "CENTER" then
		label:SetPoint("TOP", page, "TOPLEFT", x, -10)
	elseif justify == "RIGHT" then
		label:SetPoint("TOPRIGHT", page, "TOPLEFT", x, -10)
	else
		label:SetPoint("TOPLEFT", x, -10)
	end
	label:SetText(text)
	return label
end

function UI:BuildDepartures(parent, kind)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()
	page:Hide()
	page.kind = kind
	insetBox(page, BOARD_FOOTER)
	header(page, kind == "P" and L["COL_DEST"] or L["COL_POINT"], X + COL.name)
	header(page, kind == "P" and L["COL_MAGES"] or L["COL_LOCKS"], X + COL.count, "CENTER")
	header(page, L["COL_FROM"], X + COL.price)
	header(page, L["COL_STATUS"], X + COL.lamp)
	page.scroll = Theme.Scroll(page, 0, -BOARD_HEAD, W, PAGE_H - BOARD_HEAD - BOARD_FOOTER - 4, BAR_X)
	local body = page.scroll.body

	page.rows = {}
	for index = 1, MAX_ROWS do
		local row = CreateFrame("Button", nil, body)
		row:SetSize(RW, ROW_H)
		Theme.Row(row)
		row.icon = Theme.Icon(row, 40)
		row.icon:SetPoint("LEFT", 4, 0)
		row.name = Theme.Text(row, "bold", 15, C.text)
		row.name:SetPoint("LEFT", COL.name, 1)
		row.name:SetWidth(COL.count - COL.name - 22)
		row.count = Theme.Text(row, "title", 20, C.text, "CENTER")
		row.count:SetPoint("CENTER", row, "LEFT", COL.count, 1)
		row.price = Theme.Text(row, "title", 20, C.accent)
		row.price:SetPoint("LEFT", COL.price, 1)
		row.lamp = Theme.Lamp(row, 14)
		row.lamp:SetPoint("LEFT", COL.lamp, 0)
		row.status = Theme.Text(row, "bold", 12, C.text)
		row.status:SetPoint("LEFT", COL.status, 1)
		row:SetScript("OnClick", function()
			self.sel[kind].row = row.id
			self.sel[kind].key = nil
			self:Refresh()
		end)
		page.rows[index] = row
	end

	local drop = CreateFrame("Frame", nil, body)
	drop:SetWidth(W - 60 - SB)
	page.drop = drop
	drop.items = {}
	for index = 1, MAX_PROVIDERS do
		local item = CreateFrame("Button", nil, drop)
		item:SetSize(W - 60 - SB, PROVIDER_H - 4)
		item:SetPoint("TOPLEFT", 0, -(index - 1) * PROVIDER_H)
		item.sel = Theme.Fill(item, C.pick)
		item.mark = item:CreateTexture(nil, "ARTWORK")
		item.mark:SetColorTexture(unpack(C.accent))
		item.mark:SetPoint("TOPLEFT")
		item.mark:SetPoint("BOTTOMLEFT")
		item.mark:SetWidth(2)
		item.name = Theme.Text(item, "bold", 13, C.text)
		item.name:SetPoint("TOPLEFT", 50, -6)
		item.near = Theme.Badge(item, L["NEAR"])
		item.near:SetPoint("LEFT", item.name, "RIGHT", 6, 0)
		item.place = Theme.Text(item, "body", 11, C.dim)
		item.place:SetPoint("TOPLEFT", item.name, "BOTTOMLEFT", 0, -3)
		item.place:SetWidth(276)
		item.star = Theme.Star(item, 11)
		item.star:SetPoint("TOPLEFT", 334, -6)
		item.rating = Theme.Text(item, "bold", 12, C.text)
		item.rating:SetPoint("LEFT", item.star, "RIGHT", 3, 0)
		item.trips = Theme.Text(item, "body", 10.5, C.dim)
		item.trips:SetPoint("TOPLEFT", 334, -23)
		item.price = Theme.Text(item, "title", 18, C.accent, "RIGHT")
		item.price:SetPoint("RIGHT", -4, 0)
		item.price:SetWidth(70)
		item:SetScript("OnClick", function()
			self.sel[kind].key = item.key
			self:Refresh()
		end)
		drop.items[index] = item
	end
	page.divider = Theme.Divider(body, W - 120 - SB)

	page.note = Theme.Text(body, "body", 11, C.dim)
	page.note:SetWordWrap(true)
	page.note:SetWidth(W - 60 - SB)
	page.empty = Theme.Text(body, "body", 12, C.dim, "CENTER")
	page.empty:SetWidth(RW)
	page.empty:SetWordWrap(true)

	self:BuildFooter(page, function()
		self:OrderSelected(kind)
	end)
	return page
end

function UI:BuildFooter(page, onOrder)
	page.me = Theme.Text(page, "body", 12, C.dim)
	page.me:SetPoint("BOTTOMLEFT", X, 46)
	page.where = Theme.Text(page, "body", 11, C.dim)
	page.where:SetPoint("BOTTOMLEFT", X, 29)
	page.where:SetWidth(W - 2 * X - 190)
	page.pending = CreateFrame("Button", nil, page)
	page.pending:SetSize(200, 16)
	page.pending:SetPoint("BOTTOMLEFT", X, 60)
	page.pending.text = Theme.Text(page.pending, "bold", 11.5, C.accent)
	page.pending.text:SetPoint("LEFT")
	page.pending:SetScript("OnClick", function()
		ns.Tickets:ShowPendingRating()
	end)
	if onOrder then
		page.order = Theme.Button(page, "", "primary", 180, 42)
		page.order:SetPoint("BOTTOMRIGHT", -22, 24)
		page.order:SetScript("OnClick", onOrder)
	end
end

function UI:UpdateFooter(page, price)
	local zone, sub = ns.Zone()
	local _, class = UnitClass("player")
	page.me:SetText(L["YOU"]:format(Theme.Colored(ns.MyName() or "", Theme.ClassColor(class))))
	page.where:SetText(place(zone, sub))
	local deal, entry = ns.Deal:Unrated()
	page.pending:SetShown(deal ~= nil and not ns.Deal.buy)
	if deal then
		page.pending.text:SetText(L["RATE_PENDING"]:format(Theme.Colored(entry.provider, Theme.ClassColor(entry.kind == "P" and "M" or "W"))))
		page.pending:SetWidth(page.pending.text:GetStringWidth() + 4)
	end
	if page.order then
		page.order.label:SetText(price and L["ORDER"]:format(ns.Money(price)) or L["ORDER_EMPTY"])
		Theme.SetEnabled(page.order, price ~= nil)
	end
end

local function placeText(kind, provider)
	local parts = {}
	if kind == "P" then
		parts[1] = place(provider.zone, provider.sub)
	else
		parts[1] = provider.helpers and L["HELPERS_YES"] or L["HELPERS_NO"]
	end
	if provider.pay == "B" then
		parts[#parts + 1] = L["PAY_BEFORE"]
	end
	return table.concat(parts, ", ")
end

-- Keeps the selection valid: a row with providers and one of its providers.
function UI:Selected(kind, list)
	local sel = self.sel[kind]
	local row
	for _, entry in ipairs(list) do
		local id = entry.code or entry.id
		if id == sel.row and entry.count > 0 then
			row = entry
		end
	end
	if not row then
		for _, entry in ipairs(list) do
			if entry.count > 0 then
				row = entry
				break
			end
		end
	end
	if not row then
		sel.row, sel.key = nil, nil
		return nil, nil
	end
	sel.row = row.code or row.id
	local provider
	for _, candidate in ipairs(row.providers) do
		if candidate.key == sel.key then
			provider = candidate
		end
	end
	provider = provider or row.providers[1]
	sel.key = provider.key
	return row, provider
end

function UI:UpdateDepartures(page, kind, list)
	local selectedRow, selectedProvider = self:Selected(kind, list)
	local y = -2
	for index, row in ipairs(page.rows) do
		local entry = list[index]
		row:SetShown(entry ~= nil)
		if entry then
			row.id = entry.code or entry.id
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", X, y)
			row.name:SetText(kind == "P" and ns.DestName(entry.code) or entry.label)
			row.icon.icon:SetTexture(ns.SpellIcon(kind == "P" and ns.DestSpell(entry.code) or ns.SUMMON_SPELL))
			row.count:SetText(tostring(entry.count))
			row.count:SetTextColor(unpack(entry.count > 0 and C.text or C.dim))
			row.price:SetText(entry.minPrice and ns.Money(entry.minPrice) or L["NO_PRICE"])
			row.price:SetTextColor(unpack(entry.minPrice and C.accent or C.dim))
			if entry.count == 0 then
				row.lamp:Set("grey")
				row.status:SetText(kind == "P" and L["ST_NO_MAGES"] or L["ST_NO_LOCKS"])
				row.status:SetTextColor(unpack(C.dim))
			elseif kind == "S" and not entry.ready then
				row.lamp:Set("amber")
				row.status:SetText(L["ST_GATHER"])
				row.status:SetTextColor(unpack(C.text))
			else
				row.lamp:Set("green")
				row.status:SetText(L["ST_BOARDING"])
				row.status:SetTextColor(unpack(C.text))
			end
			local isSelected = entry == selectedRow
			row:SetSelected(isSelected)
			y = y - ROW_STEP
			if isSelected then
				page.drop:ClearAllPoints()
				page.drop:SetPoint("TOPLEFT", 30, y + 2)
				local shown = math.min(#entry.providers, MAX_PROVIDERS)
				page.drop:SetHeight(shown * PROVIDER_H)
				for itemIndex, item in ipairs(page.drop.items) do
					local provider = entry.providers[itemIndex]
					item:SetShown(provider ~= nil)
					if provider then
						item.key = provider.key
						item.name:SetText(provider.name)
						item.name:SetTextColor(unpack(Theme.ClassColor(kind == "P" and "M" or "W")))
						item.near:SetShown(provider.near > 0)
						item.place:SetText(placeText(kind, provider))
						item.price:SetText(ns.Money(provider.price))
						item.rating:SetText(provider.rating and decimal(provider.rating) or "-")
						item.trips:SetText(ns.Format("TRIPS", provider.trips))
						local chosen = provider == selectedProvider
						item.sel:SetShown(chosen)
						item.mark:SetShown(chosen)
					end
				end
				y = y - shown * PROVIDER_H
				page.divider:ClearAllPoints()
				page.divider:SetPoint("TOPLEFT", 60, y + 4)
				y = y - 14
			end
		end
	end
	page.drop:SetShown(selectedRow ~= nil)
	page.divider:SetShown(selectedRow ~= nil)
	page.note:ClearAllPoints()
	page.note:SetPoint("TOPLEFT", 30, y - 2)
	page.note:SetText(kind == "S" and (L["SUMMON_NOTE"] .. "\n" .. L["GATHER_NOTE"]) or "")
	page.note:SetShown(kind == "S")
	if kind == "S" then
		y = y - 34
	end
	local any = false
	for _, entry in ipairs(list) do
		any = any or entry.count > 0
	end
	page.empty:SetShown(not any)
	page.empty:SetText(kind == "P" and L["EMPTY_PORTALS"] or L["EMPTY_SUMMON"])
	if not any then
		page.empty:ClearAllPoints()
		page.empty:SetPoint("TOP", page.scroll.body, "TOPLEFT", X + RW / 2, y - 8)
		y = y - 36
	end
	self:UpdateFooter(page, selectedProvider and selectedProvider.price or nil)
	page.current = { row = selectedRow, provider = selectedProvider }
	return -y + 10
end

function UI:OrderSelected(kind)
	local page = self.frame.pages[kind]
	local current = page.current
	if not current or not current.provider then
		return
	end
	local alternatives = {}
	for _, provider in ipairs(current.row.providers) do
		if provider ~= current.provider then
			alternatives[#alternatives + 1] = provider
		end
	end
	ns.Deal:Order(current.provider, kind == "P" and current.row.code or "*", alternatives)
end

-- Top list --------------------------------------------------------------------------------

function UI:BuildTop(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()
	page:Hide()
	insetBox(page, TOP_FOOTER)
	page.seg = Theme.Segments(page, { L["MAGES"], L["LOCKS"] }, function(index)
		self.topKind = index == 1 and "P" or "S"
		self.topSelected = nil
		self:Refresh()
	end)
	page.seg:SetPoint("TOPLEFT", 28, -10)
	page.note = Theme.Text(page, "body", 11, C.dim)
	page.note:SetPoint("LEFT", page.seg, "RIGHT", 10, 0)
	page.note:SetText(L["TOP_NOTE"])
	local function label(text, x, justify)
		local item = header(page, text, x, justify)
		item:ClearAllPoints()
		local anchor = justify == "CENTER" and "TOP" or (justify == "RIGHT" and "TOPRIGHT" or "TOPLEFT")
		item:SetPoint(anchor, page, "TOPLEFT", x, -48)
	end
	label(L["COL_RANK"], 40, "CENTER")
	label(L["COL_CARRIER"], 64)
	label(L["COL_TRIPS"], X + 350, "CENTER")
	label(L["COL_RATING"], W - 32 - SB, "RIGHT")
	page.scroll = Theme.Scroll(page, 0, -TOP_HEAD, W, PAGE_H - TOP_HEAD - TOP_FOOTER - 4, BAR_X)
	local body = page.scroll.body
	page.rows = {}
	for index = 1, Ledger.TOP_SIZE do
		local row = CreateFrame("Button", nil, body)
		row:SetSize(RW, 28)
		Theme.Row(row)
		row.rank = Theme.Text(row, "title", 17, C.dim, "CENTER")
		row.rank:SetPoint("CENTER", row, "LEFT", 14, 1)
		row.rank:SetText(tostring(index))
		row.rank:SetTextColor(unpack(C.medal[index] or C.dim))
		row.name = Theme.Text(row, "bold", 13, C.text)
		row.name:SetPoint("LEFT", 38, 1)
		row.duty = Theme.Badge(row, L["ON_LINE"])
		row.duty:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
		row.trips = Theme.Text(row, "title", 17, C.text, "CENTER")
		row.trips:SetPoint("CENTER", row, "LEFT", 350, 1)
		row.rating = Theme.Text(row, "bold", 13, C.text, "RIGHT")
		row.rating:SetPoint("RIGHT", -6, 1)
		row.star = Theme.Star(row, 11)
		row.star:SetPoint("RIGHT", row.rating, "LEFT", -3, 0)
		row:SetScript("OnClick", function()
			self.topSelected = self.topSelected ~= row.key and row.key or nil
			self:Refresh()
		end)
		page.rows[index] = row
	end

	local card = CreateFrame("Frame", nil, body)
	card:SetSize(W - 96 - SB, 82)
	Theme.Inset(card)
	card.lines = {}
	for index = 1, 3 do
		local line = Theme.Text(card, "body", 11.5, index == 1 and C.text or C.dim)
		line:SetPoint("TOPLEFT", 10, -8 - (index - 1) * 18)
		line:SetWidth(W - 116 - SB)
		card.lines[index] = line
	end
	card.report = Theme.Button(card, L["REPORT"], "dark", 122, 24)
	card.report:SetPoint("BOTTOMRIGHT", -8, 6)
	card.report:SetScript("OnClick", function()
		self:ShowReasons(card.report, card.name, false)
	end)
	card.ban = Theme.Button(card, L["BAN"], "dark", 100, 24)
	card.ban:SetPoint("RIGHT", card.report, "LEFT", -6, 0)
	card.ban:SetScript("OnClick", function()
		self:ShowReasons(card.ban, card.name, true)
	end)
	page.card = card
	page.rule = Theme.Text(page, "body", 11, C.dim)
	page.rule:SetPoint("BOTTOMLEFT", X, 20)
	page.rule:SetWidth(280)
	page.rule:SetWordWrap(true)
	page.place = Theme.Text(page, "title", 17, C.accent, "RIGHT")
	page.place:SetPoint("BOTTOMRIGHT", -X, 26)
	page.empty = Theme.Text(page, "body", 12, C.dim, "CENTER")
	page.empty:SetPoint("TOP", 0, -84)
	page.empty:SetWidth(RW)
	page.empty:SetWordWrap(true)
	page.empty:SetText(L["TOP_EMPTY"])
	return page
end

local TAG_ORDER = { "FAST", "POLITE", "SLOW", "PRICEY" }

function UI:UpdateTop(page, stats)
	local list = Ledger.Top(stats, self.topKind)
	page.seg:Select(self.topKind == "P" and 1 or 2)
	local y = -4
	local cardShown = false
	for index, row in ipairs(page.rows) do
		local entry = list[index]
		row:SetShown(entry ~= nil)
		if entry then
			row.key = entry.key
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", X, y)
			row.name:SetText(entry.name)
			row.name:SetTextColor(unpack(Theme.ClassColor(self.topKind == "P" and "M" or "W")))
			row.duty:SetShown(ns.Net.offers[entry.key] ~= nil)
			row.trips:SetText(tostring(entry.trips))
			row.rating:SetText(decimal(entry.rating))
			local selected = entry.key == self.topSelected
			row:SetSelected(selected)
			y = y - 32
			if selected then
				cardShown = true
				local card = page.card
				card.name = entry.name
				card:ClearAllPoints()
				card:SetPoint("TOPLEFT", 64, y)
				local s = entry.stats
				card.lines[1]:SetText(ns.Format("PROFILE", s.trips, s.buyers))
				local tags = {}
				for _, tag in ipairs(TAG_ORDER) do
					if s.tags[tag] then
						tags[#tags + 1] = Util.Lower(L["TAG_" .. tag]) .. " " .. s.tags[tag]
					end
				end
				card.lines[2]:SetText(#tags > 0 and (L["PROFILE_TAGS"] .. table.concat(tags, ", ")) or "")
				local last = {}
				for i, stars in ipairs(s.last) do
					last[i] = tostring(stars)
				end
				card.lines[3]:SetText(#last > 0 and L["PROFILE_LAST"]:format(table.concat(last, ", ")) or L["PROFILE_NONE"])
				card.ban:SetShown(ns.AmAdmin())
				y = y - 90
			end
		end
	end
	page.card:SetShown(cardShown)
	page.empty:SetShown(#list == 0)
	page.rule:SetText(L["TOP_RULE"]:format(Ledger.TOP_MIN_TRIPS, decimal(Ledger.TOP_MIN_RATING)))
	local rank = ns.ProviderClass() and Ledger.Place(stats, ns.ProviderClass() == "M" and "P" or "S", ns.MyKey())
	page.place:SetText(rank and L["YOUR_PLACE"]:format(rank) or "")
	return -y + 8
end

-- Reason picker for a report or a ban.
function UI:ShowReasons(anchor, name, ban)
	local menu = self.reasons
	if not menu then
		menu = CreateFrame("Frame", nil, self.frame)
		menu:SetFrameStrata("DIALOG")
		menu:SetSize(228, 4 * 28 + 12)
		menu:Hide()
		Theme.Inset(menu)
		menu.buttons = {}
		for index, reason in ipairs(ns.Proto.REASONS) do
			local button = Theme.Button(menu, L["REASON_" .. reason], "dark", 212, 26)
			button:SetPoint("TOP", 0, -6 - (index - 1) * 28)
			button.reason = reason
			menu.buttons[index] = button
		end
		self.reasons = menu
	end
	for _, button in ipairs(menu.buttons) do
		button:SetScript("OnClick", function()
			menu:Hide()
			if ban then
				ns.Admin:Ban(name, button.reason)
			else
				ns.Admin:Report(name, button.reason)
				ns.Print(L["REPORT_SENT"])
			end
			self:Refresh()
		end)
	end
	menu:ClearAllPoints()
	menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
	menu:SetShown(not menu:IsShown())
end

-- My run --------------------------------------------------------------------------------

function UI:BuildRun(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()
	page:Hide()

	local duty = CreateFrame("Frame", nil, page)
	duty:SetPoint("TOPLEFT", 18, 0)
	duty:SetPoint("TOPRIGHT", -18, 0)
	duty:SetHeight(50)
	Theme.Inset(duty)
	duty.switch = Theme.Switch(duty)
	duty.switch:SetPoint("LEFT", 12, 0)
	duty.switch:SetScript("OnClick", function()
		ns.Duty:SetDuty(not ns.db.char.duty)
	end)
	duty.label = Theme.Text(duty, "title", 19, C.green)
	duty.label:SetPoint("LEFT", duty.switch, "RIGHT", 12, 1)
	duty.stats = Theme.Text(duty, "body", 11, C.dim, "RIGHT")
	duty.stats:SetPoint("RIGHT", -12, 0)
	duty.stats:SetWidth(200)
	duty.stats:SetWordWrap(true)
	page.duty = duty
	page.scroll = Theme.Scroll(page, 0, -RUN_HEAD, W, PAGE_H - RUN_HEAD - 16, BAR_X)
	local body = page.scroll.body

	page.routesLabel = Theme.Section(body, L["SEC_ROUTES"], X + SB)
	page.routes = {}
	for index = 1, 5 do
		local row = CreateFrame("Frame", nil, body)
		row:SetSize(RW, 40)
		row.check = Theme.Check(row)
		row.check:SetPoint("LEFT", 2, 0)
		row.check:SetScript("OnClick", function()
			ns.Duty:SetEnabled(row.code, not row.check.on)
			row.check:SetOn(not row.check.on)
		end)
		row.plate = Theme.Row(CreateFrame("Frame", nil, row))
		row.plate:SetHeight(40)
		row.icon = Theme.Icon(row.plate, 34)
		row.icon:SetPoint("LEFT", 3, 0)
		row.name = Theme.Text(row.plate, "bold", 14, C.text)
		row.name:SetPoint("LEFT", 46, 1)
		row.name:SetWidth(RW - 30 - 46 - 90)
		row.price = CreateFrame("Button", nil, row.plate)
		row.price:SetSize(72, 26)
		row.price:SetPoint("RIGHT", -6, 0)
		Theme.Inset(row.price)
		row.price.text = Theme.Text(row.price, "title", 17, C.accent, "RIGHT")
		row.price.text:SetPoint("RIGHT", -8, 1)
		row.price:SetScript("OnClick", function()
			self:EditPrice(row.price, row.code)
		end)
		page.routes[index] = row
	end
	page.pointNote = Theme.Text(body, "body", 11, C.dim)
	page.pointNote:SetWidth(RW)

	page.helpersLabel = Theme.Text(body, "bold", 11, C.head)
	page.helpersLabel:SetText(L["HELPERS"])
	page.helpers = Theme.Segments(body, { L["HAVE"], L["SEEK"] }, function(index)
		ns.Duty:SetHelpers(index == 1)
	end)
	page.helpers:SetPoint("LEFT", page.helpersLabel, "RIGHT", 10, 0)
	page.payLabel = Theme.Text(body, "bold", 11, C.head)
	page.payLabel:SetText(L["PAYMENT"])
	page.pay = Theme.Segments(body, { L["AFTER"], L["BEFORE"] }, function(index)
		ns.Duty:SetPay(index == 1 and "A" or "B")
	end)
	page.pay:SetPoint("LEFT", page.payLabel, "RIGHT", 10, 0)
	page.reagent = CreateFrame("Frame", nil, body)
	page.reagent:SetSize(42, 24)
	Theme.Inset(page.reagent)
	page.reagent.text = Theme.Text(page.reagent, "title", 16, C.accent, "CENTER")
	page.reagent.text:SetPoint("CENTER", 0, 1)
	page.reagentLabel = Theme.Text(body, "bold", 11, C.head, "RIGHT")
	page.reagentLabel:SetPoint("RIGHT", page.reagent, "LEFT", -8, 0)
	page.whereNote = Theme.Text(body, "body", 11, C.dim)
	page.whereNote:SetWidth(RW)

	page.ordersLabel = Theme.Section(body, L["SEC_ORDERS"], X + SB)
	page.orders = {}
	for index = 1, 3 do
		page.orders[index] = self:BuildOrderRow(body)
	end
	page.noOrders = Theme.Text(body, "body", 11, C.dim)
	page.noOrders:SetText(L["NO_ORDERS"])
	page.chatLabel = Theme.Section(body, L["SEC_CHAT"], X + SB)
	page.chats = {}
	for index = 1, 3 do
		local row = CreateFrame("Frame", nil, body)
		row:SetSize(RW, 44)
		Theme.Row(row)
		row.name = Theme.Text(row, "bold", 13, C.text)
		row.name:SetPoint("TOPLEFT", 10, -7)
		row.text = Theme.Text(row, "body", 11, C.dim)
		row.text:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
		row.text:SetWidth(316)
		row.invite = Theme.Button(row, L["INVITE"], "dark", 116, 28)
		row.invite:SetPoint("RIGHT", -6, 0)
		row.invite:SetScript("OnClick", function()
			ns.Listen:Invite(row.sender)
		end)
		page.chats[index] = row
	end
	page.noSpells = Theme.Text(page, "body", 12, C.accent, "CENTER")
	page.noSpells:SetPoint("TOP", 0, -80)
	page.noSpells:SetWidth(W - 2 * X)
	page.noSpells:SetWordWrap(true)

	local footLine = Theme.Line(page)
	footLine:SetPoint("BOTTOMLEFT", X, RUN_FOOTER)
	footLine:SetPoint("BOTTOMRIGHT", -X, RUN_FOOTER)
	page.footLine = footLine
	page.hint = Theme.Text(page, "body", 11.5, C.dim)
	page.hint:SetPoint("BOTTOMLEFT", X, 24)
	page.hint:SetWordWrap(true)
	page.hint:SetText(L["HELPERS_HINT"])
	page.call = Theme.Button(page, L["CALL_HELPERS"], "dark", 190, 40)
	page.call:SetPoint("BOTTOMRIGHT", -22, 20)
	page.call:SetScript("OnClick", function()
		ns.Duty:CallHelpers()
	end)
	return page
end

-- Order row: accept and decline for new orders, a secure cast button once the buyer is in the group.
function UI:BuildOrderRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(RW, 46)
	Theme.Row(row)
	row.name = Theme.Text(row, "bold", 13, C.text)
	row.name:SetPoint("TOPLEFT", 10, -8)
	row.info = Theme.Text(row, "body", 11, C.dim)
	row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
	row.info:SetWidth(266)
	row.accept = Theme.Button(row, L["ACCEPT"], "primary", 106, 28)
	row.accept:SetPoint("RIGHT", -40, 0)
	row.accept:SetScript("OnClick", function()
		ns.Deal:Accept(row.deal)
	end)
	row.decline = Theme.CrossButton(row, 28)
	row.decline:SetPoint("RIGHT", -6, 0)
	row.decline:SetScript("OnClick", function()
		ns.Deal:Decline(row.deal, "busy")
	end)
	row.cast = Theme.Button(row, "", "primary", 156, 28, true)
	row.cast:SetPoint("RIGHT", -6, 0)
	row.status = Theme.Text(row, "bold", 12, C.green, "RIGHT")
	row.status:SetPoint("RIGHT", -12, 0)
	return row
end

-- Secure attributes change only out of combat.
function UI:SetCast(button, sale)
	if InCombatLockdown() then
		return
	end
	if sale.kind == "P" then
		local spell = ns.DestSpell(sale.code)
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", spell and ns.SpellName(spell) or nil)
		button:SetAttribute("unit", nil)
		button.label:SetText(L["OPEN_PORTAL"])
	else
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", ns.SpellName(ns.SUMMON_SPELL))
		button:SetAttribute("unit", ns.GroupUnit(sale.buyer))
		button.label:SetText(L["RITUAL"])
	end
end

function UI:UpdateRun(page)
	local class = ns.ProviderClass()
	local codes = ns.Duty:Codes()
	local onDuty = ns.Duty:OnDuty()
	local char = ns.db.char
	page.duty.switch:SetOn(onDuty)
	page.duty.label:SetText(onDuty and L["DUTY"] or L["OFF_DUTY"])
	page.duty.label:SetTextColor(unpack(onDuty and C.green or C.dim))
	page.duty.stats:SetText(ns.Format("DUTY_STATS", char.runTrips or 0, ns.Money(char.runEarned or 0)))
	local noSpells = #codes == 0
	page.noSpells:SetShown(noSpells)
	page.noSpells:SetText(class == "W" and L["NO_SPELLS_W"] or L["NO_SPELLS_M"])
	local isWarlock = class == "W" and not noSpells
	page.scroll:SetView(PAGE_H - RUN_HEAD - (isWarlock and RUN_FOOTER + 4 or 16))

	local y = -14
	page.routesLabel:SetText(class == "W" and L["SEC_POINT"] or L["SEC_ROUTES"])
	page.routesLabel:ClearAllPoints()
	page.routesLabel:SetPoint("TOPLEFT", X, y)
	page.routesLabel:SetShown(not noSpells)
	page.routesLabel.line:SetShown(not noSpells)
	y = y - 18
	local zone, sub = ns.Zone()
	for index, row in ipairs(page.routes) do
		local code = codes[index]
		row:SetShown(code ~= nil)
		if code then
			row.code = code
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", X, y)
			local isPoint = code == "*"
			row.check:SetShown(not isPoint)
			row.check:SetOn(ns.Duty:Enabled(code))
			row.plate:ClearAllPoints()
			row.plate:SetPoint("TOPLEFT", isPoint and 0 or 30, 0)
			row.plate:SetPoint("TOPRIGHT")
			row.name:SetText(isPoint and (sub ~= "" and sub or zone) or ns.DestName(code))
			row.name:SetTextColor(unpack((isPoint or ns.Duty:Enabled(code)) and C.text or C.dim))
			row.icon.icon:SetTexture(ns.SpellIcon(isPoint and ns.SUMMON_SPELL or ns.DestSpell(code)))
			row.price.text:SetText(ns.Money(ns.Duty:Price(code)))
			y = y - 46
		end
	end
	page.pointNote:ClearAllPoints()
	page.pointNote:SetPoint("TOPLEFT", X, y)
	page.pointNote:SetText(class == "W" and L["POINT_NOTE"] or "")
	if class == "W" then
		y = y - 22
		page.helpersLabel:ClearAllPoints()
		page.helpersLabel:SetPoint("TOPLEFT", X, y - 6)
		page.helpers:Select(char.helpers and 1 or 2)
		y = y - 32
	end
	page.helpersLabel:SetShown(class == "W" and not noSpells)
	page.helpers:SetShown(class == "W" and not noSpells)
	page.payLabel:ClearAllPoints()
	page.payLabel:SetPoint("TOPLEFT", X, y - 6)
	page.pay:Select(char.pay == "B" and 2 or 1)
	page.reagent:ClearAllPoints()
	page.reagent:SetPoint("TOPRIGHT", -(X + SB), y)
	page.reagent.text:SetText(tostring(ns.Duty:Reagents() or 0))
	page.reagentLabel:SetText(class == "W" and L["SHARDS"] or L["RUNES"])
	for _, region in ipairs({ page.payLabel, page.pay, page.reagent, page.reagentLabel }) do
		region:SetShown(not noSpells)
	end
	y = y - 34
	page.whereNote:ClearAllPoints()
	page.whereNote:SetPoint("TOPLEFT", X, y)
	local where = class == "M" and not noSpells
	page.whereNote:SetText(where and L["WHERE_NOTE"]:format(place(zone, sub)) or "")
	y = y - (where and 30 or 10)

	page.ordersLabel:ClearAllPoints()
	page.ordersLabel:SetPoint("TOPLEFT", X, y)
	y = y - 16
	local sales = ns.Deal:SaleList()
	page.noOrders:ClearAllPoints()
	page.noOrders:SetPoint("TOPLEFT", X, y - 2)
	page.noOrders:SetShown(#sales == 0)
	if #sales == 0 then
		y = y - 22
	end
	for index, row in ipairs(page.orders) do
		local sale = sales[index]
		local show = sale ~= nil
		if InCombatLockdown() then
			show = row:IsShown()
		end
		if not InCombatLockdown() then
			row:SetShown(show)
		end
		if sale then
			row.deal = sale.deal
			if not InCombatLockdown() then
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", X, y)
			end
			row.name:SetText(sale.buyer)
			row.name:SetTextColor(unpack(Theme.ClassColor(sale.cls)))
			local where = sale.kind == "P" and ns.DestName(sale.code) or (sale.sub ~= "" and sale.sub or sale.zone)
			local state
			if sale.state == "incoming" then
				state = L["S_WAITING"]:format(string.format("0:%02d", math.max(0, math.ceil(ns.Deal.ANSWER_WAIT - (GetTime() - sale.since)))))
			elseif sale.state == "accepted" then
				state = L["S_INVITED"]
			elseif sale.state == "done" then
				state = L["S_DONE"]
			else
				state = sale.paid >= sale.price and L["S_PAID"] or L["S_INGROUP"]
			end
			row.info:SetText(where .. ", " .. ns.Money(sale.price) .. ", " .. state)
			row.accept:SetShown(sale.state == "incoming")
			row.decline:SetShown(sale.state == "incoming")
			local casting = sale.state == "grouped" and not sale.delivered
			if not InCombatLockdown() then
				row.cast:SetShown(casting)
				if casting then
					self:SetCast(row.cast, sale)
				end
			end
			row.status:SetShown(sale.state == "done")
			row.status:SetText(L["S_DONE"])
			y = y - 52
		end
	end

	y = y - 8
	local chats = ns.Listen.list
	page.chatLabel:ClearAllPoints()
	page.chatLabel:SetPoint("TOPLEFT", X, y)
	page.chatLabel:SetShown(#chats > 0)
	page.chatLabel.line:SetShown(#chats > 0)
	if #chats > 0 then
		y = y - 16
	end
	for index, row in ipairs(page.chats) do
		local entry = chats[index]
		row:SetShown(entry ~= nil)
		if entry then
			row.sender = entry.sender
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", X, y)
			row.name:SetText(entry.sender)
			row.name:SetTextColor(unpack(Theme.ClassColor(entry.cls)))
			row.text:SetText(entry.text .. ", " .. (entry.channel or ""))
			y = y - 50
		end
	end
	page.footLine:SetShown(isWarlock)
	page.hint:SetShown(isWarlock)
	page.call:SetShown(isWarlock)
	page.ordersLabel:SetShown(not noSpells)
	page.ordersLabel.line:SetShown(not noSpells)
	if noSpells then
		return 0
	end
	return -y + 12
end

function UI:EditPrice(anchor, code)
	local box = self.priceBox
	if not box then
		box = CreateFrame("EditBox", nil, self.frame)
		box:SetSize(72, 26)
		box:SetFrameStrata("DIALOG")
		box:SetAutoFocus(true)
		box:SetFont(Theme.FONTS.title, 17, "")
		box:SetTextColor(unpack(C.accent))
		box:SetJustifyH("RIGHT")
		box:SetTextInsets(6, 9, 0, 0)
		Theme.Inset(box)
		box:SetScript("OnEscapePressed", function(edit)
			edit:Hide()
		end)
		box:SetScript("OnEnterPressed", function(edit)
			local value = tonumber((edit:GetText() or ""):gsub(",", "."), 10)
			if value and value > 0 then
				ns.Duty:SetPrice(edit.code, value * 10000)
			end
			edit:Hide()
			self:Refresh()
		end)
		box:SetScript("OnEditFocusLost", function(edit)
			edit:Hide()
		end)
		self.priceBox = box
	end
	box.code = code
	box:ClearAllPoints()
	box:SetAllPoints(anchor)
	local gold = ns.Duty:Price(code) / 10000
	box:SetText(gold == math.floor(gold) and tostring(gold) or string.format("%.2f", gold))
	box:Show()
	box:HighlightText()
	GameTooltip:SetOwner(box, "ANCHOR_TOP")
	GameTooltip:SetText(L["PRICE_PROMPT"], 1, 1, 1)
	GameTooltip:Show()
	box:SetScript("OnHide", function()
		GameTooltip:Hide()
	end)
end

-- Admin --------------------------------------------------------------------------------

function UI:BuildAdmin(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()
	page:Hide()
	page.scroll = Theme.Scroll(page, 0, 0, W, PAGE_H - 16, BAR_X)
	local body = page.scroll.body
	page.sections = {}
	for _, key in ipairs({ "REPORTS", "BANS", "PAIRS" }) do
		local block = { label = Theme.Section(body, L["SEC_" .. key], X + SB), rows = {} }
		for index = 1, 5 do
			local row = CreateFrame("Frame", nil, body)
			row:SetSize(RW, 26)
			row.text = Theme.Text(row, "body", 11.5, C.text)
			row.text:SetPoint("LEFT")
			row.text:SetWidth(RW - 100)
			if key ~= "PAIRS" then
				row.button = Theme.Button(row, key == "BANS" and L["UNBAN"] or L["BAN"], "dark", 90, 24)
				row.button:SetPoint("RIGHT")
			end
			block.rows[index] = row
		end
		block.none = Theme.Text(body, "body", 11.5, C.dim)
		block.none:SetText(L["NONE"])
		page.sections[key] = block
	end
	return page
end

function UI:UpdateAdmin(page)
	local data = ns.RealmData()
	local lists = {
		REPORTS = data.reports,
		BANS = data.bans.list,
		PAIRS = ns.Admin:Pairs(),
	}
	local y = -8
	for _, key in ipairs({ "REPORTS", "BANS", "PAIRS" }) do
		local block = page.sections[key]
		block.label:ClearAllPoints()
		block.label:SetPoint("TOPLEFT", X, y)
		y = y - 20
		local list = lists[key]
		block.none:ClearAllPoints()
		block.none:SetPoint("TOPLEFT", X, y)
		block.none:SetShown(#list == 0)
		if #list == 0 then
			y = y - 22
		end
		for index, row in ipairs(block.rows) do
			local entry = list[index]
			row:SetShown(entry ~= nil)
			if entry then
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", X, y)
				if key == "REPORTS" then
					row.text:SetText(L["REPORT_LINE"]:format(entry.reporter, entry.target, L["REASON_" .. entry.reason]))
					row.button:SetScript("OnClick", function()
						ns.Admin:Ban(entry.target, entry.reason)
					end)
				elseif key == "BANS" then
					row.text:SetText(entry.name .. ", " .. (L["REASON_" .. entry.reason] or entry.reason))
					row.button:SetScript("OnClick", function()
						ns.Admin:Unban(entry.name)
					end)
				else
					row.text:SetText(ns.Format("PAIR_LINE", entry.provider, entry.buyer, entry.count))
				end
				y = y - 28
			end
		end
		y = y - 10
	end
	return -y + 14
end
