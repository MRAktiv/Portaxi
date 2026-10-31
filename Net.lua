-- Channel and direct messages: offers, requests, trip confirmations, reviews, history sync, buyers' own trip lists, bans.
-- Addons cannot send from inside instances, so everything goes out only in the open world.
local _, ns = ...
local addon, Util, Proto, Ledger, Market = ns.addon, ns.Util, ns.Proto, ns.Ledger, ns.Market

local Net = addon:NewModule("Net", "AceEvent-3.0", "AceTimer-3.0", "AceComm-3.0")
ns.Net = Net

local PREFIX = "Portaxi"
local CHANNEL = "Portaxi"
local JOIN_WAIT = 60
local MAX_CHANNELS = 20
local ZONE_CHANNEL = Enum.PermanentChatChannelType and Enum.PermanentChatChannelType.Zone or 1
local SYNC_DELAY = 30
local SYNC_LIMIT = Proto.MAX_RECORDS
local ANSWER_MIN, ANSWER_MAX = 2, 12
local QUERY_SPAN = 30 * 86400
local QUERY_GAP = 600
local PRUNE_EVERY = 60

Net.PREFIX, Net.CHANNEL = PREFIX, CHANNEL
Net.offers = {}
Net.tally = {}
Net.answered = {}
Net.queried = {}
Net.received, Net.sent = 0, 0

-- True once a game zone channel holds a number; a channel joined before them takes /1.
function Net.ZoneChannelsJoined()
	if not (C_ChatInfo and C_ChatInfo.GetChannelInfoFromIdentifier) then
		return true
	end
	for index = 1, MAX_CHANNELS do
		local id = GetChannelName(index)
		if type(id) == "number" and id > 0 then
			local info = C_ChatInfo.GetChannelInfoFromIdentifier(tostring(id))
			if info and info.channelType == ZONE_CHANNEL then
				return true
			end
		end
	end
	return false
end

function Net:OnEnable()
	self.enabledAt = GetTime()
	if self:ChannelID() and not Net.ZoneChannelsJoined() then
		self.restored = true
		pcall(LeaveChannelByName, CHANNEL)
	end
	self:RegisterComm(PREFIX, "OnComm")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateChannel")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateChannel")
	local filter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
	if filter then
		for _, event in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL" }) do
			filter(event, Net.HideOwnChannel)
		end
	end
	self:ScheduleRepeatingTimer("Tick", 10)
	self:ScheduleTimer("UpdateChannel", 5)
end

-- Chat filter: hides notices and text of the Portaxi channel. The first argument is the message.
function Net.HideOwnChannel(_, _, ...)
	for index = 2, select("#", ...) do
		local value = select(index, ...)
		if type(value) == "string" and Util.Usable(value) and (value == CHANNEL or value:match("^%d+%. " .. CHANNEL .. "$")) then
			return true
		end
	end
	return false
end

function Net:Active()
	return not ns.InInstance()
end

function Net:ChannelID()
	local id = GetChannelName(CHANNEL)
	if type(id) == "number" and id > 0 then
		return id
	end
	return nil
end

function Net:UpdateChannel()
	if self:ChannelID() or not self:Active() then
		return
	end
	if not Net.ZoneChannelsJoined() and GetTime() - self.enabledAt < JOIN_WAIT then
		return
	end
	local join = JoinTemporaryChannel or JoinChannelByName
	local ok, err = pcall(join, CHANNEL)
	self.joinResult = ok and "ok" or tostring(err)
end

function Net:Tick()
	self:UpdateChannel()
	local now = ns.Now()
	Market.Expire(self.offers, GetTime())
	if self:ChannelID() and not self.synced and GetTime() - self.enabledAt >= SYNC_DELAY then
		self.synced = true
		self:Query()
	end
	if not self.pruned or now - self.pruned > PRUNE_EVERY then
		self.pruned = now
		Ledger.Prune(ns.RealmData().ledger, now)
	end
	self:SendMessage("PORTAXI_BOARD")
end

function Net:Broadcast(text, priority)
	local id = self:ChannelID()
	if not id or not self:Active() then
		return false
	end
	self:SendCommMessage(PREFIX, text, "CHANNEL", id, priority or "NORMAL")
	self.sent = self.sent + 1
	return true
end

function Net:Whisper(name, text)
	if not self:Active() then
		return false
	end
	self:SendCommMessage(PREFIX, text, "WHISPER", name, "ALERT")
	self.sent = self.sent + 1
	return true
end

-- Own trip half: kept locally at once, then sent; the other side's half completes it.
function Net:SendConfirm(confirm)
	local ledger = ns.RealmData().ledger
	local trip = Ledger.AddHalf(ledger, confirm, ns.MyName(), ns.Now())
	self:Broadcast(Proto.EncodeConfirm(confirm))
	if trip then
		self:SendMessage("PORTAXI_TRIP", trip)
	end
	self:SendMessage("PORTAXI_LEDGER")
end

function Net:SendReview(deal, stars, tags)
	local ledger = ns.RealmData().ledger
	Ledger.AddReview(ledger, { deal = deal, stars = stars, tags = tags }, ns.MyName(), ns.Now())
	self:Broadcast(Proto.EncodeReview(deal, stars, tags))
	self:SendMessage("PORTAXI_LEDGER")
end

