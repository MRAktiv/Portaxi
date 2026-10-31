-- "Gold and stone" look: bronze frame, plaque and medallion, lacquered buttons, board rows and paper tickets,
-- all drawn from the textures in Media\Skin.
local _, ns = ...

local Theme = {}
ns.Theme = Theme

local MEDIA = "Interface\\AddOns\\Portaxi\\Media\\"
local SKIN = MEDIA .. "Skin\\"
Theme.MEDIA = MEDIA
Theme.SKIN = SKIN
Theme.ICON = MEDIA .. "logo"

Theme.FONTS = {
	title = MEDIA .. "Fonts\\Forum-Regular.ttf",
	body = MEDIA .. "Fonts\\Onest-Regular.ttf",
	bold = MEDIA .. "Fonts\\Onest-SemiBold.ttf",
}

local function rgb(hex, alpha)
	return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, alpha or 1 }
end
Theme.RGB = rgb

Theme.C = {
	text = rgb("EFE2C6"),
	dim = rgb("A8977A"),
	accent = rgb("F0C060"),
	head = rgb("C9A35E"),
	trimDim = rgb("6B4F26"),
	green = rgb("78E678"),
	red = rgb("E0583C"),
	pick = rgb("FFC878", 0.08),
	medal = { rgb("E8B860"), rgb("C9CED8"), rgb("C98A55") },
	ink = rgb("2E1E12"),
	inkText = rgb("342618"),
	inkSoft = rgb("785C3E"),
	inkLine = rgb("AA8C62"),
	seal = rgb("961C14"),
	sealRing = rgb("B08030"),
	buyerLink = rgb("185278"),
	sellerLink = rgb("8A5A1E"),
	badgeText = rgb("0C1E0E"),
}
local C = Theme.C

-- file, texture width and height, corner in texture pixels, corner on screen.
local SLICES = {
	frame = { "frame", 256, 256, 64, 32 },
	button = { "button-on", 128, 64, 20, 10 },
	dark = { "tab", 128, 64, 18, 9 },
	tabOn = { "tab-on", 128, 64, 18, 9 },
	inset = { "inset", 64, 64, 16, 8 },
	row = { "row", 64, 64, 12, 6 },
	rowSel = { "row-sel", 64, 64, 12, 6 },
	glow = { "glow", 128, 128, 40, 20 },
	scrollTrack = { "scroll-track", 16, 64, 8, 4 },
	scrollThumb = { "scroll-thumb", 16, 64, 8, 3 },
}

function Theme.Text(parent, font, size, color, justify, flat)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(Theme.FONTS[font], size, "")
	text:SetTextColor(unpack(color or C.text))
	text:SetJustifyH(justify or "LEFT")
	text:SetWordWrap(false)
	if not flat then
		text:SetShadowOffset(1, -1)
		text:SetShadowColor(0, 0, 0, 0.85)
	end
	return text
end

function Theme.Fill(frame, color, layer)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
	texture:SetAllPoints()
	texture:SetColorTexture(unpack(color))
	return texture
end

function Theme.Border(frame, color, layer)
	local sides = {}
	for index, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
		local side = frame:CreateTexture(nil, layer or "BORDER")
		side:SetColorTexture(unpack(color))
		side:SetPoint(spec[1])
		side:SetPoint(spec[2])
		if spec[3] then
			side:SetWidth(spec[3])
		else
			side:SetHeight(spec[4])
		end
		sides[index] = side
	end
	return sides
end

function Theme.Line(parent, color)
	local line = parent:CreateTexture(nil, "BORDER")
	line:SetColorTexture(unpack(color or C.trimDim))
	line:SetHeight(1)
	return line
end

-- Nine pieces: corners keep their size, edges and the centre stretch. outset grows it past the frame.
local SLICE = {}
SLICE.__index = SLICE

