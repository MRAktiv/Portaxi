-- Trip ledger: which trips count, which reviews count, and the top list built from them.
-- A trip counts when this client heard both sides confirm it within WINDOW (a witness),
-- or when at least MIN_VOUCH other witnesses, neither of them a party, vouch for the same record
-- within VOUCH_WINDOW and the buyer lists the trip among his own.
local _, ns = ...
local Util = ns.Util

local Ledger = {}
ns.Ledger = Ledger

Ledger.WINDOW = 600
Ledger.DRIFT = 300
Ledger.MIN_VOUCH = 2
Ledger.VOUCH_WINDOW = 600
Ledger.MAX_OPEN = 10
Ledger.MAX_VOUCH_LOAD = 300
Ledger.KEEP = 31 * 86400
Ledger.TOP_SPAN = 30 * 86400
Ledger.PAIR_GAP = 7 * 86400
Ledger.REVIEW_SPAN = 86400
Ledger.MIN_BUYER_LEVEL = 10
Ledger.TOP_MIN_TRIPS = 5
Ledger.TOP_MIN_RATING = 4.0
Ledger.TOP_SIZE = 10
Ledger.HALF_TTL = 900

function Ledger.New()
	return { trips = {}, halves = {}, reviews = {}, attest = {}, load = {} }
end

-- Open entries of one sender in a table keyed by anything; caps what one player can make every client keep.
local function openBy(map, owner)
	local count = 0
	for _, entry in pairs(map) do
		count = count + (entry.owner == owner and 1 or 0)
	end
	return count
end

local function signature(r)
	return table.concat({ Util.NameKey(r.provider), Util.NameKey(r.buyer), r.kind, r.code, r.price, r.blevel, r.time }, ",")
end
Ledger.Signature = signature

local function newTrip(r)
	return { deal = r.deal, provider = r.provider, buyer = r.buyer, kind = r.kind, code = r.code, price = r.price, blevel = r.blevel, time = r.time }
end

local function reviewKey(deal, author)
	return deal .. "|" .. Util.NameKey(author)
end

local function applyPendingReview(state, trip)
	local key = reviewKey(trip.deal, trip.buyer)
	local review = state.reviews[key]
	if review and trip.ok and review.at - trip.time <= Ledger.REVIEW_SPAN then
		trip.stars, trip.tags, trip.reviewSeen = review.stars, review.tags, true
		state.reviews[key] = nil
	end
end

-- One side's confirmation as heard on the channel. Returns the trip when this half completes it.
-- The first half heard ties the deal id to its two names: a copy of the id with other names is ignored.
function Ledger.AddHalf(state, half, sender, now)
	local claimed = half.role == "P" and half.provider or half.buyer
	if not Util.SameName(claimed, sender) or Util.SameName(half.provider, half.buyer) then
		return nil
	end
	if math.abs(half.time - now) > Ledger.DRIFT then
		return nil
	end
	local existing = state.trips[half.deal]
	if existing and existing.witnessed then
		return nil
	end
	local parties = Util.NameKey(half.provider) .. "|" .. Util.NameKey(half.buyer)
	local slot = state.halves[half.deal]
	if slot and slot.parties ~= parties then
		return nil
	end
	if not slot then
		local owner = Util.NameKey(sender)
		if openBy(state.halves, owner) >= Ledger.MAX_OPEN then
			return nil
		end
		slot = { parties = parties, owner = owner }
		state.halves[half.deal] = slot
	end
	slot[half.role] = { half = half, at = now }
	local p, b = slot.P, slot.B
	if not (p and b) then
		return nil
	end
	state.halves[half.deal] = nil
	local ph, bh = p.half, b.half
	local same = ph.kind == bh.kind and ph.code == bh.code and ph.price == bh.price
	if not same or math.abs(p.at - b.at) > Ledger.WINDOW then
		return nil
	end
	if ph.paid < ph.price or bh.paid < bh.price then
		return nil
	end
	local record = { deal = ph.deal, provider = ph.provider, buyer = ph.buyer, kind = ph.kind, code = ph.code, price = ph.price,
		blevel = math.min(ph.blevel, bh.blevel), time = ph.time }
	local trip = newTrip(record)
	trip.witnessed, trip.ok = true, true
	state.trips[trip.deal] = trip
	applyPendingReview(state, trip)
	return trip
end

-- New records one voucher may start within VOUCH_WINDOW; repeats of a record he already vouched for are free.
local function takeLoad(state, voucher, now)
	local load = state.load[voucher]
	if not load or now - load.since > Ledger.VOUCH_WINDOW then
		load = { since = now, count = 0 }
		state.load[voucher] = load
	end
	if load.count >= Ledger.MAX_VOUCH_LOAD then
		return false
	end
	load.count = load.count + 1
	return true
end

