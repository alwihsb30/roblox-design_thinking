--!strict
-- Jalankan SATU KALI di Roblox Studio > View > Command Bar pada Baseplate BARU.
-- Membuat graybox CrossSafe yang tertata. Tidak membuat Rani_NPC atau script gameplay.

local REQUIRED_ROOTS = {
	"CrossSafeFreshMap",
	"InvestigationClues",
	"WarRoom",
	"BlueprintStations",
	"MaterialSupply",
	"InteractionStation",
	"CrossSafeSimulation",
}

for _, name in ipairs(REQUIRED_ROOTS) do
	if workspace:FindFirstChild(name) then
		error(string.format("Workspace.%s sudah ada. Jalankan generator ini hanya pada Baseplate baru.", name))
	end
end
if workspace:FindFirstChild("Crosswalk_Entry") or workspace:FindFirstChild("Crosswalk_Destination") then
	error("Marker crosswalk sudah ada. Jalankan generator ini hanya pada Baseplate baru.")
end

local function makeFolder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addSurfaceText(part: BasePart, guiName: string, face: Enum.NormalId, text: string, background: Color3)
	local surface = Instance.new("SurfaceGui")
	surface.Name = guiName
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 35
	surface.AlwaysOnTop = true
	surface.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background
	label.Text = text
	label.TextColor3 = Color3.fromRGB(26, 42, 56)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = surface
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = label
end

