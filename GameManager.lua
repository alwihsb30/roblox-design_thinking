--!strict
-- Script server otoritatif: mengelola pilihan individu, saldo, misi, evaluasi, dan iterasi.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DecisionTreeData = require(ReplicatedStorage:WaitForChild("DecisionTreeData"))
local EvaluationService = require(script.Parent:WaitForChild("EvaluationService"))
local ClueQuestManager = require(script.Parent:WaitForChild("ClueQuestManager"))
local SpatialMissionManager = require(script.Parent:WaitForChild("SpatialMissionManager"))

local isTreeValid, treeError = DecisionTreeData.Validate()
assert(isTreeValid, "DecisionTreeData gagal divalidasi: " .. tostring(treeError))

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), name .. " harus berupa Folder")
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function getOrCreateRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("RemoteEvent"), name .. " harus berupa RemoteEvent")
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function getOrCreateRemoteFunction(parent: Instance, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("RemoteFunction"), name .. " harus berupa RemoteFunction")
		return existing
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

type TransactionAction = "PURCHASE" | "SALVAGE_REFUND" | "UPGRADE"
type Phase = "WAITING_FOR_RANI" | "DECISIONS" | "MISSION" | "SIMULATION" | "ITERATION" | "COMPLETE"

type TransactionRecord = {
	Timestamp: number,
	ActionType: TransactionAction,
	ItemKey: string,
	Amount: number,
	BalanceAfter: number,
}

local NetFolder = getOrCreateFolder(ReplicatedStorage, "GameNetwork")
local SubmitChoiceEvent = getOrCreateRemoteEvent(NetFolder, "SubmitChoice")
local SyncGameStateEvent = getOrCreateRemoteEvent(NetFolder, "SyncGameState")
local ChooseIterationEvent = getOrCreateRemoteEvent(NetFolder, "ChooseIteration")
local StartSessionEvent = getOrCreateRemoteEvent(NetFolder, "StartSession")
local GetGameStateFunction = getOrCreateRemoteFunction(NetFolder, "GetGameState")
ClueQuestManager.Initialize(SyncGameStateEvent)

local GameSession = {
	CurrentStage = 1,
	ActiveNodeKey = DecisionTreeData.Constants.RootNode,
	PathChoices = {} :: { string },
	SelectedPrototypeKey = "",
	Budget = DecisionTreeData.Constants.InitialBudget,
	Ledger = {} :: { TransactionRecord },
	Phase = "WAITING_FOR_RANI" :: Phase,
	IsPatched = false,
	LatestReport = nil :: any,
	PivotCount = 0,
}

local RaniPromptPart: BasePart? = nil
local RaniPrompt: ProximityPrompt? = nil
local sessionPlayer: Player? = nil
local needsSessionReset = false

