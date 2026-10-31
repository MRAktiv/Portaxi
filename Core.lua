-- Startup: saved data, minimap button and slash commands.
local ADDON_NAME, ns = ...
local addon, L, Theme = ns.addon, ns.L, ns.Theme

local function tooltip(tip)
	tip:AddLine(L["TITLE"])
	local mages, locks = 0, 0
	for _, offer in pairs(ns.Net.offers) do
		if offer.fac == ns.Faction() then
			if offer.cls == "M" then
				mages = mages + 1
			else
				locks = locks + 1
			end
		end
	end
	tip:AddLine(ns.Format("TOOLTIP_COUNTS", mages, locks), 1, 1, 1)
	tip:AddLine(" ")
	tip:AddLine(L["TOOLTIP_LEFT"], 0.6, 0.6, 0.6)
end

-- Entry in the minimap addon compartment, named in Portaxi.toc.
function Portaxi_OnAddonCompartmentClick()
	ns.UI:Toggle()
end

function Portaxi_OnAddonCompartmentEnter(_, button)
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	tooltip(GameTooltip)
	GameTooltip:Show()
end

function Portaxi_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end

function addon:OnInitialize()
	ns.db = LibStub("AceDB-3.0"):New("PortaxiDB", ns.DEFAULTS, true)
	ns.SetLanguage(ns.db.global.lang or ns.DefaultLanguage())
	local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
		type = "launcher",
		text = L["TITLE"],
		icon = Theme.ICON,
		OnClick = function()
			ns.UI:Toggle()
		end,
		OnTooltipShow = tooltip,
	})
	local icon = LibStub("LibDBIcon-1.0")
	icon:Register(ADDON_NAME, launcher, ns.db.profile.minimap)
	-- Round sign centred in the 53 px minimap ring.
	icon:SetButtonBackground(ADDON_NAME, nil, 20, "TOPLEFT", 6.3, -5.7)
	icon:SetButtonIcon(ADDON_NAME, nil, 20, "TOPLEFT", 6.3, -5.7)
	self:RegisterChatCommand("portaxi", "OnSlash")
	self:RegisterChatCommand("ptx", "OnSlash")
end

function addon:OnEnable()
	if not ns.db.profile.firstRunShown then
		ns.db.profile.firstRunShown = true
		ns.Print(L["FIRST_RUN"])
	end
end

function addon:OnSlash(input)
	local command = (input or ""):lower():match("^%s*(%S*)")
	if command == "diag" then
		ns.Diag:Run()
	elseif command == "debug" then
		ns.db.profile.debug = not ns.db.profile.debug
		ns.Print("debug", tostring(ns.db.profile.debug))
	else
		ns.UI:Toggle()
	end
end
