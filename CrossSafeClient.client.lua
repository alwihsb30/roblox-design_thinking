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

-- Quest HUD terpisah dari panel voting, jadi progres misi terlihat saat panel diskusi tertutup.
local questGui = Instance.new("ScreenGui")
questGui.Name = "CrossSafeQuestGui"
questGui.ResetOnSpawn = false
questGui.IgnoreGuiInset = false
questGui.DisplayOrder = 5
questGui.Parent = playerGui

local trackerFrame = Instance.new("Frame")
trackerFrame.Name = "QuestTracker"
trackerFrame.Position = UDim2.new(0.02, 0, 0.02, 0)
trackerFrame.Size = UDim2.new(0.88, 0, 0, 70)
trackerFrame.BackgroundColor3 = Color3.fromRGB(24, 35, 48)
trackerFrame.BackgroundTransparency = 0.16
trackerFrame.BorderSizePixel = 0
trackerFrame.Parent = questGui
local trackerConstraint = Instance.new("UISizeConstraint")
trackerConstraint.MinSize = Vector2.new(230, 70)
trackerConstraint.MaxSize = Vector2.new(380, 70)
trackerConstraint.Parent = trackerFrame
local trackerCorner = Instance.new("UICorner")
trackerCorner.CornerRadius = UDim.new(0, 10)
trackerCorner.Parent = trackerFrame

local trackerLabel = Instance.new("TextLabel")
trackerLabel.Name = "QuestText"
trackerLabel.Position = UDim2.fromOffset(12, 5)
trackerLabel.Size = UDim2.new(1, -24, 0, 26)
trackerLabel.BackgroundTransparency = 1
trackerLabel.Font = Enum.Font.GothamSemibold
trackerLabel.Text = "Misi: Cari 3 bukti bahaya [0/3]"
trackerLabel.TextColor3 = Color3.fromRGB(255, 232, 156)
trackerLabel.TextSize = 14
trackerLabel.TextWrapped = true
trackerLabel.TextXAlignment = Enum.TextXAlignment.Left
trackerLabel.Parent = trackerFrame

local trackerDetail = Instance.new("TextLabel")
trackerDetail.Name = "QuestDetail"
trackerDetail.Position = UDim2.fromOffset(12, 33)
trackerDetail.Size = UDim2.new(1, -24, 0, 32)
trackerDetail.BackgroundTransparency = 1
trackerDetail.Font = Enum.Font.Gotham
trackerDetail.Text = "Periksa tiga bukti fisik sebelum berbicara dengan Rani."
trackerDetail.TextColor3 = Color3.fromRGB(218, 229, 236)
trackerDetail.TextSize = 11
trackerDetail.TextWrapped = true
trackerDetail.TextXAlignment = Enum.TextXAlignment.Left
trackerDetail.TextYAlignment = Enum.TextYAlignment.Top
trackerDetail.Parent = trackerFrame

local notificationCard = Instance.new("Frame")
notificationCard.Name = "ClueNotification"
notificationCard.Position = UDim2.new(0.02, 0, 0.02, 88)
notificationCard.Size = UDim2.new(0.88, 0, 0, 108)
notificationCard.BackgroundColor3 = Color3.fromRGB(31, 76, 64)
notificationCard.BackgroundTransparency = 0.12
notificationCard.BorderSizePixel = 0
notificationCard.Visible = false
notificationCard.Parent = questGui
local notificationConstraint = Instance.new("UISizeConstraint")
notificationConstraint.MinSize = Vector2.new(230, 108)
notificationConstraint.MaxSize = Vector2.new(380, 108)
notificationConstraint.Parent = notificationCard
local notificationCorner = Instance.new("UICorner")
notificationCorner.CornerRadius = UDim.new(0, 10)
notificationCorner.Parent = notificationCard