function Theme.Slice(frame, key, layer, sublevel, outset)
	local file, tw, th, corner, size = unpack(SLICES[key])
	local u, v, o = corner / tw, corner / th, outset or 0
	local function piece(left, right, top, bottom)
		local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
		texture:SetTexture(SKIN .. file)
		texture:SetTexCoord(left, right, top, bottom)
		return texture
	end
	local s = setmetatable({ pieces = {} }, SLICE)
	local tl, tr = piece(0, u, 0, v), piece(1 - u, 1, 0, v)
	local bl, br = piece(0, u, 1 - v, 1), piece(1 - u, 1, 1 - v, 1)
	tl:SetPoint("TOPLEFT", -o, o)
	tr:SetPoint("TOPRIGHT", o, o)
	bl:SetPoint("BOTTOMLEFT", -o, -o)
	br:SetPoint("BOTTOMRIGHT", o, -o)
	for _, texture in ipairs({ tl, tr, bl, br }) do
		texture:SetSize(size, size)
	end
	local top, bottom = piece(u, 1 - u, 0, v), piece(u, 1 - u, 1 - v, 1)
	local left, right, middle = piece(0, u, v, 1 - v), piece(1 - u, 1, v, 1 - v), piece(u, 1 - u, v, 1 - v)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
	top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
	bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
	bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
	left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
	right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
	middle:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT")
	middle:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
	s.pieces = { tl, tr, bl, br, top, bottom, left, right, middle }
	return s
end

function SLICE:SetShown(shown)
	for _, texture in ipairs(self.pieces) do
		texture:SetShown(shown)
	end
end

function SLICE:SetDesaturated(flag)
	for _, texture in ipairs(self.pieces) do
		texture:SetDesaturated(flag)
	end
end

function SLICE:SetBlendMode(mode)
	for _, texture in ipairs(self.pieces) do
		texture:SetBlendMode(mode)
	end
end

function SLICE:SetAlpha(alpha)
	for _, texture in ipairs(self.pieces) do
		texture:SetAlpha(alpha)
	end
end

function Theme.Inset(frame)
	return Theme.Slice(frame, "inset", "BACKGROUND", 1)
end

-- Window body: stone face, bronze frame, medallion with the emblem, title plaque and the close button.
function Theme.Window(f, title, onClose)
	local face = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	face:SetTexture(SKIN .. "bg")
	face:SetPoint("TOPLEFT", 6, -6)
	face:SetPoint("BOTTOMRIGHT", -6, 6)
	Theme.Slice(f, "frame", "BORDER", 0)
	local decor = CreateFrame("Frame", nil, f)
	decor:SetAllPoints()
	decor:SetFrameLevel(f:GetFrameLevel() + 20)
	if title then
		local medallion = decor:CreateTexture(nil, "ARTWORK")
		medallion:SetTexture(SKIN .. "medallion")
		medallion:SetSize(84, 84)
		medallion:SetPoint("TOPLEFT", -10, 10)
		local emblem = decor:CreateTexture(nil, "OVERLAY")
		emblem:SetTexture(SKIN .. "emblem")
		emblem:SetSize(58, 58)
		emblem:SetPoint("CENTER", medallion)
		local plaque = Theme.Plaque(decor, 200)
		plaque:SetPoint("TOP", 0, 12)
		plaque.text = Theme.Text(plaque, "title", 24, C.accent, "CENTER")
		plaque.text:SetPoint("CENTER", 0, 1)
		plaque.text:SetText(title)
		f.plaque = plaque
	end
	local close = CreateFrame("Button", nil, decor)
	close:SetSize(26, 26)
	close:SetPoint("TOPRIGHT", 0, 0)
	close:SetNormalTexture(SKIN .. "close")
	close:SetHighlightTexture(SKIN .. "close", "ADD")
	close:SetScript("OnClick", onClose)
	f.close = close
	f.decor = decor
	return f
end

function Theme.Plaque(parent, width)
	local plaque = CreateFrame("Frame", nil, parent)
	plaque:SetSize(width, 40)
	local cap = 28
	local left = plaque:CreateTexture(nil, "ARTWORK")
	left:SetTexture(SKIN .. "plaque")
	left:SetTexCoord(0, 88 / 512, 0, 1)
	left:SetPoint("TOPLEFT")
	left:SetSize(cap, 40)
	local right = plaque:CreateTexture(nil, "ARTWORK")
	right:SetTexture(SKIN .. "plaque")
	right:SetTexCoord(1 - 88 / 512, 1, 0, 1)
	right:SetPoint("TOPRIGHT")
	right:SetSize(cap, 40)
	local middle = plaque:CreateTexture(nil, "ARTWORK")
	middle:SetTexture(SKIN .. "plaque")
	middle:SetTexCoord(88 / 512, 1 - 88 / 512, 0, 1)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	return plaque
