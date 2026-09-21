--!strict
--[[
	Shared UI theme for hub, HUD, countdown, and end screens.
	Full-bleed hub layout tokens (sidebar, content padding, card grid).
]]

local Theme = {
	-- Solid backgrounds (hub root must be fully opaque — zero world bleed)
	Bg = Color3.fromRGB(8, 10, 16),
	BgDeep = Color3.fromRGB(5, 6, 10),
	Overlay = Color3.fromRGB(4, 6, 12),
	Sidebar = Color3.fromRGB(10, 12, 20),
	SidebarAlt = Color3.fromRGB(14, 16, 26),
	Panel = Color3.fromRGB(14, 18, 28),
	PanelAlt = Color3.fromRGB(20, 26, 40),
	Card = Color3.fromRGB(22, 28, 42),
	CardHover = Color3.fromRGB(32, 40, 58),
	CardSelected = Color3.fromRGB(28, 40, 62),
	Stroke = Color3.fromRGB(48, 58, 82),
	StrokeBright = Color3.fromRGB(80, 110, 180),
	StrokeSoft = Color3.fromRGB(36, 44, 64),
	Shadow = Color3.fromRGB(0, 0, 0),
	Text = Color3.fromRGB(236, 240, 250),
	TextMuted = Color3.fromRGB(148, 158, 182),
	TextDim = Color3.fromRGB(100, 110, 138),
	Accent = Color3.fromRGB(70, 140, 230),
	AccentSoft = Color3.fromRGB(50, 100, 180),
	AccentGlow = Color3.fromRGB(90, 160, 255),
	Success = Color3.fromRGB(56, 175, 115),
	SuccessDark = Color3.fromRGB(36, 120, 80),
	SuccessHover = Color3.fromRGB(70, 200, 135),
	Warning = Color3.fromRGB(235, 185, 75),
	Danger = Color3.fromRGB(220, 70, 80),
	OITC = Color3.fromRGB(230, 125, 70),
	Credits = Color3.fromRGB(255, 210, 90),
	Owned = Color3.fromRGB(70, 180, 130),
	Equipped = Color3.fromRGB(90, 160, 255),
	-- Layout
	Radius = 12,
	RadiusSm = 8,
	RadiusXs = 6,
	NavHeight = 56,
	SidebarWidth = 248,
	ContentPad = 40,
	CardMinWidth = 200,
	CardHeight = 168,
	GridGap = 14,
	FontTitle = Enum.Font.GothamBold,
	FontBody = Enum.Font.Gotham,
	FontMono = Enum.Font.GothamMedium,
}

return Theme