local function getRaniPromptPart(npc: Instance): BasePart?
	local head = npc:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") then
		return head
	end
	local preferredPart = npc:FindFirstChild("HumanoidRootPart", true)
	if preferredPart and preferredPart:IsA("BasePart") then
		return preferredPart
	end
	if npc:IsA("Model") and npc.PrimaryPart then
		return npc.PrimaryPart
	end
	for _, descendant in ipairs(npc:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function setupRaniPrompt(npc: Instance)
	if RaniPrompt and RaniPrompt.Parent then
		return
	end
	local promptPart = getRaniPromptPart(npc)
	if not promptPart then
		warn("Workspace.Rani_NPC tidak memiliki BasePart untuk ProximityPrompt.")
		return
	end
	local prompt = promptPart:FindFirstChild("TalkToRaniPrompt")
	if prompt and not prompt:IsA("ProximityPrompt") then
		warn("TalkToRaniPrompt harus berupa ProximityPrompt; objek itu dilewati.")
		return
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TalkToRaniPrompt"
		prompt.Parent = promptPart
	end

	local talkPrompt = prompt :: ProximityPrompt
	talkPrompt.ActionText = "Ajak bicara"
	talkPrompt.ObjectText = "Rani"
	talkPrompt.KeyboardKeyCode = Enum.KeyCode.E
	talkPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	talkPrompt.HoldDuration = 0
	talkPrompt.MaxActivationDistance = 10
	-- The prompt may be attached to HumanoidRootPart; don't let the rig hide its own prompt.
	talkPrompt.RequiresLineOfSight = false
	talkPrompt.Enabled = true
	RaniPromptPart = promptPart
	RaniPrompt = talkPrompt

	talkPrompt.Triggered:Connect(function(player: Player)
		if sessionPlayer ~= player then
			return
		end
		if GameSession.Phase == "WAITING_FOR_RANI" then
			local foundCount, requiredCount = ClueQuestManager.GetProgress()
			if ClueQuestManager.IsComplete() then
				SyncGameStateEvent:FireClient(player, "RANI_DIALOGUE", foundCount, requiredCount)
			else
				SyncGameStateEvent:FireClient(player, "RANI_GATEKEEPER", foundCount, requiredCount)
			end
		elseif GameSession.Phase == "MISSION" or GameSession.Phase == "SIMULATION" then
			SpatialMissionManager.SendState(player)
		else
			SyncGameStateEvent:FireClient(player, "OPEN_GAME_UI")
		end
	end)
end

local existingRani = workspace:FindFirstChild("Rani_NPC")
if existingRani then
	setupRaniPrompt(existingRani)
else
	warn("NPC belum ditemukan. Tambahkan Model bernama Workspace.Rani_NPC agar sesi dapat dimulai lewat interaksi.")
	workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == "Rani_NPC" then
			setupRaniPrompt(child)
		end
	end)
end

local function isPlayerNearRani(player: Player): boolean
	local promptPart = RaniPromptPart
	if not promptPart or not promptPart.Parent then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local talkPrompt = RaniPrompt
	local allowedDistance = (talkPrompt and talkPrompt.MaxActivationDistance or 10) + 3
	return (root.Position - promptPart.Position).Magnitude <= allowedDistance
end

local function getNodeChoiceKeys(nodeKey: string, budget: number): { string }
	local node = DecisionTreeData.Nodes[nodeKey]
	if not node then
		return {}
	end
	local available: { string } = {}
	for choiceKey, choice in pairs(node.Choices) do
		if node.Stage == 4 then
			local prototype = DecisionTreeData.Prototypes[choiceKey]
			if prototype and prototype.Cost <= budget then
				table.insert(available, choiceKey)
			end
		elseif DecisionTreeData.Nodes[choice.NextNode] then
			-- Saring cabang yang berujung pada prototipe di luar saldo agar pemain tidak terkunci.
			if getNodeChoiceKeys(choice.NextNode, budget)[1] then
				table.insert(available, choiceKey)
			end
		end
	end
	table.sort(available)
	return available
end

local function sendPrompt(targetPlayer: Player?)
	if GameSession.Phase ~= "DECISIONS" then
		return
	end
	local allowedChoiceKeys = getNodeChoiceKeys(GameSession.ActiveNodeKey, GameSession.Budget)
	if targetPlayer then
		SyncGameStateEvent:FireClient(
			targetPlayer,
			"PROMPT_NODE",
			GameSession.ActiveNodeKey,
			allowedChoiceKeys,
			GameSession.Budget,
			GameSession.CurrentStage
		)
	else
		SyncGameStateEvent:FireAllClients(
			"PROMPT_NODE",
			GameSession.ActiveNodeKey,
			allowedChoiceKeys,
			GameSession.Budget,
			GameSession.CurrentStage
		)
	end
end

local function getPrototypeModel(modelName: string): Model?
	local folder = ServerStorage:FindFirstChild("PrototypeModels")
	if not folder or not folder:IsA("Folder") then
		return nil
	end
	local model = folder:FindFirstChild(modelName)
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

local function getPrototypeSlot(): BasePart?
	local station = workspace:FindFirstChild("InteractionStation")
	local slot = station and station:FindFirstChild("PrototypeSlot")
	if slot and slot:IsA("BasePart") then
		return slot
	end
	return nil
end

