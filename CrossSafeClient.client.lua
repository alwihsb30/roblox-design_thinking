--!strict
-- Starter LocalScript untuk UI prototipe CrossSafe.
-- Letakkan di StarterGui. UI dibuat lewat kode agar alur voting dapat langsung dicoba.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local DecisionTreeData = require(ReplicatedStorage:WaitForChild("DecisionTreeData"))

local network = ReplicatedStorage:WaitForChild("GameNetwork")
local syncEvent = network:WaitForChild("SyncGameState") :: RemoteEvent
local submitVoteEvent = network:WaitForChild("SubmitVote") :: RemoteEvent
local iterationEvent = network:WaitForChild("TriggerIteration") :: RemoteEvent
local startSessionEvent = network:WaitForChild("StartSession") :: RemoteEvent
local getGameState = network:WaitForChild("GetGameState") :: RemoteFunction

type ButtonOption = {
	Id: string,
	Text: string,
}

type ChoiceHandler = (string, number) -> ()

local gui = Instance.new("ScreenGui")
gui.Name = "CrossSafeGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(600, 570)
panel.BackgroundColor3 = Color3.fromRGB(24, 35, 48)
panel.BorderSizePixel = 0
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingLeft = UDim.new(0, 20)
panelPadding.PaddingRight = UDim.new(0, 20)
panelPadding.Parent = panel

