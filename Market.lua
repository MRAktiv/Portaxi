-- Live board: offers of mages and warlocks on duty, grouped by destination for the buyer.
local _, ns = ...
local Util = ns.Util

local Market = {}
ns.Market = Market

Market.TTL = 150

function Market.Add(offers, key, name, offer, now)
	offer.key, offer.name, offer.seen = key, name, now
	offers[key] = offer
end

function Market.Remove(offers, key)
	offers[key] = nil
end

function Market.Expire(offers, now)
	for key, offer in pairs(offers) do
		if now - offer.seen > Market.TTL then
			offers[key] = nil
		end
	end
end

-- 2: same subzone, 1: same zone, 0: elsewhere. Zones by map id when both know it: names follow each client's language.
function Market.Near(offer, viewer)
	local sameZone
	if offer.map and viewer.map then
		sameZone = offer.map == viewer.map
	else
		sameZone = offer.zone == viewer.zone
	end
	if not sameZone then
		return 0
	end
	if offer.sub ~= "" and offer.sub == viewer.sub then
		return 2
	end
	return 1
end

local function entry(offer, price, viewer, stats)
	local s = stats[offer.key]
	return {
		key = offer.key, name = offer.name, level = offer.level, price = price, zone = offer.zone, map = offer.map, sub = offer.sub,
		pay = offer.pay, helpers = offer.helpers, near = Market.Near(offer, viewer),
		rating = s and s.rating or nil, trips = s and s.trips or 0,
	}
end

local function byQuality(a, b)
	if a.near ~= b.near then
		return a.near > b.near
	end
	local ra, rb = a.rating or -1, b.rating or -1
	if ra ~= rb then
		return ra > rb
	end
	if a.price ~= b.price then
		return a.price < b.price
	end
	return a.key < b.key
end

local function visible(offer, viewer, isBanned)
	return offer.fac == viewer.fac and offer.key ~= viewer.key and not isBanned(offer.name)
end

local function minPrice(providers)
	local low
	for _, provider in ipairs(providers) do
		low = (not low or provider.price < low) and provider.price or low
	end
	return low
end

-- Destinations of the viewer's faction, capitals first, with the mages offering each one.
function Market.Portals(offers, viewer, stats, isBanned)
	local byCode, extra = {}, {}
	for _, code in ipairs(ns.DEST_ORDER[viewer.fac] or {}) do
		byCode[code] = {}
	end
	for _, offer in pairs(offers) do
		if offer.cls == "M" and visible(offer, viewer, isBanned) then
			for _, item in ipairs(offer.items) do
				if not byCode[item.code] then
					byCode[item.code] = {}
					extra[#extra + 1] = item.code
				end
				table.insert(byCode[item.code], entry(offer, item.price, viewer, stats))
			end
		end
	end
	table.sort(extra)
	local list = {}
	local order = {}
	for _, code in ipairs(ns.DEST_ORDER[viewer.fac] or {}) do
		order[#order + 1] = code
	end
	for _, code in ipairs(extra) do
		order[#order + 1] = code
	end
	for _, code in ipairs(order) do
		local providers = byCode[code]
		table.sort(providers, byQuality)
		list[#list + 1] = { code = code, providers = providers, count = #providers, minPrice = minPrice(providers) }
	end
	return list
end

-- Summon points: one row per place where warlocks stand. Ready rows (helpers present) go first.
function Market.Summons(offers, viewer, stats, isBanned)
	local byPoint, list = {}, {}
	for _, offer in pairs(offers) do
		if offer.cls == "W" and visible(offer, viewer, isBanned) then
			local id = offer.zone .. "/" .. offer.sub
			local point = byPoint[id]
			if not point then
				point = { id = id, label = offer.sub ~= "" and offer.sub or offer.zone, zone = offer.zone, sub = offer.sub, providers = {}, ready = false }
				byPoint[id] = point
				list[#list + 1] = point
			end
			local provider = entry(offer, offer.items[1].price, viewer, stats)
			provider.near = 0
			table.insert(point.providers, provider)
			point.ready = point.ready or offer.helpers
		end
	end
	for _, point in ipairs(list) do
		table.sort(point.providers, function(a, b)
			if a.helpers ~= b.helpers then
				return a.helpers
			end
			return byQuality(a, b)
		end)
		point.count = #point.providers
		point.minPrice = minPrice(point.providers)
	end
	table.sort(list, function(a, b)
		if a.ready ~= b.ready then
			return a.ready
		end
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.label < b.label
	end)
	return list
end

function Market.CountWithProviders(list)
	local count = 0
	for _, row in ipairs(list) do
		if row.count > 0 then
			count = count + 1
		end
	end
	return count
end