local function destroyMountedModels()
	for _, modelName in ipairs({ "ActivePrototypeInstance", "ActiveQuickPatchInstance" }) do
		local model = workspace:FindFirstChild(modelName)
		if model then
			model:Destroy()
		end
	end
end

local function mountPrototypeModel(modelName: string): boolean
	local slot = getPrototypeSlot()
	local template = getPrototypeModel(modelName)
	if not slot then
		warn("Workspace.InteractionStation.PrototypeSlot tidak ditemukan; model prototipe tidak dapat dipasang.")
		return false
	end
	destroyMountedModels()
	if template then
		local clone = template:Clone()
		clone.Name = "ActivePrototypeInstance"
		clone:PivotTo(slot.CFrame)
		clone.Parent = workspace
	else
		-- Graybox terlihat tetap tersedia walau model dekoratif belum dibuat.
		warn("Model prototipe belum ada di ServerStorage.PrototypeModels; menampilkan graybox berlabel: " .. modelName)
		local fallback = Instance.new("Model")
		fallback.Name = "ActivePrototypeInstance"
		local block = Instance.new("Part")
		block.Name = "PrototypePreview"
		block.Size = Vector3.new(4, 3, 4)
		block.CFrame = slot.CFrame * CFrame.new(0, slot.Size.Y / 2 + 1.5, 0)
		block.Anchored = true
		block.Color = Color3.fromRGB(58, 153, 130)
		block.Material = Enum.Material.Neon
		block.Parent = fallback
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PrototypeName"
		billboard.Size = UDim2.fromOffset(230, 58)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = block
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(24, 35, 48)
		label.Text = "PROTOTIPE\n" .. modelName
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.TextWrapped = true
		label.Font = Enum.Font.GothamBold
		label.Parent = billboard
		fallback.PrimaryPart = block
		fallback.Parent = workspace
	end
	return true
end

local function mountQuickPatchModel(modelName: string)
	local slot = getPrototypeSlot()
	local template = getPrototypeModel(modelName)
	if not slot then
		warn("PrototypeSlot tidak ditemukan; visual Quick Patch dilewati.")
		return
	end
	if not template then
		warn("Model Quick Patch tidak ditemukan di ServerStorage.PrototypeModels: " .. modelName)
		return
	end
	local oldPatch = workspace:FindFirstChild("ActiveQuickPatchInstance")
	if oldPatch then
		oldPatch:Destroy()
	end
	local clone = template:Clone()
	clone.Name = "ActiveQuickPatchInstance"
	clone:PivotTo(slot.CFrame)
	clone.Parent = workspace
end

local function recordTransaction(action: TransactionAction, itemKey: string, amount: number): boolean
	if amount <= 0 or amount % 1 ~= 0 then
		return false
	end
	if (action == "PURCHASE" or action == "UPGRADE") and GameSession.Budget < amount then
		return false
	end
	if action == "PURCHASE" or action == "UPGRADE" then
		GameSession.Budget -= amount
	else
		GameSession.Budget += amount
		if GameSession.Budget > DecisionTreeData.Constants.InitialBudget then
			error("Pengembalian dana melewati modal awal")
		end
	end
	table.insert(GameSession.Ledger, {
		Timestamp = os.time(),
		ActionType = action,
		ItemKey = itemKey,
		Amount = amount,
		BalanceAfter = GameSession.Budget,
	})
	return true
end

local presentDecision: (Player?) -> ()
local processSelectedChoice: (string) -> ()
local presentIterationDecision: (Player?) -> ()

local function publishReport(report: any)
	GameSession.LatestReport = report
	GameSession.Phase = if report.CanQuickPatch or report.CanDeepPivot then "ITERATION" else "COMPLETE"
	SyncGameStateEvent:FireAllClients("SHOW_EVALUATION_REPORT", report, GameSession.Budget)
	if GameSession.Phase == "ITERATION" then
		presentIterationDecision(nil)
	end
end

local function evaluateCurrentSession(): any
	return EvaluationService.EvaluateFullSession(
		GameSession.PathChoices,
		GameSession.SelectedPrototypeKey,
		GameSession.Budget,
		GameSession.IsPatched
	)
end

