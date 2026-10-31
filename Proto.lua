-- Wire format of every Portaxi message. Fields are separated by "~"; lists by "," and ";".
-- Decoders validate everything and return nil on anything unexpected.
local _, ns = ...
local Util = ns.Util

local Proto = {}
ns.Proto = Proto

Proto.VERSION = "1"
local SEP = "~"
local MAX_PRICE = 100000000
local MAX_LEVEL = 80
local MAX_MAP = 99999
local MAX_PLACE = 128
Proto.MAX_ITEMS = 12
Proto.MAX_RECORDS = 100
Proto.MAX_MINE = 50

local function int(value, low, high)
	local number = tonumber(value)
	if not number or number ~= math.floor(number) or number < low or number > high then
		return nil
	end
	return number
end

local function join(...)
	local parts = { ... }
	for index = 1, select("#", ...) do
		parts[index] = parts[index] == nil and "" or tostring(parts[index])
	end
	return table.concat(parts, SEP)
end

local function fields(text, head, count)
	if type(text) ~= "string" or text:sub(1, 1) ~= head then
		return nil
	end
	local parts = Util.Split(text, SEP)
	if parts[2] ~= Proto.VERSION or #parts ~= count then
		return nil
	end
	return parts
end

local function validDeal(deal)
	return type(deal) == "string" and deal:match("^[%w]+$") and #deal >= 6 and #deal <= 12
end

-- Destination code: a capital ("OG") or any other portal by spell id ("S12345"); "*" is a summon.
function Proto.ValidCode(code)
	return type(code) == "string" and (code:match("^%u%u$") or code:match("^S%d+$") or code == "*") and true or false
end

-- "|" starts UI escape codes (textures, colours, links); no real name or place has it.
local function validName(name)
	return type(name) == "string" and name ~= "" and #name <= 48 and not name:find("[~;,|%c]")
end

local function validPlace(text)
	return #text <= MAX_PLACE and not text:find("[|%c]")
end