local function makeLabel(name: string, y: number, height: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromOffset(20, y)
	label.Size = UDim2.new(1, -40, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(239, 244, 248)
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = panel
	return label
end

local titleLabel = makeLabel("Title", 12, 32, 22)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Size = UDim2.new(1, -80, 0, 32)
titleLabel.Text = "CrossSafe | Design Thinking"

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Position = UDim2.new(1, -58, 0, 10)
closeButton.Size = UDim2.fromOffset(38, 34)
closeButton.BackgroundColor3 = Color3.fromRGB(76, 88, 101)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 22
closeButton.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton
closeButton.Activated:Connect(function()
	gui.Enabled = false
end)

local budgetLabel = makeLabel("Budget", 46, 25, 16)
budgetLabel.TextColor3 = Color3.fromRGB(255, 218, 105)

local stageLabel = makeLabel("Stage", 74, 26, 16)
stageLabel.Font = Enum.Font.GothamSemibold

local promptLabel = makeLabel("Prompt", 104, 205, 16)
promptLabel.TextYAlignment = Enum.TextYAlignment.Top

local statusLabel = makeLabel("Status", 312, 34, 14)
statusLabel.TextColor3 = Color3.fromRGB(170, 205, 225)

local function makeChoiceButton(name: string, y: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = UDim2.fromOffset(20, y)
	button.Size = UDim2.new(1, -40, 0, 78)
	button.BackgroundColor3 = Color3.fromRGB(48, 104, 140)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamSemibold
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 16
	button.TextWrapped = true
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.TextYAlignment = Enum.TextYAlignment.Center
	button.Visible = false
	button.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = button
	return button
end

local choiceButtons = {
	makeChoiceButton("Choice1", 354),
	makeChoiceButton("Choice2", 442),
}
local startSessionButton = makeChoiceButton("StartSession", 354)
startSessionButton.Text = "Mulai diskusi bersama Rani"
startSessionButton.Visible = false

local clickHandlers: { [number]: (() -> ()) } = {}
for index, button in ipairs(choiceButtons) do
	local buttonIndex = index
	button.Activated:Connect(function()
		local handler = clickHandlers[buttonIndex]
		if handler then
			handler()
		end
	end)
end

local activeNodeKey: string? = nil
local activeVoteToken: number? = nil

local function clearChoices()
	for index, button in ipairs(choiceButtons) do
		button.Visible = false
		button.Active = false
		clickHandlers[index] = nil
	end
	startSessionButton.Visible = false
	startSessionButton.Active = false
end

local function showRaniDialogue()
	gui.Enabled = true
	activeNodeKey = nil
	activeVoteToken = nil
	clearChoices()
	titleLabel.Text = "CrossSafe | Bicara dengan Rani"
	budgetLabel.Text = ""
	stageLabel.Text = "Empathize — dengarkan pengguna"
	promptLabel.Text = "Rani: Aku takut terjebak di tengah jalan saat menyeberang empat lajur. Aku sering tidak yakin kapan kendaraan akan berhenti. Bisa bantu tim mencari solusi yang aman?"
	statusLabel.Text = "Dekati Rani dan pilih Mulai diskusi untuk memulai sesi tim."
	startSessionButton.Visible = true
	startSessionButton.Active = true
end

startSessionButton.Activated:Connect(function()
	if not startSessionButton.Active then
		return
	end
	startSessionButton.Active = false
	startSessionButton.Visible = false
	statusLabel.Text = "Memulai sesi bersama Rani..."
	startSessionEvent:FireServer()
end)

local function formatRupiah(amount: number): string
	local remaining = tostring(math.floor(amount))
	local groups: { string } = {}
	while #remaining > 3 do
		table.insert(groups, 1, string.sub(remaining, -3))
		remaining = string.sub(remaining, 1, -4)
	end
	table.insert(groups, 1, remaining)
	return "Rp " .. table.concat(groups, ".")
end

local function setBudget(amount: number)
	budgetLabel.Text = "Modal tim: " .. formatRupiah(amount)
end

local function renderOptions(options: { ButtonOption }, voteToken: number?, handler: ChoiceHandler)
	clearChoices()
	if voteToken == nil then
		statusLabel.Text = "Menunggu server membuka voting..."
		return
	end
	activeVoteToken = voteToken
	for index, option in ipairs(options) do
		local button = choiceButtons[index]
		if not button then
			break
		end
		local optionId = option.Id
		button.Text = option.Text
		button.Visible = true
		button.Active = true
		clickHandlers[index] = function()
			if activeVoteToken ~= voteToken then
				return
			end
			clearChoices()
			statusLabel.Text = "Suara tercatat. Menunggu keputusan tim..."
			handler(optionId, voteToken)
		end
	end
end

local function renderNode(nodeKey: string, allowedChoiceKeys: { string }, budget: number, stage: number, voteToken: number?)
	local node = DecisionTreeData.Nodes[nodeKey]
	if not node then
		statusLabel.Text = "Node tidak ditemukan: " .. nodeKey
		clearChoices()
		return
	end
	activeNodeKey = nodeKey
	activeVoteToken = voteToken
	setBudget(budget)
	stageLabel.Text = string.format("Tahap %d | %s", stage, ({ "Empathize", "Define", "Ideate", "Prototype" })[stage] or "CrossSafe")
	promptLabel.Text = node.Prompt
	local options: { ButtonOption } = {}
	for _, choiceKey in ipairs(allowedChoiceKeys) do
		local choice = node.Choices[choiceKey]
		if choice then
			table.insert(options, { Id = choiceKey, Text = choice.Text })
		end
	end
	renderOptions(options, voteToken, function(choiceKey: string, token: number)
		submitVoteEvent:FireServer(nodeKey, token, choiceKey)
	end)
	if voteToken then
		statusLabel.Text = string.format("Voting aktif — diskusi tim dan pilih opsi (%d detik).", DecisionTreeData.Constants.VoteDurationSeconds)
	end
end

local function renderReport(report: any, budget: number)
	activeNodeKey = nil
	activeVoteToken = nil
	clearChoices()
	setBudget(budget)
	stageLabel.Text = string.format("Laporan desain | %s", report.SafetyStatus)
	local stars = string.rep("★", report.StarRating) .. string.rep("☆", 5 - report.StarRating)
	promptLabel.Text = string.format(
		"%s\nSkor Design Thinking: %d/100 | %s\nKebutuhan: %s\nCatatan: %s\nRani: %s",
		report.VerdictTitle,
		report.ScoreDT,
		stars,
		report.UserNeedAddressed,
		report.CriticalRiskNote,
		report.RaniStatement
	)
	if report.MustDeepPivot then
		statusLabel.Text = "Safety Gate gagal: tim perlu memilih Deep Pivot."
	elseif report.PivotBlockedByBudget then
		statusLabel.Text = "Saldo menghalangi iterasi berikutnya. Laporan ini mengakhiri sesi."
	elseif report.CanQuickPatch or report.CanDeepPivot then
		statusLabel.Text = "Pilih langkah iterasi bersama tim."
	else
		statusLabel.Text = "Sesi selesai. Diskusikan apa yang dipelajari dari umpan balik Rani."
	end
end

local function renderIteration(actions: { string }, budget: number, mustDeepPivot: boolean, voteToken: number?)
	activeNodeKey = nil
	setBudget(budget)
	stageLabel.Text = "Tahap Iterasi | Voting Tim"
	promptLabel.Text = if mustDeepPivot
		then "Desain belum lolos Safety Gate. Tim perlu memilih Deep Pivot untuk merancang ulang jalur solusi."
		else "Pilih cara menanggapi umpan balik Rani. Quick Patch memperbaiki prototipe; Deep Pivot menjual prototipe dengan salvage 50%."
	local options: { ButtonOption } = {}
	for _, action in ipairs(actions) do
		if action == "QUICK_PATCH" then
			table.insert(options, { Id = action, Text = "QUICK PATCH — tambah mitigasi risiko (Rp2.000.000)" })
		elseif action == "DEEP_PIVOT" then
			table.insert(options, { Id = action, Text = "DEEP PIVOT — salvage 50% dan kembali ke Tahap 2" })
		end
	end
	renderOptions(options, voteToken, function(action: string, token: number)
		iterationEvent:FireServer(token, action)
	end)
end

local function renderSnapshot(snapshot: any)
	setBudget(snapshot.Budget)
	if snapshot.Phase == "DECISIONS" then
		renderNode(snapshot.ActiveNodeKey, snapshot.AllowedChoiceKeys, snapshot.Budget, snapshot.CurrentStage, snapshot.VoteToken)
	elseif snapshot.LatestReport then
		renderReport(snapshot.LatestReport, snapshot.Budget)
		if snapshot.Phase == "ITERATION" then
			renderIteration(
				snapshot.AllowedIterationActions,
				snapshot.Budget,
				snapshot.LatestReport.MustDeepPivot,
				snapshot.VoteToken
			)
		end
	end
end

local function refreshFromServer()
	local ok, snapshot = pcall(function()
		return getGameState:InvokeServer()
	end)
	if ok and snapshot then
		renderSnapshot(snapshot)
	else
		statusLabel.Text = "Belum dapat mengambil status sesi. Coba lagi sebentar."
	end
end

syncEvent.OnClientEvent:Connect(function(action: string, ...: any)
	local args = { ... }
	if action == "RANI_DIALOGUE" then
		showRaniDialogue()
	elseif action == "OPEN_GAME_UI" then
		gui.Enabled = true
		titleLabel.Text = "CrossSafe | Design Thinking"
		refreshFromServer()
	elseif action == "SESSION_STARTED" then
		gui.Enabled = true
		titleLabel.Text = "CrossSafe | Design Thinking"
		startSessionButton.Visible = false
		statusLabel.Text = "Sesi dimulai. Dengarkan kebutuhan Rani dan diskusikan pilihan bersama tim."
	elseif action == "START_REJECTED" then
		statusLabel.Text = "Untuk memulai, dekati Rani lalu pilih tombol mulai sekali lagi."
		startSessionButton.Visible = true
		startSessionButton.Active = true
	elseif action == "PROMPT_NODE" then
		renderNode(args[1], args[2], args[3], args[4], args[5])
	elseif action == "SHOW_EVALUATION_REPORT" then
		renderReport(args[1], args[2])
	elseif action == "PROMPT_ITERATION" then
		renderIteration(args[1], args[2], args[3], args[4])
	elseif action == "VOTE_REJECTED" then
		statusLabel.Text = "Voting ditolak atau sudah kedaluwarsa. Memuat status terbaru..."
		task.defer(refreshFromServer)
	elseif action == "BUDGET_REJECTED" then
		statusLabel.Text = string.format("Saldo %s tidak cukup untuk pilihan %s.", formatRupiah(args[1]), formatRupiah(args[2]))
		task.defer(refreshFromServer)
	elseif action == "ITERATION_REJECTED" then
		statusLabel.Text = "Pilihan iterasi tidak tersedia. Memuat status terbaru..."
		task.defer(refreshFromServer)
	elseif action == "DEEP_PIVOT_STARTED" then
		setBudget(args[1])
		statusLabel.Text = string.format("Deep Pivot ke-%d dimulai. Tim kembali ke Define.", args[2])
	elseif action == "NO_AFFORDABLE_PROTOTYPE" then
		statusLabel.Text = "Saldo tidak cukup untuk prototipe yang tersedia. Periksa jalur iterasi."
	end
end)