local function beginWarRoomMission()
	GameSession.Phase = "MISSION"
	SpatialMissionManager.StartWarRoomMission()
end

local function beginBlueprintMission()
	GameSession.Phase = "MISSION"
	SpatialMissionManager.StartBlueprintMission()
end

local function startTestingSimulation()
	GameSession.Phase = "SIMULATION"
	GameSession.CurrentStage = 5
	local report = evaluateCurrentSession()
	SpatialMissionManager.RunTestingSimulation(report.SafetyStatus, function()
		if GameSession.Phase == "SIMULATION" then
			publishReport(report)
		end
	end)
end

local function finishPrototypePurchase(prototypeKey: string)
	local prototype = DecisionTreeData.Prototypes[prototypeKey]
	local node = DecisionTreeData.Nodes[GameSession.ActiveNodeKey]
	if not prototype or not node or node.Stage ~= 4 or not node.Choices[prototypeKey] then
		warn("Pilihan prototipe tidak sah untuk node aktif.")
		return
	end
	if prototype.ParentChoiceId ~= GameSession.PathChoices[3] then
		warn("Induk prototipe tidak cocok dengan jalur sesi; pembelian ditolak.")
		return
	end
	if prototype.Cost > GameSession.Budget then
		SyncGameStateEvent:FireAllClients("BUDGET_REJECTED", GameSession.Budget, prototype.Cost)
		presentDecision(nil)
		return
	end
	local worldReady, setupMessage = SpatialMissionManager.CanRunTestingSimulation()
	if not worldReady then
		SyncGameStateEvent:FireAllClients("MISSION_SETUP_MISSING", setupMessage)
		presentDecision(nil)
		return
	end
	if not recordTransaction("PURCHASE", prototypeKey, prototype.Cost) then
		SyncGameStateEvent:FireAllClients("BUDGET_REJECTED", GameSession.Budget, prototype.Cost)
		presentDecision(nil)
		return
	end

	GameSession.SelectedPrototypeKey = prototypeKey
	GameSession.IsPatched = false
	GameSession.Phase = "MISSION"
	GameSession.CurrentStage = 4
	if not SpatialMissionManager.StartMaterialMission() then
		-- Workspace was checked before the purchase; this is a guard for a part removed during runtime.
		SyncGameStateEvent:FireAllClients("MISSION_SETUP_MISSING", "Objek logistik berubah saat sesi berjalan. Hentikan Play Test dan pulihkan Workspace.")
	end
end

processSelectedChoice = function(selectedChoiceKey: string)
	if GameSession.Phase ~= "DECISIONS" then
		return
	end
	local node = DecisionTreeData.Nodes[GameSession.ActiveNodeKey]
	local choice = node and node.Choices[selectedChoiceKey]
	if not node or not choice then
		warn(string.format("Pilihan %s bukan bagian dari node aktif.", tostring(selectedChoiceKey)))
		presentDecision(nil)
		return
	end
	if not table.find(getNodeChoiceKeys(GameSession.ActiveNodeKey, GameSession.Budget), selectedChoiceKey) then
		warn("Pilihan tidak lagi terjangkau dengan saldo saat ini.")
		presentDecision(nil)
		return
	end

	if GameSession.CurrentStage <= 3 then
		local completedStage = GameSession.CurrentStage
		table.insert(GameSession.PathChoices, selectedChoiceKey)
		GameSession.CurrentStage += 1
		GameSession.ActiveNodeKey = choice.NextNode
		if completedStage == 1 then
			beginWarRoomMission()
		elseif completedStage == 2 then
			beginBlueprintMission()
		else
			presentDecision(nil)
		end
	elseif GameSession.CurrentStage == 4 then
		finishPrototypePurchase(selectedChoiceKey)
	end
end

