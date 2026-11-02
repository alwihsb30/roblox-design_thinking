--!strict
-- Starter LocalScript untuk UI prototipe CrossSafe.
-- Letakkan di StarterGui. UI dibuat lewat kode agar alur voting dapat langsung dicoba.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [UPGRADE] TweenService untuk animasi progress bar metrik diagnostik
local TweenService = game:GetService("TweenService")

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
trackerFrame.Size = UDim2.new(0.92, 0, 0, 78)
trackerFrame.BackgroundColor3 = Color3.fromRGB(24, 35, 48)
trackerFrame.BorderSizePixel = 0
trackerFrame.Parent = questGui
local trackerConstraint = Instance.new("UISizeConstraint")
trackerConstraint.MinSize = Vector2.new(250, 78)
trackerConstraint.MaxSize = Vector2.new(420, 78)
trackerConstraint.Parent = trackerFrame
local trackerCorner = Instance.new("UICorner")
trackerCorner.CornerRadius = UDim.new(0, 10)
trackerCorner.Parent = trackerFrame

local trackerLabel = Instance.new("TextLabel")
trackerLabel.Name = "QuestText"
trackerLabel.Position = UDim2.fromOffset(14, 6)
trackerLabel.Size = UDim2.new(1, -28, 0, 30)
trackerLabel.BackgroundTransparency = 1
trackerLabel.Font = Enum.Font.GothamSemibold
trackerLabel.Text = "Misi: Selidiki Titik Bahaya Jalan Raya [0/3]"
trackerLabel.TextColor3 = Color3.fromRGB(255, 232, 156)
trackerLabel.TextSize = 15
trackerLabel.TextWrapped = true
trackerLabel.TextXAlignment = Enum.TextXAlignment.Left
trackerLabel.Parent = trackerFrame

local trackerDetail = Instance.new("TextLabel")
trackerDetail.Name = "QuestDetail"
trackerDetail.Position = UDim2.fromOffset(14, 36)
trackerDetail.Size = UDim2.new(1, -28, 0, 36)
trackerDetail.BackgroundTransparency = 1
trackerDetail.Font = Enum.Font.Gotham
trackerDetail.Text = "Periksa tiga bukti fisik sebelum berbicara dengan Rani."
trackerDetail.TextColor3 = Color3.fromRGB(218, 229, 236)
trackerDetail.TextSize = 12
trackerDetail.TextWrapped = true
trackerDetail.TextXAlignment = Enum.TextXAlignment.Left
trackerDetail.TextYAlignment = Enum.TextYAlignment.Top
trackerDetail.Parent = trackerFrame

local notificationCard = Instance.new("Frame")
notificationCard.Name = "ClueNotification"
notificationCard.Position = UDim2.new(0.02, 0, 0.02, 88)
notificationCard.Size = UDim2.new(0.92, 0, 0, 132)
notificationCard.BackgroundColor3 = Color3.fromRGB(31, 76, 64)
notificationCard.BorderSizePixel = 0
notificationCard.Visible = false
notificationCard.Parent = questGui
local notificationConstraint = Instance.new("UISizeConstraint")
notificationConstraint.MinSize = Vector2.new(250, 132)
notificationConstraint.MaxSize = Vector2.new(420, 132)
notificationConstraint.Parent = notificationCard
local notificationCorner = Instance.new("UICorner")
notificationCorner.CornerRadius = UDim.new(0, 10)
notificationCorner.Parent = notificationCard

local notificationTitle = Instance.new("TextLabel")
notificationTitle.Name = "Title"
notificationTitle.Position = UDim2.fromOffset(14, 10)
notificationTitle.Size = UDim2.new(1, -28, 0, 28)
notificationTitle.BackgroundTransparency = 1
notificationTitle.Font = Enum.Font.GothamBold
notificationTitle.TextColor3 = Color3.fromRGB(226, 255, 238)
notificationTitle.TextSize = 16
notificationTitle.TextXAlignment = Enum.TextXAlignment.Left
notificationTitle.TextWrapped = true
notificationTitle.Parent = notificationCard