local notificationTitle = Instance.new("TextLabel")
notificationTitle.Name = "Title"
notificationTitle.Position = UDim2.fromOffset(12, 8)
notificationTitle.Size = UDim2.new(1, -24, 0, 24)
notificationTitle.BackgroundTransparency = 1
notificationTitle.Font = Enum.Font.GothamBold
notificationTitle.TextColor3 = Color3.fromRGB(226, 255, 238)
notificationTitle.TextSize = 14
notificationTitle.TextXAlignment = Enum.TextXAlignment.Left
notificationTitle.TextWrapped = true
notificationTitle.Parent = notificationCard

local notificationDescription = Instance.new("TextLabel")
notificationDescription.Name = "Description"
notificationDescription.Position = UDim2.fromOffset(12, 36)
notificationDescription.Size = UDim2.new(1, -24, 1, -44)
notificationDescription.BackgroundTransparency = 1
notificationDescription.Font = Enum.Font.Gotham
notificationDescription.TextColor3 = Color3.fromRGB(239, 244, 248)
notificationDescription.TextSize = 12
notificationDescription.TextWrapped = true
notificationDescription.TextXAlignment = Enum.TextXAlignment.Left
notificationDescription.TextYAlignment = Enum.TextYAlignment.Top
notificationDescription.Parent = notificationCard

local questFound = 0
local questRequired = 3
local notificationVersion = 0

local function updateQuestProgress(found: number, required: number)
	questRequired = math.max(required, 1)
	questFound = math.clamp(found, 0, questRequired)
	trackerLabel.Text = string.format("Misi: Cari 3 bukti bahaya [%d/%d]", questFound, questRequired)
	trackerDetail.Text = "Rambu • marka • penerangan jalan"
	if questFound >= questRequired then
		trackerLabel.TextColor3 = Color3.fromRGB(160, 255, 192)
	else
		trackerLabel.TextColor3 = Color3.fromRGB(255, 232, 156)
	end
end

local function updateMissionState(title: string, detail: string, progress: number, required: number)
	questRequired = math.max(required, 1)
	questFound = math.clamp(progress, 0, questRequired)
	trackerLabel.Text = string.format("%s [%d/%d]", title, questFound, questRequired)
	trackerDetail.Text = detail
	if questFound >= questRequired then
		trackerLabel.TextColor3 = Color3.fromRGB(160, 255, 192)
	else
		trackerLabel.TextColor3 = Color3.fromRGB(255, 232, 156)
	end
end

local function showClueNotification(displayName: string, description: string, found: number, required: number)
	updateQuestProgress(found, required)
	notificationTitle.Text = "Bukti ditemukan: " .. displayName
	notificationDescription.Text = description
	notificationCard.Visible = true
	notificationVersion += 1
	local thisVersion = notificationVersion
	task.delay(4, function()
		if notificationVersion == thisVersion then
			notificationCard.Visible = false
		end
	end)
end

local function showWorldNotice(title: string, description: string)
	notificationTitle.Text = title
	notificationDescription.Text = description
	notificationCard.Visible = true
	notificationVersion += 1
	local thisVersion = notificationVersion
	task.delay(4, function()
		if notificationVersion == thisVersion then
			notificationCard.Visible = false
		end
	end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "CrossSafeGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Enabled = false
gui.DisplayOrder = 10
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(480, 420)
panel.BackgroundColor3 = Color3.fromRGB(24, 35, 48)
panel.BackgroundTransparency = 0.18
panel.BorderSizePixel = 0
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(220, 235, 245)
panelStroke.Transparency = 0.78
panelStroke.Thickness = 1
panelStroke.Parent = panel

local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MinSize = Vector2.new(240, 240)
panelConstraint.MaxSize = Vector2.new(520, 460)
panelConstraint.Parent = panel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingLeft = UDim.new(0, 16)
panelPadding.PaddingRight = UDim.new(0, 16)
panelPadding.PaddingTop = UDim.new(0, 12)
panelPadding.PaddingBottom = UDim.new(0, 12)
panelPadding.Parent = panel

local panelLayout = Instance.new("UIListLayout")
panelLayout.FillDirection = Enum.FillDirection.Vertical
panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
panelLayout.Padding = UDim.new(0, 6)
panelLayout.Parent = panel

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 34)
header.LayoutOrder = 1
header.Parent = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -48, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 19
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextYAlignment = Enum.TextYAlignment.Center
titleLabel.TextWrapped = true
titleLabel.Text = "CrossSafe | Design Thinking"
titleLabel.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 0, 0, 0)
closeButton.Size = UDim2.fromOffset(34, 32)
closeButton.BackgroundColor3 = Color3.fromRGB(76, 88, 101)
closeButton.BackgroundTransparency = 0.16
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 22
closeButton.Parent = header
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton
closeButton.Activated:Connect(function()
	gui.Enabled = false
end)