-- History sync: ask once after login for trips newer than the newest one already known.
function Net:Query()
	local now = ns.Now()
	local latest = Ledger.Latest(ns.RealmData().ledger)
	local since = latest > 0 and math.max(latest - 3600, now - QUERY_SPAN) or now - QUERY_SPAN
	self.myQuery = Util.NewID(8)
	self:Broadcast(Proto.EncodeQuery(self.myQuery, since), "BULK")
	self:SendMine()
end

-- Own purchases of the last month, newest first: other clients count a trip they only heard of from witnesses once its buyer lists it.
function Net:SendMine()
	local now, list = ns.Now(), {}
	for deal, entry in pairs(ns.db.char.deals) do
		if now - entry.time <= Ledger.KEEP then
			list[#list + 1] = { deal = deal, provider = entry.provider, stars = entry.stars, tags = entry.tags, time = entry.time }
		end
	end
	if #list == 0 then
		return
	end
	table.sort(list, function(a, b)
		return a.time > b.time
	end)
	while #list > Proto.MAX_MINE do
		list[#list] = nil
	end
	self:Broadcast(Proto.EncodeMine(list), "BULK")
end

-- Answers after a random pause and leaves out records two others already vouched for; one query per player in QUERY_GAP.
function Net:OnQuery(sender, query)
	local key = Util.NameKey(sender)
	if self.answered[query.qid] or (self.queried[key] and GetTime() - self.queried[key] < QUERY_GAP) then
		return
	end
	self.answered[query.qid], self.queried[key] = true, GetTime()
	local ledger = ns.RealmData().ledger
	if #Ledger.Witnessed(ledger, query.since, 1) == 0 then
		return
	end
	self.tally[query.qid] = self.tally[query.qid] or {}
	local delay = ANSWER_MIN + math.random() * (ANSWER_MAX - ANSWER_MIN)
	self:ScheduleTimer(function()
		local skip = {}
		for deal, vouchers in pairs(self.tally[query.qid] or {}) do
			if Util.Count(vouchers) >= Ledger.MIN_VOUCH then
				skip[deal] = true
			end
		end
		local records = Ledger.Witnessed(ledger, query.since, SYNC_LIMIT, skip)
		if #records > 0 then
			self:Broadcast(Proto.EncodeSync(query.qid, records), "BULK")
		end
	end, delay)
end

function Net:OnSync(sender, sync)
	local ledger = ns.RealmData().ledger
	local now = ns.Now()
	local tally = self.tally[sync.qid]
	local voucher = Util.NameKey(sender)
	for _, record in ipairs(sync.records) do
		Ledger.AddVouch(ledger, record, sender, now)
		if tally then
			tally[record.deal] = tally[record.deal] or {}
			tally[record.deal][voucher] = true
		end
	end
	self:SendMessage("PORTAXI_LEDGER")
end

function Net:OnComm(_, text, distribution, sender)
	if type(text) ~= "string" or not Util.Usable(sender) then
		return
	end
	if Util.SameName(sender, ns.MyName()) then
		return
	end
	self.received = self.received + 1
	local head = text:sub(1, 1)
	local now = ns.Now()
	if distribution == "WHISPER" then
		if head == "R" then
			local request = Proto.DecodeRequest(text)
			if request and not ns.IsBanned(sender) then
				ns.Deal:OnRequest(sender, request)
			end
		elseif head == "A" or head == "D" or head == "Z" then
			local kind, deal, reason = Proto.DecodeAnswer(text)
			if kind then
				ns.Deal:OnAnswer(sender, kind, deal, reason)
			end
		elseif head == "P" then
			local report = Proto.DecodeReport(text)
			if report then
				ns.Admin:OnReport(sender, report)
			end
		end
		return
	end
	if distribution ~= "CHANNEL" then
		return
	end
	if head == "O" then
		local offer = Proto.DecodeOffer(text)
		if offer then
			for index = #offer.items, 1, -1 do
				if not ns.IsOfferCode(offer.items[index].code) then
					table.remove(offer.items, index)
				end
			end
		end
		if offer and #offer.items > 0 then
			Market.Add(self.offers, Util.NameKey(sender), sender, offer, GetTime())
			self:SendMessage("PORTAXI_BOARD")
		end
	elseif head == "X" then
		if Proto.DecodeOff(text) then
			Market.Remove(self.offers, Util.NameKey(sender))
			self:SendMessage("PORTAXI_BOARD")
		end
	elseif head == "C" then
		local confirm = Proto.DecodeConfirm(text)
		if confirm then
			local trip = Ledger.AddHalf(ns.RealmData().ledger, confirm, sender, now)
			if trip then
				self:SendMessage("PORTAXI_TRIP", trip)
				self:SendMessage("PORTAXI_LEDGER")
			end
		end
	elseif head == "V" then
		local review = Proto.DecodeReview(text)
		if review and Ledger.AddReview(ns.RealmData().ledger, review, sender, now) then
			self:SendMessage("PORTAXI_LEDGER")
		end
	elseif head == "Q" then
		local query = Proto.DecodeQuery(text)
		if query then
			self:OnQuery(sender, query)
		end
	elseif head == "S" then
		local sync = Proto.DecodeSync(text)
		if sync then
			self:OnSync(sender, sync)
		end
	elseif head == "H" then
		local list = Proto.DecodeMine(text)
		if list then
			Ledger.AddAttest(ns.RealmData().ledger, list, sender, now)
			self:SendMessage("PORTAXI_LEDGER")
		end
	elseif head == "B" then
		local bans = Proto.DecodeBans(text)
		if bans then
			ns.Admin:OnBans(sender, bans)
		end
	end
end