-- Review of a trip from witnesses' votes: the one value with the most votes, at least MIN_VOUCH; a tie changes nothing.
local function countVotes(trip)
	local counts, best, bestCount, tied = {}, nil, 0, false
	for _, vote in pairs(trip.reviewVotes) do
		counts[vote] = (counts[vote] or 0) + 1
	end
	for vote, count in pairs(counts) do
		if count > bestCount then
			best, bestCount, tied = vote, count, false
		elseif count == bestCount then
			tied = true
		end
	end
	if best and not tied and bestCount >= Ledger.MIN_VOUCH then
		local stars, tags = best:match("^(%d+):(%d+)$")
		trip.stars, trip.tags = tonumber(stars), tonumber(tags)
	end
end

-- A record vouched for by another witness during sync. Vouches count only while fresh, so two
-- characters of one account taking turns never make a pair.
function Ledger.AddVouch(state, record, sender, now)
	if Util.SameName(sender, record.provider) or Util.SameName(sender, record.buyer) or Util.SameName(record.provider, record.buyer) then
		return nil
	end
	if record.time > now + Ledger.DRIFT or now - record.time > Ledger.KEEP then
		return nil
	end
	local voucher = Util.NameKey(sender)
	local trip = state.trips[record.deal]
	local sig = signature(record)
	if not (trip and trip.ok) then
		local candidate = trip and trip.candidates[sig]
		if not (candidate and candidate.vouchers[voucher]) and not takeLoad(state, voucher, now) then
			return nil
		end
		if not trip then
			trip = { deal = record.deal, candidates = {} }
			state.trips[record.deal] = trip
		end
		if not candidate then
			candidate = { record = record, vouchers = {} }
			trip.candidates[sig] = candidate
		end
		candidate.vouchers[voucher] = now
		local fresh = 0
		for _, at in pairs(candidate.vouchers) do
			fresh = fresh + (now - at <= Ledger.VOUCH_WINDOW and 1 or 0)
		end
		if fresh >= Ledger.MIN_VOUCH then
			for key, value in pairs(newTrip(candidate.record)) do
				trip[key] = value
			end
			trip.ok, trip.candidates = true, nil
			applyPendingReview(state, trip)
		end
	end
	if trip.ok and signature(trip) == sig and record.stars and not trip.reviewSeen then
		trip.reviewVotes = trip.reviewVotes or {}
		trip.reviewVotes[voucher] = record.stars .. ":" .. record.tags
		countVotes(trip)
	end
	return trip.ok and trip or nil
end

-- A review heard straight from its author.
function Ledger.AddReview(state, review, sender, now)
	local trip = state.trips[review.deal]
	if trip and trip.ok then
		if not Util.SameName(sender, trip.buyer) or now - trip.time > Ledger.REVIEW_SPAN then
			return nil
		end
		trip.stars, trip.tags, trip.reviewSeen = review.stars, review.tags, true
		return trip
	end
	local key, owner = reviewKey(review.deal, sender), Util.NameKey(sender)
	if not state.reviews[key] and openBy(state.reviews, owner) >= Ledger.MAX_OPEN then
		return nil
	end
	state.reviews[key] = { stars = review.stars, tags = review.tags, owner = owner, at = now }
	return nil
end

-- A buyer's own list of trips, heard from the buyer; it replaces his previous list.
function Ledger.AddAttest(state, list, sender, now)
	local deals = {}
	for _, entry in ipairs(list) do
		deals[entry.deal] = { provider = Util.NameKey(entry.provider), stars = entry.stars, tags = entry.tags }
	end
	state.attest[Util.NameKey(sender)] = { at = now, deals = deals }
end

-- The buyer's own entry for a trip, when he listed it with the same provider.
function Ledger.Attested(state, trip)
	local mine = state.attest[Util.NameKey(trip.buyer)]
	local entry = mine and mine.deals[trip.deal]
	return entry and entry.provider == Util.NameKey(trip.provider) and entry or nil
end