local function makeLabel(name: string, height: number, size: number, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(239, 244, 248)
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.LayoutOrder = order
	label.Parent = panel
	return label
end

local budgetLabel = makeLabel("Budget", 22, 15, 2)
budgetLabel.TextColor3 = Color3.fromRGB(255, 218, 105)

local stageLabel = makeLabel("Stage", 24, 15, 3)
stageLabel.Font = Enum.Font.GothamSemibold

local promptFrame = Instance.new("ScrollingFrame")
promptFrame.Name = "PromptScroll"
promptFrame.Size = UDim2.new(1, 0, 0, 112)
promptFrame.BackgroundColor3 = Color3.fromRGB(13, 22, 32)
promptFrame.BackgroundTransparency = 0.3
promptFrame.BorderSizePixel = 0
promptFrame.ScrollBarThickness = 4
promptFrame.ScrollBarImageTransparency = 0.45
promptFrame.ScrollingDirection = Enum.ScrollingDirection.Y
promptFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
promptFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
promptFrame.LayoutOrder = 4
promptFrame.Parent = panel
local promptCorner = Instance.new("UICorner")
promptCorner.CornerRadius = UDim.new(0, 8)
promptCorner.Parent = promptFrame
local promptPadding = Instance.new("UIPadding")
promptPadding.PaddingLeft = UDim.new(0, 10)
promptPadding.PaddingRight = UDim.new(0, 10)
promptPadding.PaddingTop = UDim.new(0, 8)
promptPadding.PaddingBottom = UDim.new(0, 8)
promptPadding.Parent = promptFrame

local promptLabel = Instance.new("TextLabel")
promptLabel.Name = "Prompt"
promptLabel.Position = UDim2.fromOffset(0, 0)
promptLabel.Size = UDim2.new(1, -4, 0, 0)
promptLabel.AutomaticSize = Enum.AutomaticSize.Y
promptLabel.BackgroundTransparency = 1
promptLabel.Font = Enum.Font.Gotham
promptLabel.TextColor3 = Color3.fromRGB(239, 244, 248)
promptLabel.TextSize = 16
promptLabel.TextXAlignment = Enum.TextXAlignment.Left
promptLabel.TextYAlignment = Enum.TextYAlignment.Top
promptLabel.TextWrapped = true
promptLabel.Parent = promptFrame

local statusLabel = makeLabel("Status", 34, 14, 5)
statusLabel.TextColor3 = Color3.fromRGB(170, 205, 225)

local choiceFrame = Instance.new("Frame")
choiceFrame.Name = "Choices"
choiceFrame.Size = UDim2.new(1, 0, 0, 140)
choiceFrame.BackgroundTransparency = 1
choiceFrame.ClipsDescendants = true
choiceFrame.LayoutOrder = 6
choiceFrame.Parent = panel

local choiceLayout = Instance.new("UIListLayout")
choiceLayout.FillDirection = Enum.FillDirection.Vertical
choiceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
choiceLayout.SortOrder = Enum.SortOrder.LayoutOrder
choiceLayout.Padding = UDim.new(0, 8)
choiceLayout.Parent = choiceFrame

local function makeChoiceButton(name: string, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 64)
	button.BackgroundColor3 = Color3.fromRGB(48, 104, 140)
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamSemibold
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 15
	button.TextWrapped = true
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.TextYAlignment = Enum.TextYAlignment.Center
	button.LayoutOrder = order
	button.Visible = false
	button.Parent = choiceFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = button
	return button
end

local choiceButtons = {
	makeChoiceButton("Choice1", 1),
	makeChoiceButton("Choice2", 2),
}
local startSessionButton = makeChoiceButton("StartSession", 1)
startSessionButton.Text = "Mulai diskusi bersama Rani"
startSessionButton.Visible = false

local function updateResponsiveLayout()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local landscape = viewport.X > viewport.Y
	local compact = viewport.X < 760 or viewport.Y < 640
	local veryShort = viewport.Y < 360
	local tiny = viewport.Y < 280

	local widthScale = if landscape then 0.78 else 0.92
	local heightScale = if landscape then 0.9 else 0.58
	local panelWidth = math.clamp(viewport.X * widthScale, 240, 520)
	local panelHeight = math.clamp(viewport.Y * heightScale, 220, 440)
	panel.Size = UDim2.fromOffset(math.floor(panelWidth), math.floor(panelHeight))

	local padding = if tiny then 6 elseif veryShort then 8 elseif compact then 10 else 16
	local gap = if tiny then 3 elseif compact then 4 else 6
	panelPadding.PaddingLeft = UDim.new(0, padding)
	panelPadding.PaddingRight = UDim.new(0, padding)
	panelPadding.PaddingTop = UDim.new(0, padding)
	panelPadding.PaddingBottom = UDim.new(0, padding)
	panelLayout.Padding = UDim.new(0, gap)
	choiceLayout.Padding = UDim.new(0, if compact then 5 else 8)

	local headerHeight = if tiny then 22 elseif veryShort then 24 elseif compact then 28 else 32
	local budgetHeight = if tiny then 14 elseif veryShort then 16 elseif compact then 18 else 20
	local stageHeight = if tiny then 16 elseif veryShort then 18 elseif compact then 20 else 22
	local promptHeight = if tiny then 32 elseif veryShort then 48 elseif compact then 72 else 108
	local statusHeight = if tiny then 18 elseif veryShort then 22 elseif compact then 28 else 32
	local choiceHeight = if tiny then 88 elseif veryShort then 100 elseif compact then 122 else 132
	local buttonHeight = if tiny then 40 elseif veryShort then 46 elseif compact then 56 else 60
	local buttonTextSize = if tiny then 11 elseif compact then 13 else 15

	header.Size = UDim2.new(1, 0, 0, headerHeight)
	titleLabel.Size = UDim2.new(1, -(if compact then 40 else 48), 1, 0)
	titleLabel.TextSize = if compact then 16 else 19
	closeButton.Size = UDim2.fromOffset(if compact then 30 else 34, if compact then 28 else 32)
	budgetLabel.Size = UDim2.new(1, 0, 0, budgetHeight)
	budgetLabel.TextSize = if compact then 12 else 15
	stageLabel.Size = UDim2.new(1, 0, 0, stageHeight)
	stageLabel.TextSize = if compact then 13 else 15
	promptFrame.Size = UDim2.new(1, 0, 0, promptHeight)
	promptLabel.TextSize = if tiny then 12 elseif compact then 14 else 16
	promptFrame.ScrollBarThickness = if compact then 3 else 4
	statusLabel.Size = UDim2.new(1, 0, 0, statusHeight)
	statusLabel.TextSize = if compact then 12 else 14
	choiceFrame.Size = UDim2.new(1, 0, 0, choiceHeight)
	for _, button in ipairs(choiceButtons) do
		button.Size = UDim2.new(1, 0, 0, buttonHeight)
		button.TextSize = buttonTextSize
	end
	startSessionButton.Size = UDim2.new(1, 0, 0, buttonHeight)
	startSessionButton.TextSize = buttonTextSize
end

local viewportConnection: RBXScriptConnection? = nil
local function bindViewportListener()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
	updateResponsiveLayout()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewportListener)
