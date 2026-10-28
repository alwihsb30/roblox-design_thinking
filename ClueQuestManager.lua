--!strict
-- ModuleScript server untuk misi pencarian tiga bukti fisik. Progres dibagi oleh satu tim per server.

type ClueDefinition = {
	Id: string,
	PartName: string,
	DisplayName: string,
	Description: string,
}

local ClueQuestManager = {} :: {
	Initialize: (RemoteEvent) -> (),
	GetProgress: () -> (number, number),
	IsComplete: () -> boolean,
	SendProgress: (Player) -> (),
}

local CLUES: { ClueDefinition } = {
	{
		Id = "RAMBU",
		PartName = "Clue_Rambu",
		DisplayName = "Rambu Tertutup Daun",
		Description = "Rambu Zona Sekolah tertutup daun lebat! Supir dari tikungan tidak bisa melihat peringatan ini.",
	},
	{
		Id = "MARKA",
		PartName = "Clue_Marka",
		DisplayName = "Marka Zebra Cross",
		Description = "Garis zebra cross sudah terkelupas dan licin. Tidak ada marka kejut untuk memperlambat roda mobil.",
	},
	{
		Id = "PENERANGAN",
		PartName = "Clue_Penerangan",
		DisplayName = "Tiang Lampu Jalan",
		Description = "Lampu penerangan mati total dan tidak ada penanda visual aktif saat kondisi jalan berkabut/gelap.",
	},
}

local CLUE_BY_PART_NAME: { [string]: ClueDefinition } = {}
for _, clue in ipairs(CLUES) do
	CLUE_BY_PART_NAME[clue.PartName] = clue
end

local foundById: { [string]: boolean } = {}
local boundParts: { [Instance]: boolean } = {}
local boundFolders: { [Instance]: boolean } = {}
local syncEvent: RemoteEvent? = nil
local isInitialized = false

local function countFound(): number
	local count = 0
	for _, clue in ipairs(CLUES) do
		if foundById[clue.Id] then
			count += 1
		end
	end
	return count
end

function ClueQuestManager.GetProgress(): (number, number)
	return countFound(), #CLUES
end

function ClueQuestManager.IsComplete(): boolean
	return countFound() >= #CLUES
end

function ClueQuestManager.SendProgress(player: Player)
	local remote = syncEvent
	if not remote then
		return
	end
	remote:FireClient(player, "CLUE_PROGRESS", countFound(), #CLUES)
end

local function isPlayerCloseToClue(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	-- Validasi server tambahan selain pemeriksaan jarak ProximityPrompt.
	return (root.Position - part.Position).Magnitude <= 12
end

local function bindCluePart(instance: Instance)
	local clue = CLUE_BY_PART_NAME[instance.Name]
	if not clue or boundParts[instance] then
		return
	end
	if not instance:IsA("BasePart") then
		warn(string.format("%s harus berupa BasePart.", clue.PartName))
		return
	end
	boundParts[instance] = true
	instance.Anchored = true

	local existingPrompt = instance:FindFirstChild("InvestigatePrompt")
	if existingPrompt and not existingPrompt:IsA("ProximityPrompt") then
		warn(string.format("InvestigatePrompt pada %s harus berupa ProximityPrompt.", clue.PartName))
		return
	end
	local prompt = existingPrompt :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "InvestigatePrompt"
		prompt.Parent = instance
	end

	prompt.ActionText = "Periksa"
	prompt.ObjectText = clue.DisplayName
	prompt.HoldDuration = 1.0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = not foundById[clue.Id]

	prompt.Triggered:Connect(function(player: Player)
		if foundById[clue.Id] or not prompt.Enabled then
			return
		end
		if not isPlayerCloseToClue(player, instance) then
			return
		end

		foundById[clue.Id] = true
		prompt.Enabled = false
		local remote = syncEvent
		if remote then
			remote:FireAllClients("CLUE_FOUND", clue.Id, clue.DisplayName, clue.Description, countFound(), #CLUES)
		end
	end)
end

local function bindClueFolder(instance: Instance)
	if instance.Name ~= "InvestigationClues" or boundFolders[instance] then
		return
	end
	if not instance:IsA("Folder") then
		warn("Workspace.InvestigationClues harus berupa Folder.")
		return
	end
	boundFolders[instance] = true
	for _, child in ipairs(instance:GetChildren()) do
		bindCluePart(child)
	end
	instance.ChildAdded:Connect(bindCluePart)
end

function ClueQuestManager.Initialize(remote: RemoteEvent)
	if isInitialized then
		return
	end
	isInitialized = true
	syncEvent = remote

	local existingFolder = workspace:FindFirstChild("InvestigationClues")
	if existingFolder then
		bindClueFolder(existingFolder)
	else
		warn("Folder Workspace.InvestigationClues belum ada. Buat folder dan part bukti sebelum Play Test.")
	end
	workspace.ChildAdded:Connect(bindClueFolder)
end

return ClueQuestManager