presentDecision = function(targetPlayer: Player?)
	if GameSession.Phase ~= "DECISIONS" or #Players:GetPlayers() == 0 then
		return
	end
	local allowedChoiceKeys = getNodeChoiceKeys(GameSession.ActiveNodeKey, GameSession.Budget)
	if #allowedChoiceKeys == 0 then
		warn("Tidak ada prototipe yang terjangkau dari node aktif. Periksa logika anggaran pohon keputusan.")
		if targetPlayer then
			SyncGameStateEvent:FireClient(targetPlayer, "NO_AFFORDABLE_PROTOTYPE", GameSession.Budget)
		else
			SyncGameStateEvent:FireAllClients("NO_AFFORDABLE_PROTOTYPE", GameSession.Budget)
		end
		return
	end
	sendPrompt(targetPlayer)
end

local function deepPivot()
	local prototype = DecisionTreeData.Prototypes[GameSession.SelectedPrototypeKey]
	if not prototype then
		return
	end
	local refund = math.floor(prototype.Cost * 0.5)
	if not recordTransaction("SALVAGE_REFUND", prototype.Name, refund) then
		return
	end

	GameSession.PivotCount += 1
	GameSession.PathChoices = { "1.B" }
	GameSession.CurrentStage = 2
	GameSession.ActiveNodeKey = "Stage2_From1B"
	GameSession.SelectedPrototypeKey = ""
	GameSession.IsPatched = false
	GameSession.LatestReport = nil
	GameSession.Phase = "MISSION"
	destroyMountedModels()
	SyncGameStateEvent:FireAllClients("DEEP_PIVOT_STARTED", GameSession.Budget, GameSession.PivotCount)
	beginWarRoomMission()
end

local function getIterationActionKeys(): { string }
	if GameSession.Phase ~= "ITERATION" or GameSession.SelectedPrototypeKey == "" then
		return {}
	end
	local report = evaluateCurrentSession()
	local actions: { string } = {}
	if report.CanQuickPatch then
		table.insert(actions, "QUICK_PATCH")
	end
	if report.CanDeepPivot then
		table.insert(actions, "DEEP_PIVOT")
	end
	table.sort(actions)
	return actions
end

local function sendIterationPrompt(targetPlayer: Player?)
	local actions = getIterationActionKeys()
	if #actions == 0 then
		return
	end
	local report = GameSession.LatestReport
	if targetPlayer then
		SyncGameStateEvent:FireClient(targetPlayer, "PROMPT_ITERATION", actions, GameSession.Budget, report and report.MustDeepPivot == true)
	else
		SyncGameStateEvent:FireAllClients("PROMPT_ITERATION", actions, GameSession.Budget, report and report.MustDeepPivot == true)
	end
end

local function applyIteration(iterationType: string, player: Player)
	if GameSession.Phase ~= "ITERATION" then
		SyncGameStateEvent:FireClient(player, "ITERATION_REJECTED", "ITERATION_UNAVAILABLE")
		return
	end
	if not table.find(getIterationActionKeys(), iterationType) then
		SyncGameStateEvent:FireClient(player, "ITERATION_REJECTED", "ITERATION_UNAVAILABLE")
		sendIterationPrompt(player)
		return
	end
	local report = evaluateCurrentSession()
	if iterationType == "QUICK_PATCH" then
		local prototype = DecisionTreeData.Prototypes[GameSession.SelectedPrototypeKey]
		local patch = prototype and prototype.QuickPatch
		if GameSession.IsPatched or not report.CanQuickPatch or not patch then
			SyncGameStateEvent:FireAllClients("ITERATION_REJECTED", "QUICK_PATCH_UNAVAILABLE")
			return
		end
		if not recordTransaction("UPGRADE", GameSession.SelectedPrototypeKey .. ":QUICK_PATCH", patch.Cost) then
			SyncGameStateEvent:FireAllClients("ITERATION_REJECTED", "INSUFFICIENT_BUDGET")
			return
		end
		GameSession.IsPatched = true
		mountQuickPatchModel(patch.ModelName)
		startTestingSimulation()
	elseif iterationType == "DEEP_PIVOT" then
		if not report.CanDeepPivot then
			SyncGameStateEvent:FireAllClients("ITERATION_REJECTED", "DEEP_PIVOT_UNAVAILABLE")
			return
		end
		deepPivot()
	end
end

