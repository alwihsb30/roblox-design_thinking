--!strict
-- Jalankan SATU KALI di Roblox Studio > View > Command Bar saat mode Edit.
-- Menambah hiasan visual untuk layout CrossSafe hasil generator map baru.
-- Semua part hiasan Anchored dan tidak menghalangi pemain atau Rani.

local decorationRoot = workspace:FindFirstChild("EnvironmentDecorations")
if not decorationRoot or not decorationRoot:IsA("Folder") then
	error("Buat Workspace.EnvironmentDecorations sebagai Folder terlebih dahulu.")
end
if decorationRoot:FindFirstChild("CrossSafe_VisualDressing") then
	error("CrossSafe_VisualDressing sudah ada. Generator ini hanya dijalankan satu kali.")
end

local dressing = Instance.new("Folder")
dressing.Name = "CrossSafe_VisualDressing"
dressing.Parent = decorationRoot

local function makePart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local newPart = Instance.new("Part")
	newPart.Name = name
	newPart.Size = size
	newPart.CFrame = CFrame.new(position)
	newPart.Color = color
	newPart.Material = material
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	newPart.Parent = dressing
	return newPart
end

local function makeSign(name: string, size: Vector3, position: Vector3, title: string, color: Color3): Part
	local sign = makePart(name, size, position, color, Enum.Material.SmoothPlastic)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "DecorationSignGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 35
	surface.AlwaysOnTop = false
	surface.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = title
	label.TextColor3 = Color3.fromRGB(248, 246, 228)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = surface
	return sign
end

-- Lantai rumput membuat tepi map terasa seperti lingkungan sekolah.
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate.Material = Enum.Material.Grass
	baseplate.Color = Color3.fromRGB(87, 128, 78)
end

-- Gerbang sekolah berada di depan bangunan yang berpusat di X=72, Z=44.
local darkGreen = Color3.fromRGB(42, 83, 65)
local paleCream = Color3.fromRGB(239, 225, 180)
makePart("SchoolGate_LeftPillar", Vector3.new(1.3, 7, 1.3), Vector3.new(59, 3.5, 31), darkGreen, Enum.Material.Concrete)
makePart("SchoolGate_RightPillar", Vector3.new(1.3, 7, 1.3), Vector3.new(85, 3.5, 31), darkGreen, Enum.Material.Concrete)
makePart("SchoolGate_Header", Vector3.new(27, 0.8, 1.3), Vector3.new(72, 7, 31), darkGreen, Enum.Material.Metal)
makeSign("SchoolGate_Sign", Vector3.new(12, 1.7, 0.3), Vector3.new(72, 5.7, 30.25), "GERBANG SEKOLAH", darkGreen)

local gateXs = { 62.5, 64, 65.5, 67, 77, 78.5, 80, 81.5 }
for index, x in ipairs(gateXs) do
	makePart("SchoolGate_Bar_" .. tostring(index), Vector3.new(0.24, 4.1, 0.24), Vector3.new(x, 2.35, 31), darkGreen, Enum.Material.Metal)
end
for wingIndex, centerX in ipairs({ 64.75, 79.25 }) do
	makePart("SchoolGate_RailBottom_" .. tostring(wingIndex), Vector3.new(7.8, 0.25, 0.3), Vector3.new(centerX, 0.7, 31), darkGreen, Enum.Material.Metal)
	makePart("SchoolGate_RailTop_" .. tostring(wingIndex), Vector3.new(7.8, 0.25, 0.3), Vector3.new(centerX, 4.3, 31), darkGreen, Enum.Material.Metal)
end

for index, x in ipairs({ 64, 80 }) do
	local window = makePart("School_FrontWindow_" .. tostring(index), Vector3.new(4.5, 3, 0.18), Vector3.new(x, 6.3, 33.82), Color3.fromRGB(139, 196, 208), Enum.Material.Glass)
	window.Transparency = 0.25
end

-- Atap dan meja kecil memperjelas fungsi Pos Satpam. Papan analisis tetap terbuka.
makePart("GuardPost_Roof", Vector3.new(23.5, 0.6, 17), Vector3.new(-70, 7.45, 44.5), darkGreen, Enum.Material.Metal)
makePart("GuardPost_RoofTrim", Vector3.new(23.8, 0.28, 0.6), Vector3.new(-70, 7.05, 36), Color3.fromRGB(220, 185, 105), Enum.Material.WoodPlanks)
makePart("GuardPost_Desk", Vector3.new(6, 1.5, 2.5), Vector3.new(-75, 1.25, 40), Color3.fromRGB(127, 88, 56), Enum.Material.WoodPlanks)
makePart("GuardPost_DeskLeg_Left", Vector3.new(0.35, 1, 0.35), Vector3.new(-77.4, 0.5, 40), darkGreen, Enum.Material.Metal)
makePart("GuardPost_DeskLeg_Right", Vector3.new(0.35, 1, 0.35), Vector3.new(-72.6, 0.5, 40), darkGreen, Enum.Material.Metal)

