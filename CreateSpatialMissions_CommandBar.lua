--!strict
-- Jalankan sekali di Roblox Studio > View > Command Bar saat mode Edit.
-- Bagian yang dibuat adalah graybox. Setelah itu pindahkan/ubah ukurannya agar pas dengan map.

-- Offset ini memisahkan graybox baru dari tiga marker Misi 1 yang biasanya dibuat di origin.
local origin = Vector3.new(0, 0, 100)

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("Folder") then
			error(parent:GetFullName() .. "." .. name .. " harus berupa Folder.")
		end
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureContainer(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("Folder") and not existing:IsA("Model") then
			error(existing:GetFullName() .. " harus berupa Folder atau Model.")
		end
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensurePart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number?,
	canCollide: boolean?
): BasePart
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("BasePart") then
			error(existing:GetFullName() .. " harus berupa BasePart.")
		end
		return existing
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = canCollide ~= false
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function ensureMarker(parent: Instance, name: string, position: Vector3, lookDirection: Vector3): BasePart
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("BasePart") then
			error(existing:GetFullName() .. " harus berupa BasePart.")
		end
		return existing
	end
	local marker = ensurePart(
		parent,
		name,
		Vector3.new(3, 0.2, 3),
		position,
		Color3.fromRGB(38, 219, 231),
		Enum.Material.Neon,
		0.45,
		false
	)
	marker.CFrame = CFrame.lookAt(position, position + lookDirection)
	return marker
end

local function ensureVehicle(parent: Instance, name: string, chassisCFrame: CFrame, color: Color3): Model
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("Model") then
			error(existing:GetFullName() .. " harus berupa Model.")
		end
		return existing
	end
	local model = Instance.new("Model")
	model.Name = name
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(7, 2, 11)
	chassis.CFrame = chassisCFrame
	chassis.Color = color
	chassis.Material = Enum.Material.Metal
	chassis.Anchored = true
	chassis.Parent = model
	local roof = Instance.new("Part")
	roof.Name = "Cabin"
	roof.Size = Vector3.new(5, 1.5, 5)
	roof.CFrame = chassisCFrame * CFrame.new(0, 1.7, -0.4)
	roof.Color = Color3.fromRGB(120, 174, 193)
	roof.Material = Enum.Material.Glass
	roof.Transparency = 0.25
	roof.Anchored = true
	roof.CanCollide = false
	roof.Parent = model
	model.PrimaryPart = chassis
	model.Parent = parent
	return model
end

local function ensureBlueprintCard(parent: Instance, name: string, position: Vector3, text: string, color: Color3): BasePart
	local existing = parent:FindFirstChild(name)
	local card: BasePart
	if existing then
		if not existing:IsA("BasePart") then
			error(existing:GetFullName() .. " harus berupa BasePart.")
		end
		card = existing
	else
		local newCard = Instance.new("Part")
		newCard.Name = name
		newCard.Size = Vector3.new(7, 0.12, 3.4)
		newCard.Position = position
		newCard.Color = color
		newCard.Material = Enum.Material.SmoothPlastic
		newCard.Anchored = true
		newCard.CanCollide = false
		newCard.Parent = parent
		card = newCard
	end
	if not card:FindFirstChild("BlueprintSurface") then
		local surface = Instance.new("SurfaceGui")
		surface.Name = "BlueprintSurface"
		surface.Face = Enum.NormalId.Top
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 45
		surface.AlwaysOnTop = true
		surface.Parent = card
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = color
		label.Text = text
		label.TextColor3 = Color3.fromRGB(28, 46, 65)
		label.TextScaled = true
		label.TextWrapped = true
		label.Font = Enum.Font.GothamBold
		label.Parent = surface
	end
	return card
end

local function ensureWhiteboardContent(part: BasePart)
	if part:FindFirstChild("AnalysisSurface") then
		return
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "AnalysisSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 35
	surface.AlwaysOnTop = true
	surface.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(238, 243, 235)
	label.Text = "POS SATPAM | PAPAN ANALISIS\n\nBUKTI → MASALAH → KEBUTUHAN PENGGUNA"
	label.TextColor3 = Color3.fromRGB(35, 58, 73)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = surface
end

local warRoom = ensureFolder(workspace, "WarRoom")
local whiteboard = ensurePart(warRoom, "Whiteboard", Vector3.new(12, 7, 0.4), origin + Vector3.new(-42, 4, 0), Color3.fromRGB(238, 243, 235), Enum.Material.SmoothPlastic)
ensureWhiteboardContent(whiteboard)