local notificationDescription = Instance.new("TextLabel")
notificationDescription.Name = "Description"
notificationDescription.Position = UDim2.fromOffset(14, 40)
notificationDescription.Size = UDim2.new(1, -28, 1, -50)
notificationDescription.BackgroundTransparency = 1
notificationDescription.Font = Enum.Font.Gotham
notificationDescription.TextColor3 = Color3.fromRGB(239, 244, 248)
notificationDescription.TextSize = 14
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
	trackerLabel.Text = string.format("Misi: Selidiki Titik Bahaya Jalan Raya [%d/%d]", questFound, questRequired)
	trackerDetail.Text = "Periksa bukti rambu, marka zebra cross, dan penerangan jalan."
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
-- [UPGRADE] Ukuran panel disesuaikan untuk kenyamanan tampilan rapor dan tombol
panel.Size = UDim2.fromOffset(620, 590)
panel.BackgroundColor3 = Color3.fromRGB(24, 35, 48)
panel.BorderSizePixel = 0
panel.Parent = gui

local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MinSize = Vector2.new(500, 520)
panelConstraint.MaxSize = Vector2.new(680, 640)
panelConstraint.Parent = panel

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

local budgetLabel = makeLabel("Budget", 44, 24, 16)
budgetLabel.TextColor3 = Color3.fromRGB(255, 218, 105)

local stageLabel = makeLabel("Stage", 68, 24, 16)
stageLabel.Font = Enum.Font.GothamSemibold

local promptLabel = makeLabel("Prompt", 96, 240, 15)
promptLabel.TextYAlignment = Enum.TextYAlignment.Top

-- [UPGRADE] ScrollingFrame untuk kontainer rapor evaluasi dan diagnostik multidimensi
local reportScrollFrame = Instance.new("ScrollingFrame")
reportScrollFrame.Name = "ReportScrollFrame"
reportScrollFrame.Position = UDim2.fromOffset(20, 96)
reportScrollFrame.Size = UDim2.new(1, -40, 0, 240)
reportScrollFrame.BackgroundTransparency = 1
reportScrollFrame.BorderSizePixel = 0
reportScrollFrame.ScrollBarThickness = 6
reportScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 110, 145)
reportScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
reportScrollFrame.CanvasSize = UDim2.fromScale(0, 0)
reportScrollFrame.Visible = false
reportScrollFrame.Parent = panel

local reportListLayout = Instance.new("UIListLayout")
reportListLayout.Padding = UDim.new(0, 10)
reportListLayout.SortOrder = Enum.SortOrder.LayoutOrder
reportListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
reportListLayout.Parent = reportScrollFrame

local reportPadding = Instance.new("UIPadding")
reportPadding.PaddingRight = UDim.new(0, 8)
reportPadding.PaddingLeft = UDim.new(0, 2)
reportPadding.PaddingTop = UDim.new(0, 2)
reportPadding.PaddingBottom = UDim.new(0, 10)
reportPadding.Parent = reportScrollFrame

local statusLabel = makeLabel("Status", 344, 30, 14)
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
	makeChoiceButton("Choice1", 380),
	makeChoiceButton("Choice2", 466),
}
local startSessionButton = makeChoiceButton("StartSession", 380)
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

local function showRaniDialogue(found: number, required: number, canStart: boolean)
	gui.Enabled = true
	activeNodeKey = nil
	activeVoteToken = nil
	clearChoices()
	-- [UPGRADE] Pastikan ScrollFrame non-aktif saat berdialog dengan Rani
	reportScrollFrame.Visible = false
	promptLabel.Visible = true
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
	-- [UPGRADE] Pastikan ScrollFrame non-aktif saat voting pertanyaan node
	reportScrollFrame.Visible = false
	promptLabel.Visible = true
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