presentIterationDecision = function(targetPlayer: Player?)
	if GameSession.Phase ~= "ITERATION" or #Players:GetPlayers() == 0 then
		return
	end
	local allowedActions = getIterationActionKeys()
	if #allowedActions == 0 then
		GameSession.Phase = "COMPLETE"
		return
	end
	sendIterationPrompt(targetPlayer)
end

local function copyLedger(): { TransactionRecord }
	local copy: { TransactionRecord } = {}
	for _, transaction in ipairs(GameSession.Ledger) do
		table.insert(copy, table.clone(transaction))
	end
	return copy
end

local function handleIterationChoice(player: Player, iterationType: any)
	if sessionPlayer ~= player then
		SyncGameStateEvent:FireClient(player, "SOLO_SERVER_REQUIRED")
		return
	end
	if GameSession.Phase ~= "ITERATION" or typeof(iterationType) ~= "string" then
		SyncGameStateEvent:FireClient(player, "ITERATION_REJECTED", "ITERATION_UNAVAILABLE")
		return
	end
	applyIteration(iterationType, player)
end

local function handleSpatialMissionCompleted(missionKey: string, _player: Player, _detail: string?)
	if missionKey == "WAR_ROOM" and GameSession.Phase == "MISSION" and GameSession.CurrentStage == 2 then
		GameSession.Phase = "DECISIONS"
		presentDecision(nil)
	elseif missionKey == "BLUEPRINT" and GameSession.Phase == "MISSION" and GameSession.CurrentStage == 3 then
		GameSession.Phase = "DECISIONS"
		presentDecision(nil)
	elseif missionKey == "ASSEMBLY" and GameSession.Phase == "MISSION" and GameSession.CurrentStage == 4 then
		local prototype = DecisionTreeData.Prototypes[GameSession.SelectedPrototypeKey]
		if not prototype then
			warn("Prototipe hilang saat misi perakitan selesai; simulasi tidak dimulai.")
			return
		end
		mountPrototypeModel(prototype.ModelName)
		SyncGameStateEvent:FireAllClients("ASSEMBLY_COMPLETE", "Model " .. prototype.ModelName .. " sudah tampil di PrototypeSlot. Simulasi penyeberangan dimulai.")
		startTestingSimulation()
	end
end

SpatialMissionManager.Initialize(SyncGameStateEvent, handleSpatialMissionCompleted)

StartSessionEvent.OnServerEvent:Connect(function(player: Player)
	if sessionPlayer ~= player then
		SyncGameStateEvent:FireClient(player, "SOLO_SERVER_REQUIRED")
		return
	end
	if not isPlayerNearRani(player) then
		SyncGameStateEvent:FireClient(player, "START_REJECTED", "DEKATI_RANI")
		return
	end
	if not ClueQuestManager.IsComplete() then
		local foundCount, requiredCount = ClueQuestManager.GetProgress()
		SyncGameStateEvent:FireClient(player, "RANI_GATEKEEPER", foundCount, requiredCount)
		return
	end
	if GameSession.Phase ~= "WAITING_FOR_RANI" then
		if GameSession.Phase == "MISSION" or GameSession.Phase == "SIMULATION" then
			SpatialMissionManager.SendState(player)
		else
			SyncGameStateEvent:FireClient(player, "OPEN_GAME_UI")
		end
		return
	end

	GameSession.Phase = "DECISIONS"
	SyncGameStateEvent:FireClient(player, "SESSION_STARTED")
	presentDecision(player)
end)

SubmitChoiceEvent.OnServerEvent:Connect(function(player: Player, nodeKey: any, choiceKey: any)
	if sessionPlayer ~= player then
		SyncGameStateEvent:FireClient(player, "SOLO_SERVER_REQUIRED")
		return
	end
	if typeof(nodeKey) ~= "string" or typeof(choiceKey) ~= "string"
		or GameSession.Phase ~= "DECISIONS"
		or nodeKey ~= GameSession.ActiveNodeKey then
		SyncGameStateEvent:FireClient(player, "CHOICE_REJECTED", "INVALID_OR_STALE_CHOICE")
		if GameSession.Phase == "DECISIONS" then
			sendPrompt(player)
		end
		return
	end
	if not table.find(getNodeChoiceKeys(GameSession.ActiveNodeKey, GameSession.Budget), choiceKey) then
		SyncGameStateEvent:FireClient(player, "CHOICE_REJECTED", "CHOICE_UNAVAILABLE")
		sendPrompt(player)
		return
	end
	processSelectedChoice(choiceKey)
end)

