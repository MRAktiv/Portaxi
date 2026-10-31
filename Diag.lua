-- /portaxi diag: what only the live client can show, in a window to copy from.
local _, ns = ...
local addon, L, Util, Theme, Ledger = ns.addon, ns.L, ns.Util, ns.Theme, ns.Ledger

local Diag = addon:NewModule("Diag")
ns.Diag = Diag

local function has(path)
	local value = _G
	for part in path:gmatch("[^%.]+") do
		value = type(value) == "table" and value[part] or nil
	end
	return value ~= nil and "yes" or "NO"
end

function Diag:Collect()
	local lines = { L["DIAG_HEADER"] }
	local function out(...)
		local parts = {}
		for index = 1, select("#", ...) do
			parts[#parts + 1] = tostring((select(index, ...)))
		end
		lines[#lines + 1] = table.concat(parts, " ")
	end
	local version, build, _, interface = GetBuildInfo()
	out("client", version, build, "interface", interface, "project", WOW_PROJECT_ID, "locale", GetLocale(), "lang", ns.Language())
	out("me", ns.MyName(), "class", ns.ProviderClass() or "-", "faction", ns.Faction(), "level", UnitLevel("player"), "admin", tostring(ns.AmAdmin()),
		"region", tostring(GetCurrentRegionName and GetCurrentRegionName()))
	local zone, sub, zoneID = ns.Zone()
	out("zone", zone, "/", sub, "map", zoneID, "instance", tostring(ns.InInstance()), "lockdown", tostring(C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()))
	out("channel", tostring(ns.Net:ChannelID()), "join", tostring(ns.Net.joinResult), "restored", tostring(ns.Net.restored), "zoneChannels", tostring(ns.Net.ZoneChannelsJoined()))
	local mages, locks = 0, 0
	for _, offer in pairs(ns.Net.offers) do
		if offer.cls == "M" then
			mages = mages + 1
		else
			locks = locks + 1
		end
	end
	out("offers", "mages", mages, "locks", locks, "sent", ns.Net.sent, "received", ns.Net.received)
	local ledger = ns.RealmData().ledger
	local total, ok, witnessed, reviewed = 0, 0, 0, 0
	for _, trip in pairs(ledger.trips) do
		total = total + 1
		ok = ok + (trip.ok and 1 or 0)
		witnessed = witnessed + (trip.witnessed and 1 or 0)
		reviewed = reviewed + (trip.stars and 1 or 0)
	end
	out("trips", total, "ok", ok, "witnessed", witnessed, "reviewed", reviewed, "halves", Util.Count(ledger.halves), "earlyReviews", Util.Count(ledger.reviews))
	local bans = ns.RealmData().bans
	out("bans", "version", bans.version, "live", #bans.list, "code", #ns.CODE_BANS, "adminOnline", tostring(ns.Admin:OnlineAdmin()), "pendingReports", #ns.db.char.pendingReports)
	for _, code in ipairs(ns.DEST_ORDER[ns.Faction() or "A"]) do
		local spell = ns.DestSpell(code)
		out("dest", code, ns.DestName(code), "spell", spell, tostring(ns.SpellName(spell)), "known", tostring(ns.KnowsSpell(spell)),
			"map", ns.DESTS[code].map, "here", tostring(ns.AtDest(code, zone, zoneID)))
	end
	out("ritual", tostring(ns.SpellName(ns.SUMMON_SPELL)), "known", tostring(ns.KnowsSpell(ns.SUMMON_SPELL)), "reagents", tostring(ns.Duty:Reagents()))
	out("duty", tostring(ns.Duty:OnDuty()), "codes", table.concat(ns.Duty:Codes(), ","), "extra", table.concat(ns.Duty:ExtraPortals(), ","))
	for _, api in ipairs({ "C_SummonInfo.GetSummonConfirmSummoner", "InitiateTrade", "C_PartyInfo.InviteUnit", "GetTargetTradeMoney", "GetPlayerTradeMoney",
		"C_Map.GetBestMapForUnit", "C_CurrencyInfo.GetCoinTextureString", "issecretvalue", "C_SpellBook.GetSpellBookItemInfo", "C_SpellBook.IsSpellKnown" }) do
		out("api", api, has(api))
	end
	local deal = ns.Deal.buy
	out("buy", deal and (deal.state .. " " .. deal.provider .. " " .. deal.code) or "-", "sales", Util.Count(ns.Deal.sales))
	out("stats providers", Util.Count(Ledger.Stats(ledger, ns.Now(), ns.IsBanned)))
	return lines
end

function Diag:Run()
	local frame = self.frame
	if not frame then
		frame = CreateFrame("Frame", "PortaxiDiag", UIParent)
		frame:SetSize(560, 420)
		frame:SetPoint("CENTER")
		frame:SetFrameStrata("DIALOG")
		frame:EnableMouse(true)
		frame:SetMovable(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
		Theme.Window(frame, nil, function()
			frame:Hide()
		end)
		local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 24, -24)
		scroll:SetPoint("BOTTOMRIGHT", -46, 62)
		local box = CreateFrame("EditBox", nil, scroll)
		box:SetMultiLine(true)
		box:SetAutoFocus(false)
		box:SetWidth(480)
		box:SetFont(Theme.FONTS.body, 11, "")
		box:SetTextColor(unpack(Theme.C.text))
		box:SetScript("OnEscapePressed", function()
			frame:Hide()
		end)
		scroll:SetScrollChild(box)
		frame.box = box
		local close = Theme.Button(frame, L["CLOSE"], "dark", 110, 28)
		close:SetPoint("BOTTOMRIGHT", -24, 22)
		close:SetScript("OnClick", function()
			frame:Hide()
		end)
		frame.close = close
		self.frame = frame
	end
	frame.close.label:SetText(L["CLOSE"])
	local text = table.concat(self:Collect(), "\n")
	frame.box:SetText(text)
	frame:Show()
	frame.box:SetFocus()
	frame.box:HighlightText()
	return text
end
