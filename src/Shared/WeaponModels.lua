--!strict
--[[
	Constructed Part/Wedge/Cylinder assemblies for Pistol + Knife.
	No MeshIds — Studio-safe. First-person friendly scale.
	Skins recolor primary / accent / metal materials via ApplySkin.
]]

local WeaponModels = {}

export type SkinColors = {
	Primary: Color3, -- grip / body
	Accent: Color3, -- neon tip / blade glow / sights
	Metal: Color3?, -- slide / barrel / guard
	MaterialPrimary: Enum.Material?,
	MaterialAccent: Enum.Material?,
	MaterialMetal: Enum.Material?,
}

local function part(
	name: string,
	className: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	handle: BasePart,
	parent: Instance,
	role: string?
): BasePart
	local p: BasePart
	if className == "WedgePart" then
		p = Instance.new("WedgePart")
	elseif className == "Cylinder" then
		local c = Instance.new("Part")
		c.Shape = Enum.PartType.Cylinder
		p = c
	else
		p = Instance.new("Part")
	end
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = handle.CFrame * offset
	if role then
		p:SetAttribute("SkinRole", role)
	end
	p.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
	return p
end

--[[
	Detailed pistol: grip Handle + frame, slide, barrel, sights, trigger guard, mag.
	Muzzle neon tip at front for flash FX.
	Coordinate: Handle local +Z toward barrel tip (Tool convention uses -Z forward in world when held;
	we build along -Z from grip center for muzzle offset matching Config.MuzzleOffset).
]]
function WeaponModels.BuildPistol(tool: Tool, colors: SkinColors): BasePart
	local primary = colors.Primary
	local accent = colors.Accent
	local metal = colors.Metal or Color3.fromRGB(55, 58, 68)
	local matP = colors.MaterialPrimary or Enum.Material.SmoothPlastic
	local matA = colors.MaterialAccent or Enum.Material.Neon
	local matM = colors.MaterialMetal or Enum.Material.Metal

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.28, 0.72, 0.38)
	handle.Color = primary
	handle.Material = matP
	handle.CanCollide = false
	handle.Massless = true
	handle.CastShadow = false
	handle:SetAttribute("SkinRole", "Primary")
	handle.Parent = tool

	-- Lower receiver / frame (sits above grip)
	part(
		"Frame",
		"Part",
		Vector3.new(0.32, 0.28, 1.05),
		CFrame.new(0, 0.42, -0.28),
		metal,
		matM,
		handle,
		tool,
		"Metal"
	)

	-- Slide (top)
	part(
		"Slide",
		"Part",
		Vector3.new(0.30, 0.18, 0.95),
		CFrame.new(0, 0.62, -0.32),
		metal:Lerp(Color3.new(0, 0, 0), 0.15),
		matM,
		handle,
		tool,
		"Metal"
	)

	-- Slide serrations (visual bars)
	for i = 0, 3 do
		part(
			"Serration" .. i,
			"Part",
			Vector3.new(0.32, 0.04, 0.04),
			CFrame.new(0, 0.72, -0.02 - i * 0.08),
			primary:Lerp(Color3.new(0, 0, 0), 0.35),
			matP,
			handle,
			tool,
			"Primary"
		)
	end

	-- Barrel (cylinder — rotated so length along Z)
	local barrel = part(
		"Barrel",
		"Cylinder",
		Vector3.new(0.55, 0.14, 0.14),
		CFrame.new(0, 0.52, -0.95) * CFrame.Angles(0, math.rad(90), 0),
		metal,
		matM,
		handle,
		tool,
		"Metal"
	)
	barrel.Size = Vector3.new(0.55, 0.14, 0.14)

	-- Muzzle tip (neon) — flash/light parent
	local muzzle = part(
		"Muzzle",
		"Part",
		Vector3.new(0.16, 0.16, 0.18),
		CFrame.new(0, 0.52, -1.22),
		accent,
		matA,
		handle,
		tool,
		"Accent"
	)

	local light = Instance.new("PointLight")
	light.Name = "MuzzleLight"
	light.Brightness = 0
	light.Range = 10
	light.Color = accent
	light.Enabled = false
	light.Parent = muzzle

	-- Front sight
	part(
		"FrontSight",
		"Part",
		Vector3.new(0.06, 0.12, 0.06),
		CFrame.new(0, 0.78, -1.05),
		accent,
		matA,
		handle,
		tool,
		"Accent"
	)

	-- Rear sight notch
	part(
		"RearSightL",
		"Part",
		Vector3.new(0.05, 0.1, 0.08),
		CFrame.new(-0.08, 0.76, 0.05),
		metal,
		matM,
		handle,
		tool,
		"Metal"
	)
	part(
		"RearSightR",
		"Part",
		Vector3.new(0.05, 0.1, 0.08),
		CFrame.new(0.08, 0.76, 0.05),
		metal,
		matM,
		handle,
		tool,
		"Metal"
	)

	-- Trigger guard
	part(
		"TriggerGuard",
		"Part",
		Vector3.new(0.22, 0.22, 0.08),
		CFrame.new(0, 0.22, -0.15),
		metal,
		matM,
		handle,
		tool,
		"Metal"
	)

	-- Mag well / grip texture strip
	part(
		"Mag",
		"Part",
		Vector3.new(0.22, 0.45, 0.28),
		CFrame.new(0, -0.05, 0.02),
		primary:Lerp(Color3.new(0, 0, 0), 0.2),
		matP,
		handle,
		tool,
		"Primary"
	)

	-- Grip side panels
	part(
		"GripL",
		"Part",
		Vector3.new(0.06, 0.55, 0.32),
		CFrame.new(-0.14, 0.0, 0),
		primary,
		matP,
		handle,
		tool,
		"Primary"
	)
	part(
		"GripR",
		"Part",
		Vector3.new(0.06, 0.55, 0.32),
		CFrame.new(0.14, 0.0, 0),
		primary,
		matP,
		handle,
		tool,
		"Primary"
	)

	return handle