local blueprintStations = ensureFolder(workspace, "BlueprintStations")
local stationA = ensurePart(blueprintStations, "Station_A", Vector3.new(9, 2, 5), origin + Vector3.new(-20, 1, 0), Color3.fromRGB(176, 111, 62), Enum.Material.WoodPlanks)
local stationB = ensurePart(blueprintStations, "Station_B", Vector3.new(9, 2, 5), origin + Vector3.new(0, 1, 0), Color3.fromRGB(62, 105, 145), Enum.Material.Metal)
ensureBlueprintCard(blueprintStations, "BlueprintCard_A", stationA.Position + Vector3.new(0, stationA.Size.Y / 2 + 0.12, 0), "BLUEPRINT A | MARKA & SPEED TABLE\nPita kejut antiselip\nSpeed table landai + drainase", Color3.fromRGB(220, 238, 250))
ensureBlueprintCard(blueprintStations, "BlueprintCard_B", stationB.Position + Vector3.new(0, stationB.Size.Y / 2 + 0.12, 0), "BLUEPRINT B | SMART TRAFFIC\nSensor penyeberangan\nLampu + hitung mundur + audio", Color3.fromRGB(223, 242, 231))

local supply = ensureFolder(workspace, "MaterialSupply")
ensurePart(supply, "Crate", Vector3.new(4, 4, 4), origin + Vector3.new(20, 2, 0), Color3.fromRGB(156, 99, 55), Enum.Material.WoodPlanks)

local interactionStation = ensureContainer(workspace, "InteractionStation")
local prototypeSlot = ensurePart(interactionStation, "PrototypeSlot", Vector3.new(6, 1, 6), origin + Vector3.new(32, 0.5, 0), Color3.fromRGB(54, 126, 102), Enum.Material.Metal)
if not prototypeSlot:FindFirstChild("AssemblySound") then
	local sound = Instance.new("Sound")
	sound.Name = "AssemblySound"
	sound.Volume = 1
	sound.RollOffMaxDistance = 60
	sound.Parent = prototypeSlot
end

ensurePart(workspace, "Crosswalk_Entry", Vector3.new(3, 0.2, 3), origin + Vector3.new(0, 0.1, -10), Color3.fromRGB(246, 213, 70), Enum.Material.Neon, 0.35, false)
ensurePart(workspace, "Crosswalk_Destination", Vector3.new(4, 0.2, 4), origin + Vector3.new(0, 0.1, 10), Color3.fromRGB(81, 223, 129), Enum.Material.Neon, 0.35, false)

local simulation = ensureFolder(workspace, "CrossSafeSimulation")
ensurePart(simulation, "SignalLamp", Vector3.new(1.2, 5, 1.2), origin + Vector3.new(0, 3, -3), Color3.fromRGB(70, 75, 78), Enum.Material.Metal)
local lamp = simulation:FindFirstChild("SignalLamp")
if lamp and lamp:IsA("BasePart") and not lamp:FindFirstChildOfClass("PointLight") then
	local pointLight = Instance.new("PointLight")
	pointLight.Name = "CrosswalkSignalLight"
	pointLight.Color = Color3.fromRGB(64, 255, 121)
	pointLight.Brightness = 2
	pointLight.Range = 18
	pointLight.Enabled = false
	pointLight.Parent = lamp
end
ensurePart(simulation, "StopLine", Vector3.new(1, 0.15, 36), origin + Vector3.new(0, 0.1, 0), Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic, 0, false)

local forward = Vector3.new(1, 0, 0)
local reverse = Vector3.new(-1, 0, 0)
local vehicle1Start = origin + Vector3.new(-28, 1, -7)
local vehicle2Start = origin + Vector3.new(28, 1, 7)
ensureVehicle(simulation, "Vehicle_1", CFrame.lookAt(vehicle1Start, vehicle1Start + forward), Color3.fromRGB(193, 77, 59))
ensureVehicle(simulation, "Vehicle_2", CFrame.lookAt(vehicle2Start, vehicle2Start + reverse), Color3.fromRGB(58, 107, 170))
-- Pivot model mobil berada setinggi Y=1; samakan tinggi marker agar mobil tidak terbenam.
ensureMarker(simulation, "VehicleStop_1", origin + Vector3.new(-3, 1, -7), forward)
ensureMarker(simulation, "VehiclePass_1", origin + Vector3.new(24, 1, -7), forward)
ensureMarker(simulation, "VehicleStop_2", origin + Vector3.new(3, 1, 7), reverse)
ensureMarker(simulation, "VehiclePass_2", origin + Vector3.new(-24, 1, 7), reverse)

if not simulation:FindFirstChild("HornSound") then
	local sound = Instance.new("Sound")
	sound.Name = "HornSound"
	sound.Volume = 1.5
	sound.RollOffMaxDistance = 120
	sound.Parent = simulation
end

print("Spatial missions graybox dibuat di sekitar Z=100 agar terpisah dari marker Misi 1. Letakkan Pos Satpam, kedua stasiun, crate, PrototypeSlot, penanda zebra cross, mobil, dan marker kendaraan sesuai map. Isi SoundId untuk AssemblySound dan HornSound dari audio Creator Store.")

