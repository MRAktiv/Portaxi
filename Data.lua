-- Game data: mage portals, summoning and reagents. Ids come from the client tables of builds 1.15.9, 1.60.1 and 2.5.6
-- (SkillLineAbility, SpellName, UiMap). map: the zone a portal lands in; from: first client interface that teaches it.
local _, ns = ...

ns.DESTS = {
	SW = { spell = 10059, map = 1453 },
	IF = { spell = 11416, map = 1455 },
	DN = { spell = 11419, map = 1457 },
	OG = { spell = 11417, map = 1454 },
	UC = { spell = 11418, map = 1458 },
	TB = { spell = 11420, map = 1456 },
	EX = { spell = 32266, map = 1947, from = 20000 },
	SM = { spell = 32267, map = 1954, from = 20000 },
	SH = { spell = { A = 33691, H = 35717 }, map = 1955, from = 20000 },
	TH = { spell = 49360, map = 1445, from = 20000 },
	ST = { spell = 49361, map = 1435, from = 20000 },
}
ns.DEST_ORDER = { A = { "SW", "IF", "DN", "EX", "SH", "TH" }, H = { "OG", "UC", "TB", "SM", "SH", "ST" } }

-- Keeps only the portals the running client version teaches.
function ns.ApplyClient(interface)
	for code, dest in pairs(ns.DESTS) do
		if (dest.from or 0) > interface then
			ns.DESTS[code] = nil
		end
	end
	for _, order in pairs(ns.DEST_ORDER) do
		for index = #order, 1, -1 do
			if not ns.DESTS[order[index]] then
				table.remove(order, index)
			end
		end
	end
end

if GetBuildInfo then
	ns.ApplyClient(select(4, GetBuildInfo()))
end

ns.SUMMON_SPELL = 698
ns.PORTAL_RUNE = 17032
ns.SOUL_SHARD = 6265