end

--[[
	Detailed knife: grip Handle + crossguard + blade wedge + pommel + spine accent.
]]
function WeaponModels.BuildKnife(tool: Tool, colors: SkinColors): BasePart
	local primary = colors.Primary
	local accent = colors.Accent
	local metal = colors.Metal or Color3.fromRGB(200, 205, 215)
	local matP = colors.MaterialPrimary or Enum.Material.SmoothPlastic
	local matA = colors.MaterialAccent or Enum.Material.Neon
	local matM = colors.MaterialMetal or Enum.Material.Metal

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.22, 0.22, 0.85)
	handle.Color = primary
	handle.Material = matP
	handle.CanCollide = false
	handle.Massless = true
	handle.CastShadow = false
	handle:SetAttribute("SkinRole", "Primary")
	handle.Parent = tool

	-- Wrapped grip rings
	for i = 0, 3 do
		part(
			"GripRing" .. i,
			"Part",
			Vector3.new(0.26, 0.26, 0.06),
			CFrame.new(0, 0, 0.25 - i * 0.18),
			primary:Lerp(Color3.new(0, 0, 0), 0.25),
			matP,
			handle,
			tool,
			"Primary"
		)
	end

	-- Pommel
	part(
		"Pommel",
		"Part",
		Vector3.new(0.28, 0.28, 0.14),
		CFrame.new(0, 0, 0.48),
		metal,
		matM,
		handle,
		tool,
		"Metal"
	)

	-- Crossguard
	part(
		"Guard",
		"Part",
		Vector3.new(0.55, 0.12, 0.12),
		CFrame.new(0, 0, -0.42),
		metal,
		matM,
		handle,
		tool,
		"Metal"
	)

	-- Blade body
	part(
		"Blade",
		"Part",
		Vector3.new(0.08, 0.22, 0.95),
		CFrame.new(0, 0.02, -0.95),
		metal,
		matM,
		handle,
		tool,
		"Metal"
	)

	-- Blade tip (wedge)
	part(
		"BladeTip",
		"WedgePart",
		Vector3.new(0.08, 0.22, 0.35),
		CFrame.new(0, 0.02, -1.55) * CFrame.Angles(0, math.rad(180), 0),
		metal,
		matM,
		handle,
		tool,
		"Metal"
	)

	-- Neon edge accent (cutting edge glow)
	part(
		"Edge",
		"Part",
		Vector3.new(0.04, 0.04, 1.15),
		CFrame.new(0, -0.1, -1.05),
		accent,
		matA,
		handle,
		tool,
		"Accent"
	)

	-- Spine ridge
	part(
		"Spine",
		"Part",
		Vector3.new(0.05, 0.05, 0.9),
		CFrame.new(0, 0.14, -0.95),
		accent:Lerp(metal, 0.4),
		matA,
		handle,
		tool,
		"Accent"
	)

	return handle