ChooseIterationEvent.OnServerEvent:Connect(handleIterationChoice)

GetGameStateFunction.OnServerInvoke = function(_player: Player)
	local clueCount, cluesRequired = ClueQuestManager.GetProgress()
	local spatialState = SpatialMissionManager.GetSnapshot()
	return {
		Phase = GameSession.Phase,
		CurrentStage = GameSession.CurrentStage,
		ActiveNodeKey = GameSession.ActiveNodeKey,
		AllowedChoiceKeys = if GameSession.Phase == "DECISIONS" then getNodeChoiceKeys(GameSession.ActiveNodeKey, GameSession.Budget) else {},
		AllowedIterationActions = if GameSession.Phase == "ITERATION" then getIterationActionKeys() else {},
		Budget = GameSession.Budget,
		PathChoices = table.clone(GameSession.PathChoices),
		SelectedPrototypeKey = GameSession.SelectedPrototypeKey,
		IsPatched = GameSession.IsPatched,
		PivotCount = GameSession.PivotCount,
		ClueCount = clueCount,
		CluesRequired = cluesRequired,
		MissionKey = spatialState.MissionKey,
		MissionTitle = spatialState.MissionTitle,
		MissionDetail = spatialState.MissionDetail,
		MissionProgress = spatialState.MissionProgress,
		MissionRequired = spatialState.MissionRequired,
		BlueprintVisited = spatialState.BlueprintVisited,
		LatestReport = if GameSession.Phase == "SIMULATION" then nil else GameSession.LatestReport,
		Ledger = copyLedger(),
	}
end

local function resetGameSession()
	GameSession.CurrentStage = 1
	GameSession.ActiveNodeKey = DecisionTreeData.Constants.RootNode
	table.clear(GameSession.PathChoices)
	GameSession.SelectedPrototypeKey = ""
	GameSession.Budget = DecisionTreeData.Constants.InitialBudget
	table.clear(GameSession.Ledger)
	GameSession.Phase = "WAITING_FOR_RANI"
	GameSession.IsPatched = false
	GameSession.LatestReport = nil
	GameSession.PivotCount = 0
	destroyMountedModels()
	ClueQuestManager.Reset()
	SpatialMissionManager.ResetSession()
end

Players.PlayerAdded:Connect(function(player: Player)
	if sessionPlayer and sessionPlayer ~= player then
		player:Kick("CrossSafe dirancang untuk satu pemain per server. Atur kapasitas server menjadi 1 pemain.")
		return
	end
	if needsSessionReset then
		resetGameSession()
		needsSessionReset = false
	end
	sessionPlayer = player

	task.defer(function()
		if player.Parent ~= Players or sessionPlayer ~= player then
			return
		end
		ClueQuestManager.SendProgress(player)
		if GameSession.CurrentStage >= 2 or GameSession.Phase == "MISSION" or GameSession.Phase == "SIMULATION" then
			SpatialMissionManager.SendState(player)
		end
		if GameSession.Phase == "DECISIONS" then
			sendPrompt(player)
		elseif GameSession.Phase == "MISSION" or GameSession.Phase == "SIMULATION" then
			return
		elseif GameSession.LatestReport then
			SyncGameStateEvent:FireClient(player, "SHOW_EVALUATION_REPORT", GameSession.LatestReport, GameSession.Budget)
			if GameSession.Phase == "ITERATION" then
				sendIterationPrompt(player)
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	if sessionPlayer ~= player then
		return
	end
	sessionPlayer = nil
	needsSessionReset = true
	task.defer(function()
		if sessionPlayer == nil and #Players:GetPlayers() == 0 and needsSessionReset then
			resetGameSession()
			needsSessionReset = false
		end
	end)
end)