-- Offer: a mage or warlock on duty. items = { { code, price }, ... }; map: zone map id, 0 when unknown.
function Proto.EncodeOffer(offer)
	local items = {}
	for _, item in ipairs(offer.items) do
		items[#items + 1] = item.code .. "=" .. item.price
	end
	return join("O", Proto.VERSION, offer.cls, offer.fac, offer.level, Util.Field(offer.zone), Util.Field(offer.sub),
		offer.pay, offer.helpers and 1 or 0, table.concat(items, ","), offer.map or 0)
end

function Proto.DecodeOffer(text)
	local p = fields(text, "O", 11)
	if not p then
		return nil
	end
	local map = int(p[11], 0, MAX_MAP)
	local offer = { cls = p[3], fac = p[4], level = int(p[5], 1, MAX_LEVEL), zone = p[6], sub = p[7], pay = p[8], helpers = p[9] == "1", items = {},
		map = map ~= 0 and map or nil }
	if (offer.cls ~= "M" and offer.cls ~= "W") or (offer.fac ~= "A" and offer.fac ~= "H") or not offer.level
		or (offer.pay ~= "A" and offer.pay ~= "B") or offer.zone == "" or not map or not validPlace(offer.zone) or not validPlace(offer.sub) then
		return nil
	end
	if p[10] == "" then
		return nil
	end
	local entries = Util.Split(p[10], ",")
	if #entries > Proto.MAX_ITEMS then
		return nil
	end
	for _, entry in ipairs(entries) do
		local code, price = entry:match("^([^=]+)=(%d+)$")
		price = int(price, 1, MAX_PRICE)
		if not code or not price or not Proto.ValidCode(code) then
			return nil
		end
		if (offer.cls == "W") ~= (code == "*") then
			return nil
		end
		offer.items[#offer.items + 1] = { code = code, price = price }
	end
	return offer
end

function Proto.EncodeOff()
	return join("X", Proto.VERSION)
end

function Proto.DecodeOff(text)
	return fields(text, "X", 2) and true or nil
end

-- Request from a buyer to one provider; cls is the buyer's class file ("PRIEST").
function Proto.EncodeRequest(request)
	return join("R", Proto.VERSION, request.deal, request.code, request.price, request.level, Util.Field(request.zone), Util.Field(request.sub), request.cls)
end

function Proto.DecodeRequest(text)
	local p = fields(text, "R", 9)
	if not p then
		return nil
	end
	local request = { deal = p[3], code = p[4], price = int(p[5], 1, MAX_PRICE), level = int(p[6], 1, MAX_LEVEL), zone = p[7], sub = p[8], cls = p[9] }
	if not validDeal(request.deal) or not Proto.ValidCode(request.code) or not request.price or not request.level
		or not request.cls:match("^%u+$") or #request.cls > 16 or not validPlace(request.zone) or not validPlace(request.sub) then
		return nil
	end
	return request
end

-- Short answers about one deal: A accept, D decline (with a reason), Z cancelled by the buyer.
function Proto.EncodeAnswer(kind, deal, reason)
	if kind == "D" then
		return join("D", Proto.VERSION, deal, reason or "busy")
	end
	return join(kind, Proto.VERSION, deal)
end

function Proto.DecodeAnswer(text)
	local head = type(text) == "string" and text:sub(1, 1)
	local p = (head == "A" or head == "Z") and fields(text, head, 3) or (head == "D" and fields(text, "D", 4))
	if not p or not validDeal(p[3]) then
		return nil
	end
	return head, p[3], p[4]
end

-- Confirmation of a finished trip by one side (role P provider, B buyer).
function Proto.EncodeConfirm(c)
	return join("C", Proto.VERSION, c.deal, c.role, c.provider, c.buyer, c.kind, c.code, c.price, c.paid, c.blevel, c.time)
end

function Proto.DecodeConfirm(text)
	local p = fields(text, "C", 12)
	if not p then
		return nil
	end
	local c = { deal = p[3], role = p[4], provider = p[5], buyer = p[6], kind = p[7], code = p[8],
		price = int(p[9], 1, MAX_PRICE), paid = int(p[10], 0, MAX_PRICE * 10), blevel = int(p[11], 1, MAX_LEVEL), time = int(p[12], 0, 4102444800) }
	if not validDeal(c.deal) or (c.role ~= "P" and c.role ~= "B") or not validName(c.provider) or not validName(c.buyer)
		or (c.kind ~= "P" and c.kind ~= "S") or not Proto.ValidCode(c.code) or not c.price or not c.paid or not c.blevel or not c.time then
		return nil
	end
	if (c.kind == "S") ~= (c.code == "*") then
		return nil
	end
	return c
end

-- Review by the buyer: stars 1-5 and tag bits.
Proto.TAGS = { FAST = 1, POLITE = 2, SLOW = 4, PRICEY = 8 }

function Proto.EncodeReview(deal, stars, tags)
	return join("V", Proto.VERSION, deal, stars, tags or 0)
end

function Proto.DecodeReview(text)
	local p = fields(text, "V", 5)
	if not p or not validDeal(p[3]) then
		return nil
	end
	local stars, tags = int(p[4], 1, 5), int(p[5], 0, 15)
	if not stars or not tags then
		return nil
	end
	return { deal = p[3], stars = stars, tags = tags }
end

-- History sync: Q asks for records newer than "since"; S answers with witnessed records.
function Proto.EncodeQuery(qid, since)
	return join("Q", Proto.VERSION, qid, since)
end

function Proto.DecodeQuery(text)
	local p = fields(text, "Q", 4)
	if not p or not validDeal(p[3]) then
		return nil
	end
	local since = int(p[4], 0, 4102444800)
	if not since then
		return nil
	end
	return { qid = p[3], since = since }
end

local function encodeRecord(r)
	return table.concat({ r.deal, r.provider, r.buyer, r.kind, r.code, r.price, r.blevel, r.time, r.stars or 0, r.tags or 0 }, ",")
end

local function decodeRecord(text)
	local p = Util.Split(text, ",")
	if #p ~= 10 then
		return nil
	end
	local r = { deal = p[1], provider = p[2], buyer = p[3], kind = p[4], code = p[5], price = int(p[6], 1, MAX_PRICE),
		blevel = int(p[7], 1, MAX_LEVEL), time = int(p[8], 0, 4102444800), stars = int(p[9], 0, 5), tags = int(p[10], 0, 15) }
	if not validDeal(r.deal) or not validName(r.provider) or not validName(r.buyer) or (r.kind ~= "P" and r.kind ~= "S")
		or not Proto.ValidCode(r.code) or not r.price or not r.blevel or not r.time or not r.stars or not r.tags then
		return nil
	end
	if (r.kind == "S") ~= (r.code == "*") then
		return nil
	end
	if r.stars == 0 then
		r.stars, r.tags = nil, nil
	end
	return r
end

function Proto.EncodeSync(qid, records)
	local list = {}
	for index, record in ipairs(records) do
		list[index] = encodeRecord(record)
	end
	return join("S", Proto.VERSION, qid, table.concat(list, ";"))
end

-- Bad records are skipped one by one; the rest of the answer still counts. Longer answers than a client sends are dropped.
function Proto.DecodeSync(text)
	local p = fields(text, "S", 4)
	if not p or not validDeal(p[3]) then
		return nil
	end
	local records = {}
	if p[4] ~= "" then
		local entries = Util.Split(p[4], ";")
		if #entries > Proto.MAX_RECORDS then
			return nil
		end
		for _, entry in ipairs(entries) do
			local record = decodeRecord(entry)
			if record then
				records[#records + 1] = record
			end
		end
	end
	return { qid = p[3], records = records }
end

-- A buyer's own trips of the last month: deal, provider, stars and tags (0 when not rated).
function Proto.EncodeMine(list)
	local entries = {}
	for index, entry in ipairs(list) do
		entries[index] = table.concat({ entry.deal, entry.provider, entry.stars or 0, entry.tags or 0 }, ",")
	end
	return join("H", Proto.VERSION, table.concat(entries, ";"))
end

function Proto.DecodeMine(text)
	local p = fields(text, "H", 3)
	if not p or p[3] == "" then
		return nil
	end
	local entries = Util.Split(p[3], ";")
	if #entries > Proto.MAX_MINE then
		return nil
	end
	local list = {}
	for _, entry in ipairs(entries) do
		local q = Util.Split(entry, ",")
		local stars, tags = int(q[3], 0, 5), int(q[4], 0, 15)
		if #q ~= 4 or not validDeal(q[1]) or not validName(q[2]) or not stars or not tags then
			return nil
		end
		list[#list + 1] = { deal = q[1], provider = q[2], stars = stars > 0 and stars or nil, tags = stars > 0 and tags or nil }
	end
	return list
end

-- Ban list from an admin: version and entries { name, reason, time }.
function Proto.EncodeBans(version, bans)
	local list = {}
	for _, ban in ipairs(bans) do
		list[#list + 1] = table.concat({ ban.name, ban.reason, ban.time }, ",")
	end
	return join("B", Proto.VERSION, version, table.concat(list, ";"))
end

function Proto.DecodeBans(text)
	local p = fields(text, "B", 4)
	if not p then
		return nil
	end
	local version = int(p[3], 0, 4102444800)
	if not version then
		return nil
	end
	local bans = {}
	if p[4] ~= "" then
		for _, entry in ipairs(Util.Split(p[4], ";")) do
			local q = Util.Split(entry, ",")
			local time = int(q[3], 0, 4102444800)
			if #q ~= 3 or not validName(q[1]) or not q[2]:match("^%l+$") or not time then
				return nil
			end
			bans[#bans + 1] = { name = q[1], reason = q[2], time = time }
		end
	end
	return { version = version, bans = bans }
end

-- Complaint to an admin.
Proto.REASONS = { "pay", "noshow", "fake", "other" }

function Proto.EncodeReport(target, reason, deal)
	return join("P", Proto.VERSION, target, reason, deal or "")
end

function Proto.DecodeReport(text)
	local p = fields(text, "P", 5)
	if not p or not validName(p[3]) then
		return nil
	end
	local known = false
	for _, reason in ipairs(Proto.REASONS) do
		known = known or reason == p[4]
	end
	if not known or (p[5] ~= "" and not validDeal(p[5])) then
		return nil
	end
	return { target = p[3], reason = p[4], deal = p[5] ~= "" and p[5] or nil }
end