end

-- Lacquered buttons: "primary" red with gold letters, "dark" for everything secondary.
-- secure = true makes a SecureActionButtonTemplate for spells.
local STYLES = {
	primary = { slice = "button", font = "title", size = 16, color = C.accent },
	dark = { slice = "dark", font = "bold", size = 12, color = C.text },
}

function Theme.Button(parent, label, style, width, height, secure)
	local spec = STYLES[style] or STYLES.primary
	local button = CreateFrame("Button", nil, parent, secure and "SecureActionButtonTemplate" or nil)
	button:SetSize(width or 120, height or 28)
	if secure then
		button:RegisterForClicks("AnyUp", "AnyDown")
	end
	button.face = Theme.Slice(button, spec.slice, "BACKGROUND")
	button.hover = Theme.Slice(button, spec.slice, "HIGHLIGHT")
	button.hover:SetBlendMode("ADD")
	button.hover:SetAlpha(0.3)
	button.label = Theme.Text(button, spec.font, spec.size, spec.color, "CENTER")
	button.label:SetPoint("LEFT", 8, 1)
	button.label:SetPoint("RIGHT", -8, 1)
	button.label:SetText(label or "")
	button:SetScript("OnMouseDown", function(self)
		if self:IsEnabled() then
			self.label:SetPoint("LEFT", 9, 0)
			self.label:SetPoint("RIGHT", -7, 0)
		end
	end)
	button:SetScript("OnMouseUp", function(self)
		self.label:SetPoint("LEFT", 8, 1)
		self.label:SetPoint("RIGHT", -8, 1)
	end)
	button.style = spec
	return button
end

-- A small button holding only a cross.
function Theme.CrossButton(parent, size)
	local button = Theme.Button(parent, "", "dark", size, size)
	local cross = button:CreateTexture(nil, "ARTWORK")
	cross:SetTexture(MEDIA .. "close")
	cross:SetSize(size * 0.5, size * 0.5)
	cross:SetPoint("CENTER")
	cross:SetVertexColor(unpack(C.dim))
	return button
end

function Theme.SetEnabled(button, enabled)
	button:SetEnabled(enabled)
	button.face:SetDesaturated(not enabled)
	button.label:SetAlpha(enabled and 1 or 0.45)
end

-- Tab: dark plate, gold-brown when active, label and an optional counter.
function Theme.Tab(parent)
	local tab = CreateFrame("Button", nil, parent)
	tab:SetHeight(28)
	tab.off = Theme.Slice(tab, "dark", "BACKGROUND")
	tab.on = Theme.Slice(tab, "tabOn", "BACKGROUND", 1)
	tab.hover = Theme.Slice(tab, "dark", "HIGHLIGHT")
	tab.hover:SetBlendMode("ADD")
	tab.hover:SetAlpha(0.25)
	tab.label = Theme.Text(tab, "bold", 13, C.dim)
	tab.label:SetPoint("LEFT", 14, 1)
	tab.count = Theme.Text(tab, "bold", 13, C.trimDim)
	tab.count:SetPoint("LEFT", tab.label, "RIGHT", 5, 0)
	function tab:SetActive(active)
		self.on:SetShown(active)
		self.label:SetTextColor(unpack(active and C.text or C.dim))
		self.count:SetTextColor(unpack(active and C.accent or C.trimDim))
	end
	function tab:Fit()
		local count = self.count:GetText() or ""
		self:SetWidth(math.floor(self.label:GetStringWidth() + (count ~= "" and self.count:GetStringWidth() + 5 or 0) + 28 + 0.5))
	end
	return tab
end