-- Records this client may vouch for: only trips it witnessed itself, newest first.
function Ledger.Witnessed(state, since, limit, skip)
	local list = {}
	for deal, trip in pairs(state.trips) do
		if trip.witnessed and trip.time > since and not (skip and skip[deal]) then
			list[#list + 1] = {
				deal = deal, provider = trip.provider, buyer = trip.buyer, kind = trip.kind, code = trip.code, price = trip.price,
				blevel = trip.blevel, time = trip.time, stars = trip.reviewSeen and trip.stars or nil, tags = trip.reviewSeen and trip.tags or nil,
			}
		end
	end
	table.sort(list, function(a, b)
		return a.time > b.time
	end)
	while limit and #list > limit do
		list[#list] = nil
	end
	return list
end

-- Candidates live only while one of their vouches is fresh.
function Ledger.Prune(state, now)
	for deal, trip in pairs(state.trips) do
		if (trip.time and now - trip.time > Ledger.KEEP) or (not trip.ok and not trip.time and not next(trip.candidates or {})) then
			state.trips[deal] = nil
		elseif trip.candidates then
			for sig, candidate in pairs(trip.candidates) do
				local fresh = false
				for _, at in pairs(candidate.vouchers) do
					fresh = fresh or now - at <= Ledger.VOUCH_WINDOW
				end
				if not fresh then
					trip.candidates[sig] = nil
				end
			end
			if not next(trip.candidates) then
				state.trips[deal] = nil
			end
		end
	end
	for buyer, mine in pairs(state.attest) do
		if now - mine.at > Ledger.KEEP then
			state.attest[buyer] = nil
		end
	end
	for voucher, load in pairs(state.load) do
		if now - load.since > Ledger.VOUCH_WINDOW then
			state.load[voucher] = nil
		end
	end
	for deal, slot in pairs(state.halves) do
		local at = (slot.P or slot.B).at
		if now - at > Ledger.HALF_TTL then
			state.halves[deal] = nil
		end
	end
	for deal, review in pairs(state.reviews) do
		if now - review.at > Ledger.REVIEW_SPAN then
			state.reviews[deal] = nil
		end
	end
end

-- Newest accepted trip time; the next sync asks for what came after it.
function Ledger.Latest(state)
	local latest = 0
	for _, trip in pairs(state.trips) do
		if trip.ok and trip.time > latest then
			latest = trip.time
		end
	end
	return latest
end

-- Per provider: counted trips, distinct buyers, rating from each buyer's latest review, tags, last ratings.
-- A trip known from witnesses alone counts once its buyer listed it; his own word on it beats witnesses' votes.
-- isBanned(name) hides a banned provider and drops trips with a banned buyer.
function Ledger.Stats(state, now, isBanned)
	isBanned = isBanned or function()
		return false
	end
	local byProvider = {}
	for _, trip in pairs(state.trips) do
		local own = trip.ok and Ledger.Attested(state, trip)
		if trip.ok and (trip.witnessed or own) and now - trip.time <= Ledger.TOP_SPAN and trip.blevel >= Ledger.MIN_BUYER_LEVEL
			and not isBanned(trip.provider) and not isBanned(trip.buyer) then
			local key = Util.NameKey(trip.provider)
			local entry = byProvider[key]
			if not entry then
				entry = { name = trip.provider, kinds = {}, buyers = {} }
				byProvider[key] = entry
			end
			entry.kinds[trip.kind] = (entry.kinds[trip.kind] or 0) + 1
			local buyer = Util.NameKey(trip.buyer)
			local view = { time = trip.time, stars = trip.stars, tags = trip.tags }
			if own and not trip.reviewSeen then
				view.stars, view.tags = own.stars, own.tags
			end
			entry.buyers[buyer] = entry.buyers[buyer] or {}
			table.insert(entry.buyers[buyer], view)
		end
	end
	local stats = {}
	for key, entry in pairs(byProvider) do
		local counted, buyers, starSum, rated = 0, 0, 0, 0
		local tags, recent = {}, {}
		for _, trips in pairs(entry.buyers) do
			buyers = buyers + 1
			table.sort(trips, function(a, b)
				return a.time < b.time
			end)
			local lastCounted
			local latestReview
			for _, trip in ipairs(trips) do
				if not lastCounted or trip.time - lastCounted >= Ledger.PAIR_GAP then
					counted = counted + 1
					lastCounted = trip.time
				end
				if trip.stars then
					latestReview = trip
				end
			end
			if latestReview then
				starSum = starSum + latestReview.stars
				rated = rated + 1
				recent[#recent + 1] = latestReview
				for name, bit in pairs(ns.Proto.TAGS) do
					if math.floor(latestReview.tags / bit) % 2 == 1 then
						tags[name] = (tags[name] or 0) + 1
					end
				end
			end
		end
		table.sort(recent, function(a, b)
			return a.time > b.time
		end)
		local last = {}
		for index = 1, math.min(5, #recent) do
			last[index] = recent[index].stars
		end
		local kind = (entry.kinds.S or 0) > (entry.kinds.P or 0) and "S" or "P"
		stats[key] = { name = entry.name, kind = kind, trips = counted, buyers = buyers, rating = rated > 0 and starSum / rated or nil,
			rated = rated, tags = tags, last = last }
	end
	return stats
end

-- Top list for one kind: P mages, S warlocks.
function Ledger.Top(stats, kind, limit)
	limit = limit or Ledger.TOP_SIZE
	local list = {}
	for key, entry in pairs(stats) do
		if entry.kind == kind and entry.trips >= Ledger.TOP_MIN_TRIPS and entry.rating and entry.rating >= Ledger.TOP_MIN_RATING then
			list[#list + 1] = { key = key, name = entry.name, trips = entry.trips, rating = entry.rating, stats = entry }
		end
	end
	table.sort(list, function(a, b)
		if a.trips ~= b.trips then
			return a.trips > b.trips
		end
		if a.rating ~= b.rating then
			return a.rating > b.rating
		end
		return a.key < b.key
	end)
	while #list > limit do
		list[#list] = nil
	end
	return list
end

-- Place of one provider among all eligible ones of the kind, or nil.
function Ledger.Place(stats, kind, key)
	local list = Ledger.Top(stats, kind, math.huge)
	for index, entry in ipairs(list) do
		if entry.key == key then
			return index
		end
	end
	return nil
end