local function addBillboard(part: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldLabel"
	billboard.Size = UDim2.fromOffset(220, 54)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(24, 35, 48)
	label.BackgroundTransparency = 0.08
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function makeMarker(parent: Instance, name: string, position: Vector3, direction: Vector3): Part
	local marker = makePart(
		parent,
		name,
		Vector3.new(3, 0.2, 3),
		CFrame.lookAt(position, position + direction),
		Color3.fromRGB(38, 219, 231),
		Enum.Material.Neon,
		false
	)
	marker.Transparency = 1
	return marker
end

local function makeVehicle(parent: Instance, name: string, center: Vector3, direction: Vector3, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	local vehicleCFrame = CFrame.lookAt(center, center + direction)
	local chassis = makePart(model, "Chassis", Vector3.new(10, 2, 5), vehicleCFrame, color, Enum.Material.Metal, false)
	local cabin = makePart(model, "Cabin", Vector3.new(5, 1.5, 4), vehicleCFrame * CFrame.new(0, 1.7, 0), Color3.fromRGB(134, 190, 205), Enum.Material.Glass, false)
	cabin.Transparency = 0.2
	model.PrimaryPart = chassis
	model.Parent = parent
	return model
end

local map = makeFolder(workspace, "CrossSafeFreshMap")
local clues = makeFolder(workspace, "InvestigationClues")
local warRoom = makeFolder(workspace, "WarRoom")
local blueprints = makeFolder(workspace, "BlueprintStations")
local supply = makeFolder(workspace, "MaterialSupply")
local interaction = makeFolder(workspace, "InteractionStation")
local simulation = makeFolder(workspace, "CrossSafeSimulation")

-- Jalan utama berjalan dari barat ke timur; pemain menyeberang dari selatan ke utara.
makePart(map, "MainRoad", Vector3.new(180, 0.5, 40), CFrame.new(0, 0.25, 0), Color3.fromRGB(48, 51, 56), Enum.Material.Asphalt)
makePart(map, "Sidewalk_South", Vector3.new(180, 0.5, 8), CFrame.new(0, 0.25, -24), Color3.fromRGB(150, 151, 145), Enum.Material.Concrete)
makePart(map, "Sidewalk_North", Vector3.new(180, 0.5, 8), CFrame.new(0, 0.25, 24), Color3.fromRGB(150, 151, 145), Enum.Material.Concrete)

for index = -5, 5 do
	makePart(
		map,
		"CrosswalkStripe_" .. tostring(index + 6),
		Vector3.new(1.4, 0.08, 12),
		CFrame.new(index * 2.2, 0.54, 0),
		Color3.fromRGB(242, 242, 234),
		Enum.Material.SmoothPlastic,
		false
	)
end
-- Pos Satpam dengan pintu depan terbuka dan papan yang bisa diperiksa.
makePart(map, "GuardPost_Floor", Vector3.new(22, 0.5, 18), CFrame.new(-70, 0.25, 44), Color3.fromRGB(155, 151, 135), Enum.Material.Concrete)
makePart(map, "GuardPost_LeftWall", Vector3.new(0.5, 7, 18), CFrame.new(-81, 3.75, 44), Color3.fromRGB(190, 200, 196), Enum.Material.Concrete)
makePart(map, "GuardPost_RightWall", Vector3.new(0.5, 7, 18), CFrame.new(-59, 3.75, 44), Color3.fromRGB(190, 200, 196), Enum.Material.Concrete)
makePart(map, "GuardPost_BackWall", Vector3.new(22, 7, 0.5), CFrame.new(-70, 3.75, 53), Color3.fromRGB(190, 200, 196), Enum.Material.Concrete)
local guardSign = makePart(map, "GuardPost_Sign", Vector3.new(12, 2, 0.3), CFrame.new(-70, 7, 34.8), Color3.fromRGB(45, 86, 75), Enum.Material.SmoothPlastic, false)
addSurfaceText(guardSign, "GuardPostTitle", Enum.NormalId.Front, "POS SATPAM", Color3.fromRGB(207, 232, 212))
local whiteboard = makePart(warRoom, "Whiteboard", Vector3.new(12, 5.5, 0.25), CFrame.new(-70, 4.2, 52.5), Color3.fromRGB(239, 243, 232), Enum.Material.SmoothPlastic)
addSurfaceText(whiteboard, "AnalysisSurface", Enum.NormalId.Front, "PAPAN ANALISIS\nBUKTI → MASALAH → KEBUTUHAN PENGGUNA", Color3.fromRGB(239, 243, 232))

-- Tiga bukti Misi 1, masing-masing langsung berada dalam folder yang dibaca server.
makePart(map, "RambuSupport", Vector3.new(0.5, 2.5, 0.5), CFrame.new(-47, 1.25, -18), Color3.fromRGB(75, 77, 73), Enum.Material.Metal, false)
local clueSign = makePart(clues, "Clue_Rambu", Vector3.new(6, 4, 0.35), CFrame.new(-47, 4.5, -18), Color3.fromRGB(174, 57, 48), Enum.Material.Metal, false)
addSurfaceText(clueSign, "ClueLabel", Enum.NormalId.Front, "ZONA SEKOLAH\nRAMBU TERTUTUP DAUN", Color3.fromRGB(247, 230, 179))
local clueMarking = makePart(clues, "Clue_Marka", Vector3.new(6, 0.2, 4), CFrame.new(-10, 0.66, 0), Color3.fromRGB(143, 137, 123), Enum.Material.Concrete, false)
addBillboard(clueMarking, "MARKA ZEBRA CROSS PUDAR", Color3.fromRGB(255, 230, 151))
local clueLamp = makePart(clues, "Clue_Penerangan", Vector3.new(0.8, 9, 0.8), CFrame.new(47, 4.5, 18), Color3.fromRGB(72, 76, 80), Enum.Material.Metal, false)
addBillboard(clueLamp, "PENERANGAN MATI", Color3.fromRGB(255, 230, 151))

-- Dua meja dengan blueprint fisik yang terlihat. Server membuka voting setelah salah satu dipindai.
local stationA = makePart(blueprints, "Station_A", Vector3.new(14, 2, 8), CFrame.new(-30, 1, 64), Color3.fromRGB(141, 100, 64), Enum.Material.WoodPlanks)
local cardA = makePart(blueprints, "BlueprintCard_A", Vector3.new(10, 0.12, 5), CFrame.new(stationA.Position + Vector3.new(0, 1.12, 0)), Color3.fromRGB(220, 238, 250), Enum.Material.SmoothPlastic, false)
addSurfaceText(cardA, "BlueprintSurface", Enum.NormalId.Top, "BLUEPRINT A | MARKA & SPEED TABLE\nPita kejut antiselip\nSpeed table landai + drainase", Color3.fromRGB(220, 238, 250))
local stationB = makePart(blueprints, "Station_B", Vector3.new(14, 2, 8), CFrame.new(5, 1, 64), Color3.fromRGB(66, 103, 136), Enum.Material.Metal)
local cardB = makePart(blueprints, "BlueprintCard_B", Vector3.new(10, 0.12, 5), CFrame.new(stationB.Position + Vector3.new(0, 1.12, 0)), Color3.fromRGB(223, 242, 231), Enum.Material.SmoothPlastic, false)
addSurfaceText(cardB, "BlueprintSurface", Enum.NormalId.Top, "BLUEPRINT B | SMART TRAFFIC\nSensor penyeberangan\nLampu + hitung mundur + audio", Color3.fromRGB(223, 242, 231))
local workshopSign = makePart(map, "WorkshopSign", Vector3.new(14, 2, 0.3), CFrame.new(-30, 5, 59.7), Color3.fromRGB(100, 69, 43), Enum.Material.WoodPlanks, false)
addSurfaceText(workshopSign, "WorkshopTitle", Enum.NormalId.Front, "BENGKEL KONSTRUKSI JALAN", Color3.fromRGB(255, 244, 222))
local labSign = makePart(map, "ElectronicsLabSign", Vector3.new(14, 2, 0.3), CFrame.new(5, 5, 59.7), Color3.fromRGB(46, 78, 105), Enum.Material.Metal, false)
addSurfaceText(labSign, "LabTitle", Enum.NormalId.Front, "LAB KOMPUTER / ELEKTRONIK", Color3.fromRGB(225, 244, 255))

-- Logistik dan titik rakit berada di sisi jalan, tidak di jalur kendaraan.
local crate = makePart(supply, "Crate", Vector3.new(5, 4, 5), CFrame.new(39, 2, 64), Color3.fromRGB(156, 99, 55), Enum.Material.WoodPlanks)
addBillboard(crate, "KOTAK MATERIAL", Color3.fromRGB(255, 234, 189))
local slot = makePart(interaction, "PrototypeSlot", Vector3.new(8, 1, 7), CFrame.new(0, 0.5, -34), Color3.fromRGB(54, 126, 102), Enum.Material.Metal)
local assemblySound = Instance.new("Sound")
assemblySound.Name = "AssemblySound"
assemblySound.Volume = 1
assemblySound.RollOffMaxDistance = 60
assemblySound.Parent = slot

local entry = makePart(workspace, "Crosswalk_Entry", Vector3.new(4, 0.2, 4), CFrame.new(0, 0.62, -27), Color3.fromRGB(246, 213, 70), Enum.Material.Neon, false)
entry.Transparency = 0.45
local destination = makePart(workspace, "Crosswalk_Destination", Vector3.new(4, 0.2, 4), CFrame.new(0, 0.62, 27), Color3.fromRGB(81, 223, 129), Enum.Material.Neon, false)
destination.Transparency = 0.45

local signalLamp = makePart(simulation, "SignalLamp", Vector3.new(1.2, 6, 1.2), CFrame.new(8, 3, -22), Color3.fromRGB(70, 75, 78), Enum.Material.Metal)
local pointLight = Instance.new("PointLight")
pointLight.Name = "CrosswalkSignalLight"
pointLight.Color = Color3.fromRGB(64, 255, 121)
pointLight.Brightness = 2
pointLight.Range = 18
pointLight.Enabled = false
pointLight.Parent = signalLamp
makePart(simulation, "StopLine", Vector3.new(0.5, 0.08, 40), CFrame.new(-16, 0.54, 0), Color3.fromRGB(245, 245, 238), Enum.Material.SmoothPlastic, false)
makePart(simulation, "StopLine_East", Vector3.new(0.5, 0.08, 40), CFrame.new(16, 0.54, 0), Color3.fromRGB(245, 245, 238), Enum.Material.SmoothPlastic, false)

local forward = Vector3.new(1, 0, 0)
local reverse = Vector3.new(-1, 0, 0)
makeVehicle(simulation, "Vehicle_1", Vector3.new(-70, 1.5, -10), forward, Color3.fromRGB(193, 77, 59))
makeVehicle(simulation, "Vehicle_2", Vector3.new(70, 1.5, 10), reverse, Color3.fromRGB(58, 107, 170))
makeMarker(simulation, "VehicleStop_1", Vector3.new(-22, 1.5, -10), forward)
makeMarker(simulation, "VehiclePass_1", Vector3.new(54, 1.5, -10), forward)
makeMarker(simulation, "VehicleStop_2", Vector3.new(22, 1.5, 10), reverse)
makeMarker(simulation, "VehiclePass_2", Vector3.new(-54, 1.5, 10), reverse)
local hornSound = Instance.new("Sound")
hornSound.Name = "HornSound"
hornSound.Volume = 1.5
hornSound.RollOffMaxDistance = 120
hornSound.Parent = simulation

-- Gedung sekolah sederhana di ujung timur map.
makePart(map, "SchoolBuilding", Vector3.new(24, 12, 20), CFrame.new(72, 6, 44), Color3.fromRGB(232, 204, 140), Enum.Material.Concrete)
local schoolSign = makePart(map, "SchoolSign", Vector3.new(16, 2, 0.35), CFrame.new(72, 10, 33.8), Color3.fromRGB(53, 97, 77), Enum.Material.SmoothPlastic, false)
addSurfaceText(schoolSign, "SchoolTitle", Enum.NormalId.Front, "SEKOLAH", Color3.fromRGB(236, 255, 229))

-- Pakai SpawnLocation bawaan Baseplate jika ada; jika tidak, buat spawn baru.
local existingSpawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
local spawnLocation: SpawnLocation
if existingSpawn and existingSpawn:IsA("SpawnLocation") then
	spawnLocation = existingSpawn
	spawnLocation.Name = "CrossSafeSpawn"
	spawnLocation.Position = Vector3.new(-12, 1, -32)
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.AllowTeamChangeOnTouch = false
else
	spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "CrossSafeSpawn"
	spawnLocation.Position = Vector3.new(-12, 1, -32)
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.AllowTeamChangeOnTouch = false
	spawnLocation.Parent = workspace
end

print("CrossSafe fresh-map graybox siap. Tambahkan Rani_NPC dari Avatar > Rig Builder dan letakkan dekat Crosswalk_Entry. Atur SoundId AssemblySound/HornSound; script server membuat prompt saat Play.")