end

function WeaponModels.SkinFromItem(item: any?, fallbackPrimary: Color3, fallbackAccent: Color3): SkinColors
	if typeof(item) ~= "table" then
		return {
			Primary = fallbackPrimary,
			Accent = fallbackAccent,
			Metal = Color3.fromRGB(60, 64, 74),
			MaterialPrimary = Enum.Material.SmoothPlastic,
			MaterialAccent = Enum.Material.Neon,
			MaterialMetal = Enum.Material.Metal,
		}
	end
	local primary = item.HandleColor or fallbackPrimary
	local accent = item.TipColor or item.TrailColor or item.HitColor or fallbackAccent
	local metal = item.MetalColor
	if typeof(metal) ~= "Color3" then
		-- Derive metal tone from primary for gold/arctic/etc.
		if item.Id == "pistol_gold" or item.Id == "knife_ember" then
			metal = Color3.fromRGB(210, 170, 50)
		elseif item.Id == "pistol_arctic" or item.Id == "knife_chrome" then
			metal = Color3.fromRGB(200, 210, 225)
		elseif item.Id == "pistol_void" then
			metal = Color3.fromRGB(40, 30, 60)
		elseif item.Id == "pistol_crimson" or item.Id == "knife_blood" then
			metal = Color3.fromRGB(70, 30, 35)
		elseif item.Id == "pistol_neon" then
			metal = Color3.fromRGB(30, 50, 35)
		else
			metal = Color3.fromRGB(60, 64, 74)
		end
	end
	local matMetal = Enum.Material.Metal
	local matPrimary = Enum.Material.SmoothPlastic
	local matAccent = Enum.Material.Neon
	if item.Id == "pistol_gold" then
		matMetal = Enum.Material.Neon
		matPrimary = Enum.Material.Metal
	elseif item.Id == "knife_chrome" or item.Id == "pistol_arctic" then
		matMetal = Enum.Material.Glass
	end
	return {
		Primary = primary,
		Accent = accent,
		Metal = metal,
		MaterialPrimary = matPrimary,
		MaterialAccent = matAccent,
		MaterialMetal = matMetal,
	}
end

function WeaponModels.ApplySkin(tool: Tool, colors: SkinColors)
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			local role = child:GetAttribute("SkinRole")
			if role == "Primary" or child.Name == "Handle" then
				child.Color = colors.Primary
				if colors.MaterialPrimary then
					child.Material = colors.MaterialPrimary
				end
			elseif role == "Accent" or child.Name == "Muzzle" or child.Name == "Edge" then
				child.Color = colors.Accent
				if colors.MaterialAccent then
					child.Material = colors.MaterialAccent
				end
				local light = child:FindFirstChild("MuzzleLight")
				if light and light:IsA("PointLight") then
					light.Color = colors.Accent
				end
			elseif role == "Metal" then
				child.Color = colors.Metal or child.Color
				if colors.MaterialMetal then
					child.Material = colors.MaterialMetal
				end
			end
		end
	end
end

return WeaponModels