-- Two or more segments, one selected; onSelect(index) after a click.
function Theme.Segments(parent, labels, onSelect)
	local frame = CreateFrame("Frame", nil, parent)
	frame.buttons = {}
	local x = 0
	for index, label in ipairs(labels) do
		local button = CreateFrame("Button", nil, frame)
		button.off = Theme.Slice(button, "dark", "BACKGROUND")
		button.on = Theme.Slice(button, "tabOn", "BACKGROUND", 1)
		button.label = Theme.Text(button, "bold", 12, C.dim, "CENTER")
		button.label:SetPoint("CENTER", 0, 1)
		button.label:SetText(label)
		local width = math.max(44, math.floor(button.label:GetStringWidth() + 24 + 0.5))
		button:SetSize(width, 24)
		button:SetPoint("LEFT", x, 0)
		x = x + width + 2
		button:SetScript("OnClick", function()
			frame:Select(index)
			if onSelect then
				onSelect(index)
			end
		end)
		frame.buttons[index] = button
	end
	frame:SetSize(x - 2, 24)
	function frame:Select(selected)
		for index, button in ipairs(self.buttons) do
			button.on:SetShown(index == selected)
			button.label:SetTextColor(unpack(index == selected and C.text or C.dim))
		end
		self.selected = selected
	end
	frame:Select(1)
	return frame
end

-- Board row plate; SetSelected adds the gold edge and its glow.
function Theme.Row(frame)
	frame.plate = Theme.Slice(frame, "row", "BACKGROUND", 0)
	frame.edge = Theme.Slice(frame, "rowSel", "BACKGROUND", 1)
	frame.glow = Theme.Slice(frame, "glow", "BACKGROUND", -1, 8)
	function frame:SetSelected(selected)
		self.edge:SetShown(selected)
		self.glow:SetShown(selected)
	end
	frame:SetSelected(false)
	return frame
end

-- Spell icon in a bronze frame.
function Theme.Icon(parent, size)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(size, size)
	holder.icon = holder:CreateTexture(nil, "ARTWORK")
	holder.icon:SetPoint("TOPLEFT", size * 0.1, -size * 0.1)
	holder.icon:SetPoint("BOTTOMRIGHT", -size * 0.1, size * 0.1)
	holder.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	holder.frame = holder:CreateTexture(nil, "OVERLAY")
	holder.frame:SetTexture(SKIN .. "iconframe")
	holder.frame:SetAllPoints()
	return holder
end

local LAMPS = { green = "lamp-green", amber = "lamp-amber", grey = "lamp-grey" }

function Theme.Lamp(parent, size)
	local lamp = parent:CreateTexture(nil, "ARTWORK")
	lamp:SetSize(size or 14, size or 14)
	function lamp:Set(kind)
		self:SetTexture(SKIN .. LAMPS[kind])
	end
	lamp:Set("grey")
	return lamp
end