bindViewportListener()

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	trackerFrame.Visible = not gui.Enabled
end)

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

local function showRaniDialogue(found: number, required: number, canStart: boolean)
	gui.Enabled = true
	promptFrame.CanvasPosition = Vector2.zero
	activeNodeKey = nil
	activeVoteToken = nil
	clearChoices()
	titleLabel.Text = "CrossSafe | Bicara dengan Rani"
	budgetLabel.Text = ""
	stageLabel.Text = "Empathize — dengarkan pengguna"
	if canStart then
		promptLabel.Text = "Rani: Terima kasih sudah memeriksa titik-titik bahaya itu. Sekarang kita bisa mulai diskusi untuk mencari solusi yang aman."
		statusLabel.Text = "Semua bukti terkumpul. Pilih Mulai diskusi untuk membuka Tahap 1."
		startSessionButton.Visible = true
		startSessionButton.Active = true
	else
		promptLabel.Text = string.format(
			'Rani: "Tolong bantu aku cek dulu 3 titik bahaya di sekitar jalan ini ya kak! ([%d/%d] Bukti ditemukan)"',
			found,
			required
		)
		statusLabel.Text = "Cari dan periksa ketiga titik bukti di sekitar jalan sebelum memulai diskusi."
		startSessionButton.Visible = false
		startSessionButton.Active = false
	end
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
	gui.Enabled = true
	promptFrame.CanvasPosition = Vector2.zero
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
	gui.Enabled = true
	promptFrame.CanvasPosition = Vector2.zero
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
	gui.Enabled = true
	promptFrame.CanvasPosition = Vector2.zero
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
	if snapshot.Phase == "WAITING_FOR_RANI" or (snapshot.Phase == "DECISIONS" and snapshot.CurrentStage == 1) then
		updateQuestProgress(snapshot.ClueCount or 0, snapshot.CluesRequired or 3)
	elseif snapshot.MissionTitle then
		updateMissionState(snapshot.MissionTitle, snapshot.MissionDetail or "", snapshot.MissionProgress or 0, snapshot.MissionRequired or 1)
	end
	if snapshot.Phase == "MISSION" or snapshot.Phase == "SIMULATION" then
		gui.Enabled = false
		activeNodeKey = nil
		activeVoteToken = nil
		clearChoices()
		return
	elseif snapshot.Phase == "DECISIONS" then
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
		showRaniDialogue(args[1] or questFound, args[2] or questRequired, true)
	elseif action == "RANI_GATEKEEPER" then
		updateQuestProgress(args[1] or questFound, args[2] or questRequired)
		showRaniDialogue(questFound, questRequired, false)
	elseif action == "CLUE_PROGRESS" then
		updateQuestProgress(args[1], args[2])
	elseif action == "CLUE_FOUND" then
		showClueNotification(args[2], args[3], args[4], args[5])
	elseif action == "MISSION_UPDATE" then
		activeNodeKey = nil
		activeVoteToken = nil
		clearChoices()
		gui.Enabled = false
		updateMissionState(args[1], args[2], args[3], args[4])
	elseif action == "WORLD_DISCOVERY" or action == "ASSEMBLY_STARTED" or action == "MISSION_HINT" then
		showWorldNotice(args[1], args[2])
	elseif action == "MISSION_SETUP_MISSING" then
		gui.Enabled = false
		updateMissionState("Misi tertahan: setup Workspace", args[1], 0, 1)
	elseif action == "SIMULATION_BEAT" then
		if args[1] == "SAFETY_PASS" then
			trackerDetail.Text = "Lampu penyeberangan aktif; kendaraan berhenti di belakang garis stop."
		else
			trackerDetail.Text = "Rani terdistraksi; kendaraan membunyikan klakson dan ia mundur."
		end
	elseif action == "ASSEMBLY_COMPLETE" then
		showWorldNotice("Prototipe berhasil dirakit", args[1] or "Model tim siap diuji di zebra cross.")
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
		if questFound >= questRequired then
			startSessionButton.Visible = true
			startSessionButton.Active = true
		end
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

-- Minta progres awal dengan aman; RemoteFunction dapat belum siap pada frame pertama klien.
task.spawn(function()
	task.wait(0.5)
	for _ = 1, 5 do
		local ok, snapshot = pcall(function()
			return getGameState:InvokeServer()
		end)
		if ok and snapshot then
			updateQuestProgress(snapshot.ClueCount or 0, snapshot.CluesRequired or 3)
			return
		end
		task.wait(0.5)
	end
end)