-- [UPGRADE] Fungsi penentuan warna dinamis metrik diagnostik
local function getMetricColor(metricKey: string, value: number): Color3
	if metricKey == "SafetyIndex" then
		if value >= 80 then
			return Color3.fromRGB(58, 196, 125) -- Hijau
		elseif value >= 50 then
			return Color3.fromRGB(245, 185, 66)  -- Kuning
		else
			return Color3.fromRGB(235, 87, 87)   -- Merah
		end
	elseif metricKey == "TrafficCongestion" then
		if value <= 20 then
			return Color3.fromRGB(58, 196, 125) -- Hijau (Lancar)
		elseif value <= 50 then
			return Color3.fromRGB(245, 185, 66)  -- Kuning (Sedang)
		else
			return Color3.fromRGB(235, 87, 87)   -- Merah (Macet parah)
		end
	elseif metricKey == "InclusivityScore" then
		if value >= 80 then
			return Color3.fromRGB(58, 196, 125) -- Hijau (Ramah difabel/lansia)
		elseif value >= 45 then
			return Color3.fromRGB(245, 185, 66)  -- Kuning
		else
			return Color3.fromRGB(235, 87, 87)   -- Merah (Tidak aksesibel)
		end
	elseif metricKey == "BudgetEfficiency" then
		if value >= 50 then
			return Color3.fromRGB(58, 196, 125) -- Hijau
		elseif value >= 20 then
			return Color3.fromRGB(245, 185, 66)  -- Kuning
		else
			return Color3.fromRGB(235, 87, 87)   -- Merah
		end
	end
	return Color3.fromRGB(58, 196, 125)
end

