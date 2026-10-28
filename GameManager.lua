--!strict
-- Script di ServerScriptService. Otoritas tunggal untuk alur permainan, voting, saldo, dan iterasi.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DecisionTreeData = require(ReplicatedStorage:WaitForChild("DecisionTreeData"))
local VotingHandler = require(script.Parent:WaitForChild("VotingHandler"))
local EvaluationService = require(script.Parent:WaitForChild("EvaluationService"))

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
type Phase = "WAITING_FOR_RANI" | "DECISIONS" | "ITERATION" | "COMPLETE"

type TransactionRecord = {
	Timestamp: number,
	ActionType: TransactionAction,
	ItemKey: string,
	Amount: number,
	BalanceAfter: number,
}

local NetFolder = getOrCreateFolder(ReplicatedStorage, "GameNetwork")
local SubmitVoteEvent = getOrCreateRemoteEvent(NetFolder, "SubmitVote")
local SyncGameStateEvent = getOrCreateRemoteEvent(NetFolder, "SyncGameState")
local TriggerIterationEvent = getOrCreateRemoteEvent(NetFolder, "TriggerIteration")
local StartSessionEvent = getOrCreateRemoteEvent(NetFolder, "StartSession")
local GetGameStateFunction = getOrCreateRemoteFunction(NetFolder, "GetGameState")

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
		if GameSession.Phase == "WAITING_FOR_RANI" then
			SyncGameStateEvent:FireClient(player, "RANI_DIALOGUE")
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
			-- Saring cabang yang berujung pada prototipe di luar saldo agar tim tidak terkunci.
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
			GameSession.CurrentStage,
			VotingHandler.GetActiveToken()
		)
	else
		SyncGameStateEvent:FireAllClients(
			"PROMPT_NODE",
			GameSession.ActiveNodeKey,
			allowedChoiceKeys,
			GameSession.Budget,
			GameSession.CurrentStage,
			VotingHandler.GetActiveToken()
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
		warn("Workspace.InteractionStation.PrototypeSlot tidak ditemukan; visual prototipe dilewati.")
		return false
	end
	if not template then
		warn("Model prototipe tidak ditemukan di ServerStorage.PrototypeModels: " .. modelName)
		return false
	end
	destroyMountedModels()
	local clone = template:Clone()
	clone.Name = "ActivePrototypeInstance"
	clone:PivotTo(slot.CFrame)
	clone.Parent = workspace
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

local startVoting: () -> ()
local processWinningChoice: (string) -> ()
local startIterationVoting: () -> ()

local function publishReport(report: any)
	GameSession.LatestReport = report
	GameSession.Phase = if report.CanQuickPatch or report.CanDeepPivot then "ITERATION" else "COMPLETE"
	SyncGameStateEvent:FireAllClients("SHOW_EVALUATION_REPORT", report, GameSession.Budget)
	if GameSession.Phase == "ITERATION" then
		startIterationVoting()
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

local function finishPrototypePurchase(prototypeKey: string)
	local prototype = DecisionTreeData.Prototypes[prototypeKey]
	local node = DecisionTreeData.Nodes[GameSession.ActiveNodeKey]
	if not prototype or not node or node.Stage ~= 4 or not node.Choices[prototypeKey] then
		warn("VotingHandler mengembalikan prototipe yang tidak sah untuk node aktif.")
		return
	end
	if prototype.ParentChoiceId ~= GameSession.PathChoices[3] then
		warn("Induk prototipe tidak cocok dengan jalur sesi; pembelian ditolak.")
		return
	end
	if prototype.Cost > GameSession.Budget then
		SyncGameStateEvent:FireAllClients("BUDGET_REJECTED", GameSession.Budget, prototype.Cost)
		startVoting()
		return
	end
	if not recordTransaction("PURCHASE", prototypeKey, prototype.Cost) then
		SyncGameStateEvent:FireAllClients("BUDGET_REJECTED", GameSession.Budget, prototype.Cost)
		startVoting()
		return
	end

	GameSession.SelectedPrototypeKey = prototypeKey
	GameSession.IsPatched = false
	GameSession.CurrentStage = 5
	mountPrototypeModel(prototype.ModelName)
	local report = evaluateCurrentSession()
	publishReport(report)
end

processWinningChoice = function(winningChoice: string)
	if GameSession.Phase ~= "DECISIONS" then
		return
	end
	local node = DecisionTreeData.Nodes[GameSession.ActiveNodeKey]
	local choice = node and node.Choices[winningChoice]
	if not node or not choice then
		warn(string.format("Pilihan pemenang %s bukan bagian dari node aktif.", tostring(winningChoice)))
		startVoting()
		return
	end
	if not table.find(getNodeChoiceKeys(GameSession.ActiveNodeKey, GameSession.Budget), winningChoice) then
		warn("Pilihan pemenang tidak lagi terjangkau dengan saldo saat ini.")
		startVoting()
		return
	end

	if GameSession.CurrentStage <= 3 then
		table.insert(GameSession.PathChoices, winningChoice)
		GameSession.CurrentStage += 1
		GameSession.ActiveNodeKey = choice.NextNode
		startVoting()
	elseif GameSession.CurrentStage == 4 then
		finishPrototypePurchase(winningChoice)
	end
end

startVoting = function()
	if GameSession.Phase ~= "DECISIONS" or #Players:GetPlayers() == 0 or VotingHandler.IsActive() then
		return
	end
	local allowedChoiceKeys = getNodeChoiceKeys(GameSession.ActiveNodeKey, GameSession.Budget)
	if #allowedChoiceKeys == 0 then
		warn("Tidak ada prototipe yang terjangkau dari node aktif. Periksa logika anggaran pohon keputusan.")
		SyncGameStateEvent:FireAllClients("NO_AFFORDABLE_PROTOTYPE", GameSession.Budget)
		return
	end
	local started = VotingHandler.StartSession(
		GameSession.ActiveNodeKey,
		DecisionTreeData.Constants.VoteDurationSeconds,
		allowedChoiceKeys,
		function(winningChoice: string?)
			if GameSession.Phase == "DECISIONS" and winningChoice then
				processWinningChoice(winningChoice)
			end
		end
	)
	if started then
		sendPrompt(nil)
	end
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

	VotingHandler.CancelSession()
	GameSession.PivotCount += 1
	GameSession.PathChoices = { "1.B" }
	GameSession.CurrentStage = 2
	GameSession.ActiveNodeKey = "Stage2_From1B"
	GameSession.SelectedPrototypeKey = ""
	GameSession.IsPatched = false
	GameSession.LatestReport = nil
	GameSession.Phase = "DECISIONS"
	destroyMountedModels()
	SyncGameStateEvent:FireAllClients("DEEP_PIVOT_STARTED", GameSession.Budget, GameSession.PivotCount)
	startVoting()
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
		SyncGameStateEvent:FireClient(targetPlayer, "PROMPT_ITERATION", actions, GameSession.Budget, report and report.MustDeepPivot == true, VotingHandler.GetActiveToken())
	else
		SyncGameStateEvent:FireAllClients("PROMPT_ITERATION", actions, GameSession.Budget, report and report.MustDeepPivot == true, VotingHandler.GetActiveToken())
	end
end

local function applyIteration(iterationType: string)
	if GameSession.Phase ~= "ITERATION" then
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
		publishReport(evaluateCurrentSession())
	elseif iterationType == "DEEP_PIVOT" then
		if not report.CanDeepPivot then
			SyncGameStateEvent:FireAllClients("ITERATION_REJECTED", "DEEP_PIVOT_UNAVAILABLE")
			return
		end
		deepPivot()
	end
end

startIterationVoting = function()
	if GameSession.Phase ~= "ITERATION" or #Players:GetPlayers() == 0 or VotingHandler.IsActive() then
		return
	end
	local allowedActions = getIterationActionKeys()
	if #allowedActions == 0 then
		GameSession.Phase = "COMPLETE"
		return
	end
	local started = VotingHandler.StartIterationSession(
		DecisionTreeData.Constants.VoteDurationSeconds,
		allowedActions,
		function(winningAction: string?)
			if GameSession.Phase == "ITERATION" and winningAction then
				applyIteration(winningAction)
			end
		end
	)
	if started then
		sendIterationPrompt(nil)
	end
end

local function copyLedger(): { TransactionRecord }
	local copy: { TransactionRecord } = {}
	for _, transaction in ipairs(GameSession.Ledger) do
		table.insert(copy, table.clone(transaction))
	end
	return copy
end

local function handleIterationVote(player: Player, voteToken: any, iterationType: any)
	if GameSession.Phase ~= "ITERATION" or typeof(voteToken) ~= "number" or typeof(iterationType) ~= "string" then
		SyncGameStateEvent:FireClient(player, "VOTE_REJECTED", "ITERATION_VOTE_UNAVAILABLE")
		return
	end
	if VotingHandler.CastVote(player, "ITERATION", voteToken, iterationType) then
		SyncGameStateEvent:FireClient(player, "VOTE_ACCEPTED", "ITERATION", iterationType)
	else
		SyncGameStateEvent:FireClient(player, "VOTE_REJECTED", "STALE_OR_INVALID_ITERATION")
	end
end

StartSessionEvent.OnServerEvent:Connect(function(player: Player)
	if not isPlayerNearRani(player) then
		SyncGameStateEvent:FireClient(player, "START_REJECTED", "DEKATI_RANI")
		return
	end
	if GameSession.Phase ~= "WAITING_FOR_RANI" then
		SyncGameStateEvent:FireClient(player, "OPEN_GAME_UI")
		return
	end

	GameSession.Phase = "DECISIONS"
	SyncGameStateEvent:FireClient(player, "SESSION_STARTED")
	startVoting()
end)

SubmitVoteEvent.OnServerEvent:Connect(function(player: Player, nodeKey: any, voteToken: any, choiceKey: any)
	if typeof(nodeKey) ~= "string" or typeof(voteToken) ~= "number" or typeof(choiceKey) ~= "string" then
		SyncGameStateEvent:FireClient(player, "VOTE_REJECTED", "INVALID_PAYLOAD")
		return
	end
	if VotingHandler.CastVote(player, nodeKey, voteToken, choiceKey) then
		SyncGameStateEvent:FireClient(player, "VOTE_ACCEPTED", nodeKey, choiceKey)
	else
		SyncGameStateEvent:FireClient(player, "VOTE_REJECTED", "STALE_OR_INVALID_CHOICE")
	end
end)

TriggerIterationEvent.OnServerEvent:Connect(handleIterationVote)

GetGameStateFunction.OnServerInvoke = function(_player: Player)
	return {
		Phase = GameSession.Phase,
		CurrentStage = GameSession.CurrentStage,
		ActiveNodeKey = GameSession.ActiveNodeKey,
		VoteToken = VotingHandler.GetActiveToken(),
		AllowedChoiceKeys = if GameSession.Phase == "DECISIONS" then getNodeChoiceKeys(GameSession.ActiveNodeKey, GameSession.Budget) else {},
		AllowedIterationActions = if GameSession.Phase == "ITERATION" then getIterationActionKeys() else {},
		Budget = GameSession.Budget,
		PathChoices = table.clone(GameSession.PathChoices),
		SelectedPrototypeKey = GameSession.SelectedPrototypeKey,
		IsPatched = GameSession.IsPatched,
		PivotCount = GameSession.PivotCount,
		LatestReport = GameSession.LatestReport,
		Ledger = copyLedger(),
	}
end

Players.PlayerAdded:Connect(function(player: Player)
	task.defer(function()
		if GameSession.Phase == "DECISIONS" then
			if not VotingHandler.IsActive() then
				startVoting()
			else
				sendPrompt(player)
			end
		elseif GameSession.LatestReport then
			SyncGameStateEvent:FireClient(player, "SHOW_EVALUATION_REPORT", GameSession.LatestReport, GameSession.Budget)
			if GameSession.Phase == "ITERATION" then
				if not VotingHandler.IsActive() then
					startIterationVoting()
				else
					sendIterationPrompt(player)
				end
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(_player: Player)
	-- Pertahankan sesi tim ketika sebagian anggota keluar. Jika server kosong, jeda voting sampai ada pemain lagi.
	task.defer(function()
		if #Players:GetPlayers() == 0 then
			VotingHandler.CancelSession()
		end
	end)
end)

-- Voting sengaja tidak dimulai saat server boot. Pemain memulai sesi dengan berbicara kepada Rani.