-- Kanopi kecil memberi identitas berbeda pada Bengkel, Lab, dan tempat logistik.
local function makeCanopy(prefix: string, centerX: number, centerZ: number, roofColor: Color3, width: number, depth: number)
	makePart(prefix .. "_Roof", Vector3.new(width, 0.5, depth), Vector3.new(centerX, 7.5, centerZ), roofColor, Enum.Material.Metal)
	local xOffset = width / 2 - 0.5
	local zOffset = depth / 2 - 0.5
	local supportPositions = {
		Vector3.new(centerX - xOffset, 3.75, centerZ - zOffset),
		Vector3.new(centerX - xOffset, 3.75, centerZ + zOffset),
		Vector3.new(centerX + xOffset, 3.75, centerZ - zOffset),
		Vector3.new(centerX + xOffset, 3.75, centerZ + zOffset),
	}
	for index, position in ipairs(supportPositions) do
		makePart(prefix .. "_Post_" .. tostring(index), Vector3.new(0.45, 7.2, 0.45), position, roofColor, Enum.Material.Metal)
	end
end

makeCanopy("WorkshopCanopy", -30, 64, Color3.fromRGB(153, 105, 62), 19, 13)
makeCanopy("ElectronicsLabCanopy", 5, 64, Color3.fromRGB(65, 116, 148), 19, 13)
makeCanopy("MaterialCanopy", 39, 64, Color3.fromRGB(74, 104, 80), 10, 10)

-- Garis pemisah lajur. Bagian tengah dibiarkan kosong agar zebra cross tetap jelas.
local dashNumber = 0
for x = -82, -22, 8 do
	dashNumber += 1
	makePart("RoadCenterDash_West_" .. tostring(dashNumber), Vector3.new(3.5, 0.07, 0.22), Vector3.new(x, 0.56, 0), paleCream, Enum.Material.SmoothPlastic)
end
dashNumber = 0
for x = 22, 82, 8 do
	dashNumber += 1
	makePart("RoadCenterDash_East_" .. tostring(dashNumber), Vector3.new(3.5, 0.07, 0.22), Vector3.new(x, 0.56, 0), paleCream, Enum.Material.SmoothPlastic)
end

-- Pohon dekoratif ditempatkan di luar trotoar dan seluruhnya tidak bisa ditabrak.
local function makeTree(treeNumber: number, x: number, z: number)
	makePart("RoadsideTree_Trunk_" .. tostring(treeNumber), Vector3.new(1.1, 5, 1.1), Vector3.new(x, 2.5, z), Color3.fromRGB(111, 79, 51), Enum.Material.Wood)
	local lowerCrown = makePart("RoadsideTree_CrownA_" .. tostring(treeNumber), Vector3.new(5, 5, 5), Vector3.new(x, 6.1, z), Color3.fromRGB(72, 137, 78), Enum.Material.Grass)
	lowerCrown.Shape = Enum.PartType.Ball
	local upperCrown = makePart("RoadsideTree_CrownB_" .. tostring(treeNumber), Vector3.new(3.8, 3.8, 3.8), Vector3.new(x + 0.2, 8.1, z), Color3.fromRGB(94, 158, 88), Enum.Material.Grass)
	upperCrown.Shape = Enum.PartType.Ball
end

local treePositions = {
	{ -55, -35 }, { -30, -35 }, { 30, -35 }, { 55, -35 },
	{ -35, 35 }, { 30, 35 }, { 52, 35 },
}
for index, position in ipairs(treePositions) do
	makeTree(index, position[1], position[2])
end

-- Daun kecil di sekitar rambu menjelaskan masalahnya tanpa menutupi prompt.
for index, leafData in ipairs({
	{ -49, 5.8, -18.35 },
	{ -45, 5.7, -18.35 },
	{ -47, 7.1, -18.35 },
}) do
	local leaf = makePart("RambuFoliage_" .. tostring(index), Vector3.new(2.1, 1.7, 1.8), Vector3.new(leafData[1], leafData[2], leafData[3]), Color3.fromRGB(63, 130, 68), Enum.Material.Grass)
	leaf.Shape = Enum.PartType.Ball
end

-- Kap lampu tampak mati pada bukti penerangan.
makePart("StreetLamp_Arm", Vector3.new(0.35, 0.35, 2.5), Vector3.new(47, 9, 16.8), Color3.fromRGB(65, 70, 73), Enum.Material.Metal)
makePart("StreetLamp_Shade", Vector3.new(1.7, 0.45, 2.3), Vector3.new(47, 8.75, 15.5), Color3.fromRGB(54, 58, 61), Enum.Material.Metal)
makePart("StreetLamp_BulbOff", Vector3.new(0.8, 0.22, 0.8), Vector3.new(47, 8.48, 15.5), Color3.fromRGB(74, 76, 72), Enum.Material.SmoothPlastic)

-- Pencahayaan siang yang hangat.
local lighting = game:GetService("Lighting")
lighting.ClockTime = 8.5
lighting.Brightness = 2
lighting.Ambient = Color3.fromRGB(118, 129, 137)
lighting.OutdoorAmbient = Color3.fromRGB(157, 166, 165)

print("Hiasan CrossSafe selesai. Semua prop dekorasi ada di Workspace.EnvironmentDecorations.CrossSafe_VisualDressing. Tekan Ctrl+S, lalu Play untuk mengecek jalur NPC.")

