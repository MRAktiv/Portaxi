-- Words that mark a portal or summon request in public chat, Russian and English.
-- A trailing "*" matches any word starting with the stem; other entries match whole words.
local _, ns = ...

ns.WORDS = {
	sell = { "wts", "selling", "sell", "lfw", "продам", "продаю", "кидаю", "открываю", "даю" },
	portal = { "port*", "portal*", "порт*", "портал*" },
	summon = { "summon*", "summ", "summs", "sum", "smn", "сумон*", "суммон*", "саммон*", "самон*", "призыв*", "призов*" },
	dest = {
		SW = { "sw", "storm", "stormwind*", "шторм", "штормград*", "св" },
		IF = { "ironforge*", "iron", "иф", "стальгорн*", "айрон*" },
		DN = { "darn", "darnassus*", "дарн", "дарнас*" },
		OG = { "og", "org", "orgri", "orgrimmar*", "орг", "огри", "оргрим*" },
		UC = { "uc", "undercity*", "under", "андер", "ундер", "подгород*", "пг" },
		TB = { "tb", "thunder*", "bluff", "тб", "тандер*", "громов*", "утес*", "утёс*" },
		EX = { "exo", "exodar*", "экзо", "экзодар*" },
		SM = { "silvermoon*", "луносвет*" },
		SH = { "shatt*", "shat", "шатт*", "шат", "шаттрат*" },
		TH = { "thera", "theramore*", "терамор*" },
		ST = { "stonard*", "каменор*" },
	},
	-- Checked on the original text: "if" in lower case is an ordinary English word.
	destUpper = { IF = { "IF" } },
}