-- Green pill with a short word ("near", "on duty").
function Theme.Badge(parent, label)
	local badge = CreateFrame("Frame", nil, parent)
	badge:SetHeight(15)
	local parts = {}
	for index, spec in ipairs({ { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }) do
		local texture = badge:CreateTexture(nil, "ARTWORK")
		texture:SetTexture(SKIN .. "badge")
		texture:SetTexCoord(spec[1], spec[2], 0, 1)
		parts[index] = texture
	end
	parts[1]:SetPoint("TOPLEFT")
	parts[1]:SetSize(8, 15)
	parts[3]:SetPoint("TOPRIGHT")
	parts[3]:SetSize(8, 15)
	parts[2]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT")
	parts[2]:SetPoint("BOTTOMRIGHT", parts[3], "BOTTOMLEFT")
	badge.text = Theme.Text(badge, "bold", 9.5, C.badgeText, "CENTER", true)
	badge.text:SetPoint("CENTER", 0, 0)
	badge.text:SetText(label)
	badge:SetWidth(math.floor(badge.text:GetStringWidth() + 12 + 0.5))
	return badge
end

-- Gold rod with a gem in the middle.
function Theme.Divider(parent, width)
	local divider = CreateFrame("Frame", nil, parent)
	divider:SetSize(width, 16)
	local gem = 14
	local left = divider:CreateTexture(nil, "ARTWORK")
	left:SetTexture(SKIN .. "divider")
	left:SetTexCoord(0, 0.486, 0, 1)
	left:SetPoint("LEFT")
	left:SetSize((width - gem) / 2, 16)
	local middle = divider:CreateTexture(nil, "ARTWORK")
	middle:SetTexture(SKIN .. "divider")
	middle:SetTexCoord(0.486, 0.514, 0, 1)
	middle:SetPoint("LEFT", left, "RIGHT")
	middle:SetSize(gem, 16)
	local right = divider:CreateTexture(nil, "ARTWORK")
	right:SetTexture(SKIN .. "divider")
	right:SetTexCoord(0.514, 1, 0, 1)
	right:SetPoint("LEFT", middle, "RIGHT")
	right:SetSize((width - gem) / 2, 16)
	return divider
end

-- Section title with a thin line to the right edge of the parent.
function Theme.Section(parent, text, right)
	local label = Theme.Text(parent, "bold", 10, C.head)
	label:SetText(text)
	local line = Theme.Line(parent)
	line:SetPoint("LEFT", label, "RIGHT", 8, 0)
	line:SetPoint("RIGHT", parent, "RIGHT", -(right or 26), 0)
	label.line = line
	return label
end

function Theme.Disc(parent, size, color, layer)
	local disc = parent:CreateTexture(nil, layer or "ARTWORK")
	disc:SetTexture(MEDIA .. "disc")
	disc:SetSize(size, size)
	disc:SetVertexColor(unpack(color))
	return disc
end

-- Five stars; Set(count, color) fills the first count, the rest stay dim.
function Theme.Stars(parent, size, gap, clickable)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(5 * size + 4 * gap, size)
	frame.stars = {}
	for index = 1, 5 do
		local star = CreateFrame("Button", nil, frame)
		star:SetSize(size, size)
		star:SetPoint("LEFT", (index - 1) * (size + gap), 0)
		star.icon = star:CreateTexture(nil, "ARTWORK")
		star.icon:SetAllPoints()
		star.icon:SetTexture(MEDIA .. "star")
		star:EnableMouse(clickable and true or false)
		star.index = index
		frame.stars[index] = star
	end
	function frame:Set(count, color, dim)
		for index, star in ipairs(self.stars) do
			star.icon:SetVertexColor(unpack(index <= count and color or dim or C.inkLine))
		end
	end
	return frame
end

function Theme.Star(parent, size)
	local star = parent:CreateTexture(nil, "ARTWORK")
	star:SetTexture(MEDIA .. "star")
	star:SetSize(size, size)
	star:SetVertexColor(unpack(C.accent))
	return star
end

-- On/off switch: a track and a gold knob.
function Theme.Switch(parent)
	local switch = CreateFrame("Button", nil, parent)
	switch:SetSize(44, 22)
	switch.track = switch:CreateTexture(nil, "BACKGROUND")
	switch.track:SetAllPoints()
	switch.knob = switch:CreateTexture(nil, "ARTWORK")
	switch.knob:SetTexture(SKIN .. "knob")
	switch.knob:SetSize(20, 20)
	function switch:SetOn(on)
		self.track:SetTexture(SKIN .. (on and "track-on" or "track-off"))
		self.knob:ClearAllPoints()
		self.knob:SetPoint(on and "RIGHT" or "LEFT", on and -1 or 1, 0)
		self.on = on
	end
	switch:SetOn(false)
	return switch
end

function Theme.Check(parent)
	local check = CreateFrame("Button", nil, parent)
	check:SetSize(20, 20)
	check.box = check:CreateTexture(nil, "ARTWORK")
	check.box:SetTexture(SKIN .. "check")
	check.box:SetAllPoints()
	check.tick = check:CreateTexture(nil, "OVERLAY")
	check.tick:SetTexture(SKIN .. "tick")
	check.tick:SetPoint("CENTER", 0, 1)
	check.tick:SetSize(20, 20)
	function check:SetOn(on)
		self.tick:SetShown(on)
		self.on = on
	end
	return check
end

-- Ticket paper for a fixed 440 width: top and bottom keep the notches, the middle band stretches.
function Theme.Paper(frame)
	local width = 880 / 1024
	local cap = 32
	local top = frame:CreateTexture(nil, "BACKGROUND")
	top:SetTexture(SKIN .. "parchment")
	top:SetTexCoord(0, width, 0, cap / 256)
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(cap)
	local bottom = frame:CreateTexture(nil, "BACKGROUND")
	bottom:SetTexture(SKIN .. "parchment")
	bottom:SetTexCoord(0, width, 1 - cap / 256, 1)
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(cap)
	local middle = frame:CreateTexture(nil, "BACKGROUND")
	middle:SetTexture(SKIN .. "parchment")
	middle:SetTexCoord(0, width, cap / 256, 1 - cap / 256)
	middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
	middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
end

-- Class colours from the client. class is a class file ("PRIEST") or "M" / "W" for the two providers.
local PROVIDER_CLASS = { M = "MAGE", W = "WARLOCK" }

local function classColor(class)
	return RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[PROVIDER_CLASS[class] or class]
end

function Theme.ClassColor(class)
	local color = classColor(class)
	return color and { color.r, color.g, color.b, 1 } or C.text
end

-- Darkened for the ticket paper; an unknown class keeps the fallback ink.
function Theme.PaperClassColor(class, fallback)
	local color = classColor(class)
	return color and { color.r * 0.45, color.g * 0.45, color.b * 0.45, 1 } or fallback
end

function Theme.Colored(text, color)
	return string.format("|cff%02x%02x%02x%s|r", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5), text)