-- [UPGRADE] Pembersih kontainer laporan evaluasi
local function clearReportView()
	for _, child in ipairs(reportScrollFrame:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- [UPGRADE] Membangun tampilan visual laporan dan kartu diagnostik multidimensi
local function populateReportView(report: any, budget: number)
	clearReportView()
	reportScrollFrame.CanvasPosition = Vector2.new(0, 0)

	-- 1. Kartu Ringkasan Hasil & Putusan (LayoutOrder = 1)
	local verdictCard = Instance.new("Frame")
	verdictCard.Name = "VerdictCard"
	verdictCard.Size = UDim2.new(1, 0, 0, 0)
	verdictCard.AutomaticSize = Enum.AutomaticSize.Y
	verdictCard.BackgroundColor3 = Color3.fromRGB(30, 44, 60)
	verdictCard.BorderSizePixel = 0
	verdictCard.LayoutOrder = 1
	verdictCard.Parent = reportScrollFrame

	local verdictCorner = Instance.new("UICorner")
	verdictCorner.CornerRadius = UDim.new(0, 10)
	verdictCorner.Parent = verdictCard

	local verdictStroke = Instance.new("UIStroke")
	verdictStroke.Color = Color3.fromRGB(50, 72, 96)
	verdictStroke.Thickness = 1
	verdictStroke.Parent = verdictCard

	local verdictLayout = Instance.new("UIListLayout")
	verdictLayout.Padding = UDim.new(0, 6)
	verdictLayout.SortOrder = Enum.SortOrder.LayoutOrder
	verdictLayout.Parent = verdictCard

	local verdictPadding = Instance.new("UIPadding")
	verdictPadding.PaddingLeft = UDim.new(0, 14)
	verdictPadding.PaddingRight = UDim.new(0, 14)
	verdictPadding.PaddingTop = UDim.new(0, 12)
	verdictPadding.PaddingBottom = UDim.new(0, 12)
	verdictPadding.Parent = verdictCard

	-- Judul Putusan
	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "VerdictTitle"
	titleLbl.Size = UDim2.new(1, 0, 0, 24)
	titleLbl.AutomaticSize = Enum.AutomaticSize.Y
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.Text = report.VerdictTitle or "LAPORAN EVALUASI DESAIN"
	titleLbl.TextColor3 = Color3.fromRGB(255, 235, 160)
	titleLbl.TextSize = 16
	titleLbl.TextWrapped = true
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.LayoutOrder = 1
	titleLbl.Parent = verdictCard

	-- Baris Skor & Bintang
	local stars = string.rep("★", report.StarRating or 1) .. string.rep("☆", 5 - (report.StarRating or 1))
	local statusColor = if report.SafetyStatus == "PASS"
		then Color3.fromRGB(58, 196, 125)
		elseif report.SafetyStatus == "CONDITIONAL"
		then Color3.fromRGB(245, 185, 66)
		else Color3.fromRGB(235, 87, 87)

	local scoreLbl = Instance.new("TextLabel")
	scoreLbl.Name = "ScoreLine"
	scoreLbl.Size = UDim2.new(1, 0, 0, 20)
	scoreLbl.BackgroundTransparency = 1
	scoreLbl.Font = Enum.Font.GothamBold
	scoreLbl.Text = string.format("Skor DT: %d/100  |  %s  [%s]", report.ScoreDT or 0, stars, report.SafetyStatus or "EVAL")
	scoreLbl.TextColor3 = statusColor
	scoreLbl.TextSize = 14
	scoreLbl.TextXAlignment = Enum.TextXAlignment.Left
	scoreLbl.LayoutOrder = 2
	scoreLbl.Parent = verdictCard

	-- Kebutuhan Pengguna
	local needLbl = Instance.new("TextLabel")
	needLbl.Name = "UserNeed"
	needLbl.Size = UDim2.new(1, 0, 0, 18)
	needLbl.AutomaticSize = Enum.AutomaticSize.Y
	needLbl.BackgroundTransparency = 1
	needLbl.Font = Enum.Font.Gotham
	needLbl.Text = "🎯 Kebutuhan: " .. (report.UserNeedAddressed or "-")
	needLbl.TextColor3 = Color3.fromRGB(220, 235, 245)
	needLbl.TextSize = 12
	needLbl.TextWrapped = true
	needLbl.TextXAlignment = Enum.TextXAlignment.Left
	needLbl.LayoutOrder = 3
	needLbl.Parent = verdictCard

	-- Catatan Risiko
	local riskLbl = Instance.new("TextLabel")
	riskLbl.Name = "RiskNote"
	riskLbl.Size = UDim2.new(1, 0, 0, 18)
	riskLbl.AutomaticSize = Enum.AutomaticSize.Y
	riskLbl.BackgroundTransparency = 1
	riskLbl.Font = Enum.Font.Gotham
	riskLbl.Text = "⚠️ Evaluasi: " .. (report.CriticalRiskNote or "-")
	riskLbl.TextColor3 = Color3.fromRGB(255, 205, 175)
	riskLbl.TextSize = 12
	riskLbl.TextWrapped = true
	riskLbl.TextXAlignment = Enum.TextXAlignment.Left
	riskLbl.LayoutOrder = 4
	riskLbl.Parent = verdictCard

	-- Kutipan Rani
	local quoteFrame = Instance.new("Frame")
	quoteFrame.Name = "RaniQuote"
	quoteFrame.Size = UDim2.new(1, 0, 0, 0)
	quoteFrame.AutomaticSize = Enum.AutomaticSize.Y
	quoteFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 42)
	quoteFrame.BorderSizePixel = 0
	quoteFrame.LayoutOrder = 5
	quoteFrame.Parent = verdictCard

	local quoteCorner = Instance.new("UICorner")
	quoteCorner.CornerRadius = UDim.new(0, 6)
	quoteCorner.Parent = quoteFrame

	local quotePadding = Instance.new("UIPadding")
	quotePadding.PaddingLeft = UDim.new(0, 10)
	quotePadding.PaddingRight = UDim.new(0, 10)
	quotePadding.PaddingTop = UDim.new(0, 6)
	quotePadding.PaddingBottom = UDim.new(0, 6)
	quotePadding.Parent = quoteFrame

	local quoteLbl = Instance.new("TextLabel")
	quoteLbl.Name = "QuoteText"
	quoteLbl.Size = UDim2.new(1, 0, 0, 16)
	quoteLbl.AutomaticSize = Enum.AutomaticSize.Y
	quoteLbl.BackgroundTransparency = 1
	quoteLbl.Font = Enum.Font.GothamItalic
	quoteLbl.Text = string.format('💬 Rani: "%s"', report.RaniStatement or "")
	quoteLbl.TextColor3 = Color3.fromRGB(195, 235, 255)
	quoteLbl.TextSize = 12
	quoteLbl.TextWrapped = true
	quoteLbl.TextXAlignment = Enum.TextXAlignment.Left
	quoteLbl.Parent = quoteFrame

	-- 2. Header Bagian Diagnostik Multidimensi (LayoutOrder = 2)
	local diagHeader = Instance.new("TextLabel")
	diagHeader.Name = "DiagnosticsHeader"
	diagHeader.Size = UDim2.new(1, 0, 0, 26)
	diagHeader.BackgroundTransparency = 1
	diagHeader.Font = Enum.Font.GothamBold
	diagHeader.Text = "📊 DIAGNOSTIK MULTIDIMENSI"
	diagHeader.TextColor3 = Color3.fromRGB(130, 210, 255)
	diagHeader.TextSize = 13
	diagHeader.TextXAlignment = Enum.TextXAlignment.Left
	diagHeader.LayoutOrder = 2
	diagHeader.Parent = reportScrollFrame

	-- 3. Pembuatan 4 Kartu Metrik dengan Animasi Progress Bar (LayoutOrder 3 - 6)
	local multiScores = report.MultidimensionalScores or {
		SafetyIndex = if report.SafetyStatus == "PASS" then 85 elseif report.SafetyStatus == "CONDITIONAL" then 65 else 30,
		TrafficCongestion = 30,
		InclusivityScore = 50,
		BudgetEfficiency = math.clamp(math.round((budget / DecisionTreeData.Constants.InitialBudget) * 100), 0, 100),
	}
	local dimensionNotes = report.DimensionNotes or {
		SafetyNote = report.CriticalRiskNote or "",
		TrafficNote = "Hambatan lalu lintas terkendali.",
		InclusivityNote = "Aksesibilitas desain sekolah.",
		BudgetNote = string.format("Sisa modal: %s.", formatRupiah(budget)),
	}

	local metricConfigs = {
		{
			Key = "SafetyIndex",
			Title = "Safety Index (Proteksi Pejalan Kaki)",
			Value = multiScores.SafetyIndex,
			Note = dimensionNotes.SafetyNote or "",
			Order = 3,
		},
		{
			Key = "TrafficCongestion",
			Title = "Traffic Congestion (Hambatan Kendaraan)",
			Value = multiScores.TrafficCongestion,
			Note = dimensionNotes.TrafficNote or "",
			Order = 4,
		},
		{
			Key = "InclusivityScore",
			Title = "Inclusivity Score (Ramah Difabel & Lansia)",
			Value = multiScores.InclusivityScore,
			Note = dimensionNotes.InclusivityNote or "",
			Order = 5,
		},
		{
			Key = "BudgetEfficiency",
			Title = "Budget Efficiency (Efisiensi Modal)",
			Value = multiScores.BudgetEfficiency,
			Note = dimensionNotes.BudgetNote or "",
			Order = 6,
		},
	}

	for _, cfg in ipairs(metricConfigs) do
		local metricCard = Instance.new("Frame")
		metricCard.Name = "Card_" .. cfg.Key
		metricCard.Size = UDim2.new(1, 0, 0, 0)
		metricCard.AutomaticSize = Enum.AutomaticSize.Y
		metricCard.BackgroundColor3 = Color3.fromRGB(28, 40, 54)
		metricCard.BorderSizePixel = 0
		metricCard.LayoutOrder = cfg.Order
		metricCard.Parent = reportScrollFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = metricCard

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = Color3.fromRGB(44, 62, 82)
		cardStroke.Thickness = 1
		cardStroke.Parent = metricCard

		local cardLayout = Instance.new("UIListLayout")
		cardLayout.Padding = UDim.new(0, 5)
		cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
		cardLayout.Parent = metricCard

		local cardPadding = Instance.new("UIPadding")
		cardPadding.PaddingLeft = UDim.new(0, 12)
		cardPadding.PaddingRight = UDim.new(0, 12)
		cardPadding.PaddingTop = UDim.new(0, 9)
		cardPadding.PaddingBottom = UDim.new(0, 9)
		cardPadding.Parent = metricCard

		-- Baris Judul & Persentase
		local topRow = Instance.new("Frame")
		topRow.Name = "TopRow"
		topRow.Size = UDim2.new(1, 0, 0, 18)
		topRow.BackgroundTransparency = 1
		topRow.LayoutOrder = 1
		topRow.Parent = metricCard

		local metricTitle = Instance.new("TextLabel")
		metricTitle.Name = "Title"
		metricTitle.Size = UDim2.new(1, -60, 1, 0)
		metricTitle.BackgroundTransparency = 1
		metricTitle.Font = Enum.Font.GothamSemibold
		metricTitle.Text = cfg.Title
		metricTitle.TextColor3 = Color3.fromRGB(240, 245, 250)
		metricTitle.TextSize = 12
		metricTitle.TextXAlignment = Enum.TextXAlignment.Left
		metricTitle.Parent = topRow

		local metricPercent = Instance.new("TextLabel")
		metricPercent.Name = "Percent"
		metricPercent.Size = UDim2.new(0, 60, 1, 0)
		metricPercent.Position = UDim2.new(1, -60, 0, 0)
		metricPercent.BackgroundTransparency = 1
		metricPercent.Font = Enum.Font.GothamBold
		metricPercent.Text = string.format("%d%%", cfg.Value)
		local metricColor = getMetricColor(cfg.Key, cfg.Value)
		metricPercent.TextColor3 = metricColor
		metricPercent.TextSize = 13
		metricPercent.TextXAlignment = Enum.TextXAlignment.Right
		metricPercent.Parent = topRow

		-- Progress Bar Track
		local barTrack = Instance.new("Frame")
		barTrack.Name = "BarTrack"
		barTrack.Size = UDim2.new(1, 0, 0, 10)
		barTrack.BackgroundColor3 = Color3.fromRGB(16, 23, 32)
		barTrack.BorderSizePixel = 0
		barTrack.LayoutOrder = 2
		barTrack.Parent = metricCard

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(0, 5)
		trackCorner.Parent = barTrack

		-- Fill Bar dengan Animasi Tweening
		local fillBar = Instance.new("Frame")
		fillBar.Name = "FillBar"
		fillBar.Size = UDim2.new(0, 0, 1, 0) -- Mulai dari 0% untuk efek animasi
		fillBar.BackgroundColor3 = metricColor
		fillBar.BorderSizePixel = 0
		fillBar.Parent = barTrack

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 5)
		fillCorner.Parent = fillBar

		-- Jalankan animasi pengisian bar
		task.defer(function()
			task.wait(0.08 * (cfg.Order - 2))
			local targetFraction = math.clamp(cfg.Value, 0, 100) / 100
			local tween = TweenService:Create(
				fillBar,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(targetFraction, 0, 1, 0) }
			)
			tween:Play()
		end)

		-- Catatan Kualitatif / Subteks Refleksi
		local noteLbl = Instance.new("TextLabel")
		noteLbl.Name = "DimensionNote"
		noteLbl.Size = UDim2.new(1, 0, 0, 16)
		noteLbl.AutomaticSize = Enum.AutomaticSize.Y
		noteLbl.BackgroundTransparency = 1
		noteLbl.Font = Enum.Font.Gotham
		noteLbl.Text = cfg.Note
		noteLbl.TextColor3 = Color3.fromRGB(180, 205, 220)
		noteLbl.TextSize = 11
		noteLbl.TextWrapped = true
		noteLbl.TextXAlignment = Enum.TextXAlignment.Left
		noteLbl.LayoutOrder = 3
		noteLbl.Parent = metricCard
	end
