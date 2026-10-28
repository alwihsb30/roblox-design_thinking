--!strict
-- Jalankan sekali di Roblox Studio > View > Command Bar saat mode Edit.
-- Posisi di bawah hanya contoh sekitar titik origin; pindahkan tiap Part ke lokasi jalan yang benar.

local origin = Vector3.new(0, 0, 0)
local folder = workspace:FindFirstChild("InvestigationClues")

if folder and not folder:IsA("Folder") then
	error("Workspace.InvestigationClues sudah ada tetapi bukan Folder.")
end

if not folder then
	folder = Instance.new("Folder")
	folder.Name = "InvestigationClues"
	folder.Parent = workspace
end

local clueParts = {
	{
		Name = "Clue_Rambu",
		Size = Vector3.new(4, 3, 0.25),
		Offset = Vector3.new(-20, 4, 0),
		Color = Color3.fromRGB(125, 45, 38),
		Material = Enum.Material.Metal,
	},
	{
		Name = "Clue_Marka",
		Size = Vector3.new(8, 0.12, 4),
		Offset = Vector3.new(0, 0.12, 0),
		Color = Color3.fromRGB(115, 112, 99),
		Material = Enum.Material.Asphalt,
	},
	{
		Name = "Clue_Penerangan",
		Size = Vector3.new(0.6, 8, 0.6),
		Offset = Vector3.new(20, 4, 0),
		Color = Color3.fromRGB(65, 69, 75),
		Material = Enum.Material.Metal,
	},
}

for _, spec in ipairs(clueParts) do
	local part = folder:FindFirstChild(spec.Name)
	if part and not part:IsA("BasePart") then
		warn(spec.Name .. " sudah ada tetapi bukan Part; bagian itu dilewati.")
		continue
	end
	if not part then
		part = Instance.new("Part")
		part.Name = spec.Name
		part.Parent = folder
	end
	local cluePart = part :: BasePart
	cluePart.Anchored = true
	cluePart.CanCollide = false
	cluePart.Size = spec.Size
	cluePart.Position = origin + spec.Offset
	cluePart.Color = spec.Color
	cluePart.Material = spec.Material
	cluePart.TopSurface = Enum.SurfaceType.Smooth
	cluePart.BottomSurface = Enum.SurfaceType.Smooth
end

print("InvestigationClues siap. Pindahkan ketiga Part ke lokasi bukti pada jalan; prompt dibuat oleh ClueQuestManager saat Play.")