end

-- Scrolled area of a fixed size with a thin bar on the right edge of the window.
-- Content may hold secure buttons, so in combat the offset and the content height stay as they are.
local WHEEL_STEP = 40

function Theme.Scroll(parent, x, y, width, height, barX)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetPoint("TOPLEFT", x, y)
	scroll:SetSize(width, height)
	local body = CreateFrame("Frame", nil, scroll)
	body:SetSize(width, height)
	scroll:SetScrollChild(body)
	scroll.body, scroll.view, scroll.content, scroll.offset = body, height, height, 0

	local track = CreateFrame("Frame", nil, parent)
	track:SetWidth(8)
	track:SetPoint("TOPLEFT", barX, y - 2)
	track:SetHeight(height - 4)
	Theme.Slice(track, "scrollTrack", "ARTWORK")
	local thumb = CreateFrame("Button", nil, track)
	thumb:SetWidth(6)
	Theme.Slice(thumb, "scrollThumb", "OVERLAY")
	track:Hide()
	scroll.track, scroll.thumb = track, thumb

	function scroll:Range()
		return math.max(0, self.content - self.view)
	end

	function scroll:SetOffset(offset)
		if InCombatLockdown() then
			return
		end
		local range = self:Range()
		self.offset = math.max(0, math.min(range, math.floor(offset + 0.5)))
		self:SetVerticalScroll(self.offset)
		local room = self.view - 4 - 2 - self.thumb:GetHeight()
		self.thumb:ClearAllPoints()
		self.thumb:SetPoint("TOP", self.track, "TOP", 0, -1 - (range > 0 and room * self.offset / range or 0))
	end

	function scroll:SetView(view)
		if InCombatLockdown() then
			return
		end
		self.view = view
		self:SetHeight(view)
		self.track:SetHeight(view - 4)
		self:SetContent(self.content)
	end

	function scroll:SetContent(content)
		if InCombatLockdown() then
			return
		end
		self.content = math.max(math.floor(content + 0.5), self.view)
		self.body:SetHeight(self.content)
		local range = self:Range()
		self.track:SetShown(range > 0)
		self.thumb:SetHeight(math.max(24, math.floor((self.view - 6) * self.view / self.content + 0.5)))
		self:SetOffset(self.offset)
	end

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		self:SetOffset(self.offset - delta * WHEEL_STEP)
	end)
	thumb:SetScript("OnMouseDown", function(self)
		local _, cursor = GetCursorPosition()
		self.drag = { cursor = cursor / self:GetEffectiveScale(), offset = scroll.offset }
	end)
	thumb:SetScript("OnMouseUp", function(self)
		self.drag = nil
	end)
	thumb:SetScript("OnUpdate", function(self)
		if not self.drag then
			return
		end
		local room = scroll.view - 6 - self:GetHeight()
		if room > 0 then
			local _, cursor = GetCursorPosition()
			local moved = self.drag.cursor - cursor / self:GetEffectiveScale()
			scroll:SetOffset(self.drag.offset + moved * scroll:Range() / room)
		end
	end)
	return scroll
end
