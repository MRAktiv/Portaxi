-- Moderation. Ban lists count only when the game server names an admin from Admins.lua as the
-- sender; relayed copies are never trusted. Reports wait until an admin is seen in the channel.
local _, ns = ...
local addon, Util, Proto = ns.addon, ns.Util, ns.Proto

local Admin = addon:NewModule("Admin", "AceEvent-3.0", "AceTimer-3.0")
ns.Admin = Admin

Admin.BROADCAST_EVERY = 15 * 60
Admin.SEEN_FOR = 600
Admin.MAX_REPORTS = 200
Admin.MAX_PENDING = 20
Admin.PAIR_MIN = 3
Admin.seen = {}

-- Name with the border between given and family name kept: "Mraktiv Dev" and "Mraktivd Ev" differ.
local function exactName(name)
	return Util.Lower((tostring(name):gsub("[%s%-]+", " ")))
end

-- Forever only: other versions have realms, where a one-word character name could copy an admin's.
function ns.IsAdmin(name)
	if not Util.regionalNames or not Util.Usable(name) or name == "" then
		return false
	end
	local region = GetCurrentRegionName and GetCurrentRegionName()
	for _, admin in ipairs(ns.ADMINS) do
		if admin.region == region and exactName(admin.name) == exactName(name) then
			return true
		end
	end
	return false
end

function ns.AmAdmin()
	return ns.IsAdmin(ns.MyName())
end

function ns.IsBanned(name)
	local key = Util.NameKey(name)
	if not key or ns.IsAdmin(name) then
		return false
	end
	return Admin:BanSet()[key] ~= nil
end

function Admin:OnEnable()
	self:ScheduleRepeatingTimer("Tick", 60)
end

-- Bans shipped in the code (Forever names, so Forever only) plus the live list from an admin.
function Admin:BanSet()
	if not self.banSet then
		local set = {}
		for _, ban in ipairs(Util.regionalNames and ns.CODE_BANS or {}) do
			set[Util.NameKey(ban.name)] = ban
		end
		for _, ban in ipairs(ns.RealmData().bans.list) do
			set[Util.NameKey(ban.name)] = ban
		end
		self.banSet = set
	end
	return self.banSet
end

function Admin:Changed()
	self.banSet = nil
	self:SendMessage("PORTAXI_BANS")
	self:SendMessage("PORTAXI_BOARD")
end

function Admin:Tick()
	if ns.AmAdmin() and ns.Net:ChannelID() and (not self.lastBroadcast or GetTime() - self.lastBroadcast >= Admin.BROADCAST_EVERY) then
		self:BroadcastBans()
	end
end

function Admin:BroadcastBans()
	local data = ns.RealmData().bans
	self.lastBroadcast = GetTime()
	ns.Net:Broadcast(Proto.EncodeBans(data.version, data.list), "BULK")
end

function Admin:OnBans(sender, bans)
	if not ns.IsAdmin(sender) then
		return
	end
	self.seen[Util.NameKey(sender)] = { name = sender, at = GetTime() }
	local data = ns.RealmData().bans
	if bans.version > data.version then
		data.version, data.list = bans.version, bans.bans
		self:Changed()
	end
	self:FlushReports()
end

local function setBan(name, entry)
	local data = ns.RealmData().bans
	local key = Util.NameKey(name)
	for index = #data.list, 1, -1 do
		if Util.NameKey(data.list[index].name) == key then
			table.remove(data.list, index)
		end
	end
	if entry then
		table.insert(data.list, entry)
	end
	data.version = math.max(data.version + 1, ns.Now())
end

function Admin:Ban(name, reason)
	if not ns.AmAdmin() or ns.IsAdmin(name) then
		return false
	end
	setBan(name, { name = name, reason = reason or "other", time = ns.Now() })
	self:Changed()
	self:BroadcastBans()
	return true
end

function Admin:Unban(name)
	if not ns.AmAdmin() then
		return false
	end
	setBan(name, nil)
	self:Changed()
	self:BroadcastBans()
	return true
end

-- Reports --------------------------------------------------------------------------------

function Admin:Report(target, reason, deal)
	local pending = ns.db.char.pendingReports
	table.insert(pending, { target = target, reason = reason, deal = deal, at = ns.Now() })
	while #pending > Admin.MAX_PENDING do
		table.remove(pending, 1)
	end
	self:FlushReports()
end

function Admin:OnlineAdmin()
	for _, seen in pairs(self.seen) do
		if GetTime() - seen.at <= Admin.SEEN_FOR then
			return seen.name
		end
	end
	return nil
end

function Admin:FlushReports()
	local pending = ns.db.char.pendingReports
	local admin = #pending > 0 and self:OnlineAdmin()
	if not admin then
		return
	end
	for _, report in ipairs(pending) do
		ns.Net:Whisper(admin, Proto.EncodeReport(report.target, report.reason, report.deal))
	end
	wipe(pending)
end

function Admin:OnReport(sender, report)
	if not ns.AmAdmin() then
		return
	end
	local reports = ns.RealmData().reports
	table.insert(reports, 1, { reporter = sender, target = report.target, reason = report.reason, deal = report.deal, at = ns.Now() })
	while #reports > Admin.MAX_REPORTS do
		table.remove(reports)
	end
	self:SendMessage("PORTAXI_REPORTS")
end

-- Same buyer and provider together PAIR_MIN or more times in the top window, most first.
function Admin:Pairs()
	local now, counts, list = ns.Now(), {}, {}
	for _, trip in pairs(ns.RealmData().ledger.trips) do
		if trip.ok and now - trip.time <= ns.Ledger.TOP_SPAN then
			local key = Util.NameKey(trip.provider) .. "|" .. Util.NameKey(trip.buyer)
			local entry = counts[key]
			if not entry then
				entry = { provider = trip.provider, buyer = trip.buyer, count = 0 }
				counts[key] = entry
				list[#list + 1] = entry
			end
			entry.count = entry.count + 1
		end
	end
	local result = {}
	for _, entry in ipairs(list) do
		if entry.count >= Admin.PAIR_MIN then
			result[#result + 1] = entry
		end
	end
	table.sort(result, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.provider < b.provider
	end)
	return result
end