end

local function renderReport(report: any, budget: number)
	gui.Enabled = true
	activeNodeKey = nil
	activeVoteToken = nil
	clearChoices()
	setBudget(budget)
	stageLabel.Text = string.format("Laporan desain | %s", report.SafetyStatus)

	-- [UPGRADE] Beralih dari PromptLabel ke ScrollingFrame laporan multidimensi
	promptLabel.Visible = false
	reportScrollFrame.Visible = true
	populateReportView(report, budget)

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
	activeNodeKey = nil
	setBudget(budget)
	stageLabel.Text = "Tahap Iterasi | Voting Tim"

	-- [UPGRADE] Pertahankan ScrollingFrame laporan jika sudah terbuka, agar pemain tetap dapat melihat metrik
	if reportScrollFrame.Visible then
		statusLabel.Text = if mustDeepPivot
			then "Safety Gate gagal: Tim perlu memilih Deep Pivot untuk merancang ulang."
			else "Pilih cara menanggapi umpan balik Rani. Quick Patch memperbaiki prototipe; Deep Pivot menjual prototipe dengan salvage 50%."
	else
		promptLabel.Visible = true
		promptLabel.Text = if mustDeepPivot
			then "Desain belum lolos Safety Gate. Tim perlu memilih Deep Pivot untuk merancang ulang jalur solusi."
			else "Pilih cara menanggapi umpan balik Rani. Quick Patch memperbaiki prototipe; Deep Pivot menjual prototipe dengan salvage 50%."
	end

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

