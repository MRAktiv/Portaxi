-- Public chat for a provider on duty: portal and summon requests go to "From chat".
local _, ns = ...
local addon, ChatWatch = ns.addon, ns.ChatWatch

local Listen = addon:NewModule("Listen", "AceEvent-3.0", "AceTimer-3.0")
ns.Listen = Listen

Listen.list = {}

local EVENTS = { CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_WHISPER = true }

function Listen:OnEnable()
	for event in pairs(EVENTS) do
		self:RegisterEvent(event, "OnChat")
	end
	self:ScheduleRepeatingTimer("Expire", 15)
end

function Listen:OnChat(event, text, sender, _, _, _, _, _, _, channelName, _, _, guid)
	if not ns.Duty:OnDuty() or not ns.Usable(text) or not ns.Usable(sender) then
		return
	end
	local name = Ambiguate and Ambiguate(sender, "none") or sender
	if ns.Util.SameName(name, ns.MyName()) or ns.IsBanned(name) or ns.GroupUnit(name) then
		return
	end
	local parsed = ChatWatch.Parse(text)
	if parsed and parsed.code and not ns.DESTS[parsed.code] then
		parsed.code = nil
	end
	local class = ns.ProviderClass()
	if not parsed or (parsed.kind == "P") ~= (class == "M") then
		return
	end
	local where = event == "CHAT_MSG_CHANNEL" and ns.Usable(channelName) and channelName or event:match("CHAT_MSG_(%u+)")
	local cls = ns.Usable(guid) and guid and GetPlayerInfoByGUID and select(2, GetPlayerInfoByGUID(guid))
	ChatWatch.Add(self.list, name, parsed, text, where, GetTime(), ns.Usable(cls) and cls or nil)
	self:SendMessage("PORTAXI_CHAT")
end

function Listen:Expire()
	local before = #self.list
	ChatWatch.Expire(self.list, GetTime())
	if #self.list ~= before then
		self:SendMessage("PORTAXI_CHAT")
	end
end

function Listen:Invite(name)
	ns.Deal:Invite(name)
	ChatWatch.Remove(self.list, name)
	self:SendMessage("PORTAXI_CHAT")
end
