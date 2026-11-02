--!strict
-- Misi ruang dan aksi fisik CrossSafe. Dipanggil dari GameManager (server).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DecisionTreeData = require(ReplicatedStorage:WaitForChild("DecisionTreeData"))

type MissionCompleteCallback = (string, Player, string?) -> ()

local SpatialMissionManager = {}

local syncEvent: RemoteEvent? = nil
local onMissionCompleted: MissionCompleteCallback? = nil
local isInitialized = false
local activeMissionKey: string? = nil
local lastMissionKey = ""
local missionTitle = "Misi: Selidiki Titik Bahaya Jalan Raya"
local missionDetail = "Periksa tiga bukti fisik sebelum berbicara dengan Rani."
local missionProgress = 0
local missionRequired = 3
local blueprintVisited: { [string]: boolean } = {}
local simulationRunId = 0

local whiteboardPart: BasePart? = nil
local whiteboardPrompt: ProximityPrompt? = nil
local blueprintParts: { [string]: BasePart } = {}
local blueprintPrompts: { [string]: ProximityPrompt } = {}
local cratePart: BasePart? = nil
local cratePrompt: ProximityPrompt? = nil
local prototypeSlot: BasePart? = nil
local assemblyPrompt: ProximityPrompt? = nil
local assemblySound: Sound? = nil
local hornSound: Sound? = nil
local vehicleHomePivots: { [Model]: CFrame } = {}

local function getFolderChildPart(folderName: string, childName: string): BasePart?
	local folder = workspace:FindFirstChild(folderName)
	local child = folder and folder:FindFirstChild(childName)
	if child and child:IsA("BasePart") then
		return child
	end
	return nil
end

local function getPlayerRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isPlayerNear(player: Player, part: BasePart, distance: number): boolean
	local root = getPlayerRoot(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= distance
end

local function sendMissionState(targetPlayer: Player?)
	local remote = syncEvent
	if not remote then
		return
	end
	if targetPlayer then
		remote:FireClient(targetPlayer, "MISSION_UPDATE", missionTitle, missionDetail, missionProgress, missionRequired, activeMissionKey or lastMissionKey)
	else
		remote:FireAllClients("MISSION_UPDATE", missionTitle, missionDetail, missionProgress, missionRequired, activeMissionKey or lastMissionKey)
	end
end

local function notifyAll(action: string, ...: any)
	local remote = syncEvent
	if remote then
		remote:FireAllClients(action, ...)
	end
end

local function setMission(key: string, title: string, detail: string, progress: number, required: number)
	activeMissionKey = key
	lastMissionKey = key
	missionTitle = title
	missionDetail = detail
	missionProgress = progress
	missionRequired = required
	sendMissionState(nil)
end

local function makePrompt(part: BasePart?, actionText: string, objectText: string, holdDuration: number): ProximityPrompt?
	if not part then
		return nil
	end
	local existing = part:FindFirstChild("SpatialMissionPrompt")
	if existing and not existing:IsA("ProximityPrompt") then
		warn(string.format("SpatialMissionPrompt pada %s harus berupa ProximityPrompt.", part:GetFullName()))
		return nil
	end
	local prompt = existing :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SpatialMissionPrompt"
		prompt.Parent = part
	end
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = holdDuration
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	return prompt
end

local function setPromptEnabled(prompt: ProximityPrompt?, enabled: boolean)
	if prompt and prompt.Parent then
		prompt.Enabled = enabled
	end
end

local function completeMission(key: string, player: Player, detail: string?)
	if activeMissionKey ~= key then
		return
	end
	if key == "WAR_ROOM" then
		setPromptEnabled(whiteboardPrompt, false)
	elseif key == "BLUEPRINT" then
		for _, prompt in pairs(blueprintPrompts) do
			setPromptEnabled(prompt, false)
		end
	elseif key == "ASSEMBLY" or key == "MATERIALS" then
		setPromptEnabled(cratePrompt, false)
		setPromptEnabled(assemblyPrompt, false)
	end
	activeMissionKey = nil
	missionProgress = missionRequired
	missionDetail = "Berhasil. Tim dapat melanjutkan ke tahap berikutnya."
	sendMissionState(nil)
	local callback = onMissionCompleted
	if callback then
		callback(key, player, detail)
	end
end

local function findMaterialTool(player: Player): Tool?
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("CrossSafeMaterial") == true then
				return child
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("CrossSafeMaterial") == true then
				return child
			end
		end
	end
	return nil
end

local function createMaterialTool(player: Player): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not backpack or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if findMaterialTool(player) then
		return true
	end

	local tool = Instance.new("Tool")
	tool.Name = "Material_Komponen_Prototipe"
	tool.ToolTip = "Material Komponen — bawa ke PrototypeSlot"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("CrossSafeMaterial", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.3, 1.3, 1.3)
	handle.Color = Color3.fromRGB(178, 118, 69)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MaterialLabel"
	billboard.Size = UDim2.fromOffset(150, 38)
	billboard.StudsOffset = Vector3.new(0, 1.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = handle
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(85, 52, 31)
	label.BackgroundTransparency = 0.08
	label.Text = "MATERIAL KOMPONEN"
	label.TextColor3 = Color3.fromRGB(255, 245, 220)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	tool.Parent = backpack
	humanoid:EquipTool(tool)
	return true
end

local function removeMaterialTools()
	for _, player in ipairs(Players:GetPlayers()) do
		local containers: { Instance } = {}
		if player.Character then
			table.insert(containers, player.Character)
		end
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			table.insert(containers, backpack)
		end
		for _, container in ipairs(containers) do
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("CrossSafeMaterial") == true then
					child:Destroy()
				end
			end
		end
	end
end

local function playSound(sound: Sound?)
	if sound and sound.SoundId ~= "" then
		sound:Play()
	end
end

local function getSimulationFolder(): Instance?
	return workspace:FindFirstChild("CrossSafeSimulation")
end

local function getRaniHumanoid(): (Model?, Humanoid?, BasePart?)
	local npc = workspace:FindFirstChild("Rani_NPC")
	if not npc or not npc:IsA("Model") then
		return nil, nil, nil
	end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		root = npc.PrimaryPart
	end
	if not root or not root:IsA("BasePart") then
		return npc, humanoid, nil
	end
	return npc, humanoid, root
end

local function moveHumanoidTo(humanoid: Humanoid, position: Vector3, timeoutSeconds: number): boolean
	local completed = false
	local reachedGoal = false
	local connection = humanoid.MoveToFinished:Connect(function(reached: boolean)
		completed = true
		reachedGoal = reached
	end)
	humanoid:MoveTo(position)
	local deadline = os.clock() + timeoutSeconds
	while not completed and os.clock() < deadline do
		task.wait(0.1)
	end
	connection:Disconnect()
	return completed and reachedGoal
end

local function getHumanoidMarkerTarget(humanoid: Humanoid, marker: BasePart): Vector3
	return marker.Position + Vector3.new(0, humanoid.HipHeight + 1, 0)
end

local function tweenModelTo(model: Model, destination: CFrame, duration: number)
	if not model.Parent then
		return
	end
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	local connection = value:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then
			model:PivotTo(value.Value)
		end
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = destination })
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	value:Destroy()
end

local function setSignalLamp(isOn: boolean)
	local simulationFolder = getSimulationFolder()
	local lamp = simulationFolder and simulationFolder:FindFirstChild("SignalLamp")
	if not lamp or not lamp:IsA("BasePart") then
		return
	end
	lamp.Color = if isOn then Color3.fromRGB(64, 255, 121) else Color3.fromRGB(70, 75, 78)
	for _, child in ipairs(lamp:GetChildren()) do
		if child:IsA("PointLight") or child:IsA("SpotLight") or child:IsA("SurfaceLight") then
			child.Enabled = isOn
		end
	end
end

local function playRaniFlinch(npc: Model, humanoid: Humanoid)
	local animation = npc:FindFirstChild("CrossSafeFlinch", true)
	if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
		local animatorInstance = humanoid:FindFirstChildOfClass("Animator")
		local animator = animatorInstance :: Animator?
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track:Play(0.1)
			return
		end
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

local function findRaniNeck(npc: Model): Motor6D?
	local neck = npc:FindFirstChild("Neck", true)
	if not neck or not neck:IsA("Motor6D") then
		return nil
	end
	return neck
end

local function getVehicleAndMarker(simulationFolder: Instance, vehicleNumber: number, targetKind: string): (Model?, BasePart?)
	local vehicle = simulationFolder:FindFirstChild("Vehicle_" .. tostring(vehicleNumber))
	local target = simulationFolder:FindFirstChild("Vehicle" .. targetKind .. "_" .. tostring(vehicleNumber))
	if not vehicle or not vehicle:IsA("Model") or not target or not target:IsA("BasePart") then
		return nil, nil
	end
	return vehicle, target
end

-- [UPGRADE] Aktor kedua: Pengguna Ekstrem (Budi / Teman Rani pengguna kursi roda)
local activeExtremeActor: Model? = nil

local function cleanupExtremeActor()
	if activeExtremeActor and activeExtremeActor.Parent then
		activeExtremeActor:Destroy()
	end
	activeExtremeActor = nil
end

local function spawnExtremeUser(startCFrame: CFrame): (Model?, Humanoid?, BasePart?)
	cleanupExtremeActor()
	local rani = workspace:FindFirstChild("Rani_NPC")
	if not rani or not rani:IsA("Model") then
		return nil, nil, nil
	end

	local clone = rani:Clone()
	clone.Name = "ExtremeUser_Budi"

	-- Bersihkan prompt interaksi pada klon
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			desc:Destroy()
		end
	end

	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	local root = clone:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		clone:Destroy()
		return nil, nil, nil
	end

	-- Kecepatan jalan lebih lambat (pejalan kaki rentan / difabel)
	humanoid.WalkSpeed = 8

	-- Bedakan penampilan: warnai pakaian/torso
	local torso = clone:FindFirstChild("Torso") or clone:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		torso.Color = Color3.fromRGB(65, 125, 185)
	end

	-- Pasang struktur kursi roda representatif
	local seat = Instance.new("Part")
	seat.Name = "WheelchairSeat"
	seat.Size = Vector3.new(2.4, 0.4, 2.2)
	seat.CFrame = root.CFrame * CFrame.new(0, -1.2, 0.2)
	seat.Color = Color3.fromRGB(45, 55, 65)
	seat.Material = Enum.Material.Metal
	seat.CanCollide = false
	seat.Anchored = false
	seat.Parent = clone

	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = root
	seatWeld.Part1 = seat
	seatWeld.Parent = seat

	for _, xOffset in ipairs({ -1.3, 1.3 }) do
		local wheel = Instance.new("Part")
		wheel.Name = "Wheel"
		wheel.Size = Vector3.new(0.3, 2.2, 2.2)
		wheel.Shape = Enum.PartType.Cylinder
		wheel.CFrame = root.CFrame * CFrame.new(xOffset, -1.2, 0.2) * CFrame.Angles(0, 0, math.rad(90))
		wheel.Color = Color3.fromRGB(30, 30, 30)
		wheel.Material = Enum.Material.Rubber
		wheel.CanCollide = false
		wheel.Anchored = false
		wheel.Parent = clone

		local wheelWeld = Instance.new("WeldConstraint")
		wheelWeld.Part0 = root
		wheelWeld.Part1 = wheel
		wheelWeld.Parent = wheel
	end

	-- Tag identitas di atas kepala
	local head = clone:FindFirstChild("Head") or root
	local tag = Instance.new("BillboardGui")
	tag.Name = "ActorTag"
	tag.Size = UDim2.fromOffset(180, 26)
	tag.StudsOffset = Vector3.new(0, 2.8, 0)
	tag.AlwaysOnTop = true
	tag.Parent = head

	local tagLbl = Instance.new("TextLabel")
	tagLbl.Size = UDim2.fromScale(1, 1)
	tagLbl.BackgroundColor3 = Color3.fromRGB(25, 45, 65)
	tagLbl.Text = "Budi (Pengguna Kursi Roda)"
	tagLbl.TextColor3 = Color3.fromRGB(180, 230, 255)
	tagLbl.Font = Enum.Font.GothamBold
	tagLbl.TextSize = 11
	tagLbl.Parent = tag
	local tagCorner = Instance.new("UICorner")
	tagCorner.CornerRadius = UDim.new(0, 6)
	tagCorner.Parent = tagLbl

	clone:PivotTo(startCFrame)
	clone.Parent = workspace
	activeExtremeActor = clone

	return clone, humanoid, root
end

-- [UPGRADE] Menampilkan gelembung dialog reaksi pada NPC
local function showActorDialogue(npc: Model, text: string, duration: number, isWarning: boolean?)
	local head = npc:FindFirstChild("Head") or npc.PrimaryPart
	if not head or not head:IsA("BasePart") then
		return
	end

	local oldBubble = head:FindFirstChild("SpeechBubbleGui")
	if oldBubble then
		oldBubble:Destroy()
	end

	local bubble = Instance.new("BillboardGui")
	bubble.Name = "SpeechBubbleGui"
	bubble.Size = UDim2.fromOffset(230, 64)
	bubble.StudsOffset = Vector3.new(0, 4.2, 0)
	bubble.AlwaysOnTop = true
	bubble.Parent = head

	local bubbleFrame = Instance.new("Frame")
	bubbleFrame.Size = UDim2.fromScale(1, 1)
	bubbleFrame.BackgroundColor3 = if isWarning
		then Color3.fromRGB(160, 35, 35)
		else Color3.fromRGB(24, 38, 52)
	bubbleFrame.BorderSizePixel = 0
	bubbleFrame.Parent = bubble

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bubbleFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = if isWarning then Color3.fromRGB(255, 110, 110) else Color3.fromRGB(70, 120, 170)
	stroke.Thickness = 1.5
	stroke.Parent = bubbleFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, -12)
	label.Position = UDim2.fromOffset(8, 6)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = bubbleFrame

	pcall(function()
		local Chat = game:GetService("Chat")
		Chat:Chat(head, text, Enum.ChatColor.White)
	end)

	task.delay(duration, function()
		if bubble and bubble.Parent then
			bubble:Destroy()
		end
	end)
end

local function configureScene()
	whiteboardPart = getFolderChildPart("WarRoom", "Whiteboard")
	local boardPrompt = makePrompt(whiteboardPart, "Buka Papan Analisis", "Papan Tulis Satpam", 0.5)
	whiteboardPrompt = boardPrompt
	if boardPrompt and whiteboardPart then
		boardPrompt.Triggered:Connect(function(player: Player)
			if activeMissionKey ~= "WAR_ROOM" or not isPlayerNear(player, whiteboardPart :: BasePart, boardPrompt.MaxActivationDistance + 1) then
				return
			end
			completeMission("WAR_ROOM", player, nil)
		end)
	end

	local stationFolder = workspace:FindFirstChild("BlueprintStations")
	for _, stationId in ipairs({ "A", "B" }) do
		local part = stationFolder and stationFolder:FindFirstChild("Station_" .. stationId)
		if part and part:IsA("BasePart") then
			blueprintParts[stationId] = part
			local objectText = if stationId == "A" then "Cetak Biru Marka & Speed Table" else "Cetak Biru Smart Traffic & Sensor"
			local prompt = makePrompt(part, "Baca Blueprint", objectText, 0.75)
			if prompt then
				blueprintPrompts[stationId] = prompt
				prompt.Triggered:Connect(function(player: Player)
					if activeMissionKey ~= "BLUEPRINT" or blueprintVisited[stationId] then
						return
					end
					if not isPlayerNear(player, part, prompt.MaxActivationDistance + 1) then
						return
					end
					blueprintVisited[stationId] = true
					local blueprintName = if stationId == "A" then "Bengkel Konstruksi Jalan" else "Lab Komputer/Elektronik"
					local description = if stationId == "A"
						then "Blueprint marka jalan, pita kejut, dan speed table landai sudah dipelajari tim."
						else "Blueprint Smart Traffic dan sensor penyeberangan sudah dipelajari tim."
					notifyAll("WORLD_DISCOVERY", "Blueprint dibaca: " .. blueprintName, description)
					completeMission("BLUEPRINT", player, stationId)
				end)
			end
		end
	end

	cratePart = getFolderChildPart("MaterialSupply", "Crate")
	local supplyPrompt = makePrompt(cratePart, "Ambil Komponen Prototipe", "Kotak Material", 0.75)
	cratePrompt = supplyPrompt
	if supplyPrompt and cratePart then
		supplyPrompt.Triggered:Connect(function(player: Player)
			if activeMissionKey ~= "MATERIALS" or not isPlayerNear(player, cratePart :: BasePart, supplyPrompt.MaxActivationDistance + 1) then
				return
			end
			if not createMaterialTool(player) then
				notifyAll("MISSION_HINT", "Material belum bisa diambil", "Pastikan karakter pemain masih hidup dan Backpack sudah tersedia.")
				return
			end
			missionTitle = "Misi: Bawa material lalu rakit di zebra cross"
			missionDetail = "Material sudah dipegang. Bawa Tool ke PrototypeSlot dan tahan E selama 1,5 detik."
			sendMissionState(nil)
			notifyAll("WORLD_DISCOVERY", "Material prototipe diambil", player.DisplayName .. " membawa komponen menuju titik perakitan.")
		end)
	end

	prototypeSlot = getFolderChildPart("InteractionStation", "PrototypeSlot")
	local slotPrompt = makePrompt(prototypeSlot, "Rakit Komponen Prototipe", "Meja Perakitan", 1.5)
	assemblyPrompt = slotPrompt
	if prototypeSlot then
		local sound = prototypeSlot:FindFirstChild("AssemblySound")
		if sound and sound:IsA("Sound") then
			assemblySound = sound
		else
			assemblySound = Instance.new("Sound")
			assemblySound.Name = "AssemblySound"
			assemblySound.Volume = 1
			assemblySound.RollOffMaxDistance = 60
			assemblySound.Parent = prototypeSlot
		end
	end
	if slotPrompt and prototypeSlot then
		slotPrompt.Triggered:Connect(function(player: Player)
			if activeMissionKey ~= "MATERIALS" or not isPlayerNear(player, prototypeSlot :: BasePart, slotPrompt.MaxActivationDistance + 1) then
				return
			end
			local character = player.Character
			local tool = findMaterialTool(player)
			if not character or not tool or tool.Parent ~= character then
				notifyAll("MISSION_HINT", "Komponen belum siap dirakit", "Lengkapi perjalanan dengan Tool Material Komponen tetap terpasang di tangan.")
				return
			end
			setPromptEnabled(cratePrompt, false)
			setPromptEnabled(assemblyPrompt, false)
			playSound(assemblySound)
			activeMissionKey = "ASSEMBLY"
			lastMissionKey = "ASSEMBLY"
			missionTitle = "Misi: Rakit prototipe di lapangan"
			missionDetail = "Komponen sedang dipasang pada PrototypeSlot."
			missionProgress = 0
			missionRequired = 1
			sendMissionState(nil)
			notifyAll("ASSEMBLY_STARTED", "Perakitan dimulai", "Komponen sedang dipasang pada titik prototipe.")
			task.delay(1, function()
				if activeMissionKey ~= "ASSEMBLY" then
					return
				end
				removeMaterialTools()
				completeMission("ASSEMBLY", player, nil)
			end)
		end)
	end

	local simulationFolder = getSimulationFolder()
	if simulationFolder then
		local horn = simulationFolder:FindFirstChild("HornSound")
		if horn and horn:IsA("Sound") then
			hornSound = horn
		end
		for vehicleNumber = 1, 2 do
			local vehicle = simulationFolder:FindFirstChild("Vehicle_" .. tostring(vehicleNumber))
			if vehicle and vehicle:IsA("Model") then
				vehicleHomePivots[vehicle] = vehicle:GetPivot()
			end
		end
	end

	for _, prompt in ipairs({ whiteboardPrompt, cratePrompt, assemblyPrompt }) do
		setPromptEnabled(prompt, false)
	end
	for _, prompt in pairs(blueprintPrompts) do
		setPromptEnabled(prompt, false)
	end
end

function SpatialMissionManager.Initialize(remote: RemoteEvent, callback: MissionCompleteCallback)
	if isInitialized then
		return
	end
	isInitialized = true
	syncEvent = remote
	onMissionCompleted = callback
	configureScene()
end

function SpatialMissionManager.StartWarRoomMission(): boolean
	if not whiteboardPart or not whiteboardPrompt then
		warn("Misi Define perlu Workspace.WarRoom.Whiteboard sebagai BasePart.")
		notifyAll("MISSION_SETUP_MISSING", "Workspace.WarRoom.Whiteboard harus dibuat sebelum Play Test.")
		return false
	end
	setPromptEnabled(whiteboardPrompt, true)
	setMission("WAR_ROOM", "Misi: Bawa bukti ke Meja Analisis", "Rani: Terima kasih sudah mengecek bukti! Sekarang bawa bukti-bukti ini ke Meja Analisis di Pos Satpam depan gerbang sekolah!", 0, 1)
	return true
end

function SpatialMissionManager.StartBlueprintMission(): boolean
	if not blueprintPrompts.A or not blueprintPrompts.B then
		warn("Misi Ideate perlu Workspace.BlueprintStations.Station_A dan Station_B.")
		notifyAll("MISSION_SETUP_MISSING", "Buat Workspace.BlueprintStations.Station_A dan Station_B sebelum Play Test.")
		return false
	end
	blueprintVisited = {}
	for _, prompt in pairs(blueprintPrompts) do
		setPromptEnabled(prompt, true)
	end
	setMission("BLUEPRINT", "Misi: Jelajahi Blueprint Kota", "Tim perlu membaca minimal satu blueprint di Bengkel Konstruksi Jalan atau Lab Komputer/Elektronik.", 0, 1)
	return true
end

function SpatialMissionManager.CanStartMaterialMission(): (boolean, string)
	if not cratePart or not cratePrompt then
		return false, "Workspace.MaterialSupply.Crate belum tersedia."
	end
	if not prototypeSlot or not assemblyPrompt then
		return false, "Workspace.InteractionStation.PrototypeSlot belum tersedia."
	end
	return true, ""
end

function SpatialMissionManager.CanRunTestingSimulation(): (boolean, string)
	local ok, reason = SpatialMissionManager.CanStartMaterialMission()
	if not ok then
		return false, reason
	end
	local _, humanoid, root = getRaniHumanoid()
	if not humanoid or not root then
		return false, "Workspace.Rani_NPC harus memiliki Humanoid dan HumanoidRootPart."
	end
	if root.Anchored then
		return false, "HumanoidRootPart milik Rani harus tidak Anchored agar dapat berjalan."
	end
	local destination = workspace:FindFirstChild("Crosswalk_Destination")
	if not destination or not destination:IsA("BasePart") then
		return false, "Workspace.Crosswalk_Destination belum tersedia."
	end
	local simulationFolder = getSimulationFolder()
	if not simulationFolder then
		return false, "Workspace.CrossSafeSimulation belum tersedia."
	end
	local signalLamp = simulationFolder:FindFirstChild("SignalLamp")
	if not signalLamp or not signalLamp:IsA("BasePart") then
		return false, "Workspace.CrossSafeSimulation.SignalLamp belum tersedia sebagai BasePart."
	end
	local stopLine = simulationFolder:FindFirstChild("StopLine")
	local entry = workspace:FindFirstChild("Crosswalk_Entry")
	if not stopLine or not stopLine:IsA("BasePart") or not entry or not entry:IsA("BasePart") then
		return false, "Buat CrossSafeSimulation.StopLine dan Workspace.Crosswalk_Entry."
	end
	for vehicleNumber = 1, 2 do
		local vehicle, stopMarker = getVehicleAndMarker(simulationFolder, vehicleNumber, "Stop")
		local _, passMarker = getVehicleAndMarker(simulationFolder, vehicleNumber, "Pass")
		if not vehicle or not stopMarker or not passMarker then
			return false, string.format("Buat Vehicle_%d, VehicleStop_%d, dan VehiclePass_%d di CrossSafeSimulation.", vehicleNumber, vehicleNumber, vehicleNumber)
		end
	end
	return true, ""
end

function SpatialMissionManager.StartMaterialMission(): boolean
	local ok, reason = SpatialMissionManager.CanRunTestingSimulation()
	if not ok then
		warn("Misi perakitan/simulasi belum siap: " .. reason)
		notifyAll("MISSION_SETUP_MISSING", reason)
		return false
	end
	removeMaterialTools()
	setPromptEnabled(cratePrompt, true)
	setPromptEnabled(assemblyPrompt, true)
	setMission("MATERIALS", "Misi: Ambil material lalu rakit di zebra cross", "Ambil komponen dari kotak logistik, lalu bawa Tool ke PrototypeSlot.", 0, 1)
	return true
end

function SpatialMissionManager.GetSnapshot(): { [string]: any }
	return {
		MissionKey = activeMissionKey or lastMissionKey,
		MissionTitle = missionTitle,
		MissionDetail = missionDetail,
		MissionProgress = missionProgress,
		MissionRequired = missionRequired,
		BlueprintVisited = table.clone(blueprintVisited),
	}
end

function SpatialMissionManager.SendState(player: Player)
	sendMissionState(player)
end

-- [UPGRADE] Simulasi Penyeberangan Dinamis & Multi-Aktor (Testing Tahap 5)
function SpatialMissionManager.RunTestingSimulation(simulationPayload: any, onComplete: () -> ())
	simulationRunId += 1
	local thisRunId = simulationRunId

	local safetyStatus: string
	local prototypeKey: string = ""
	local isPatched: boolean = false
	if typeof(simulationPayload) == "table" then
		safetyStatus = simulationPayload.SafetyStatus or "FAIL"
		prototypeKey = simulationPayload.SelectedPrototypeKey or ""
		isPatched = simulationPayload.IsPatched == true
	else
		safetyStatus = tostring(simulationPayload)
	end

	local isSafe = safetyStatus == "PASS"

	-- Klasifikasi profil perilaku desain
	local isPelican = prototypeKey == "P.15" or prototypeKey == "P.16"
	local isSpeedControl = prototypeKey == "P.04" or prototypeKey == "P.06" or prototypeKey == "P.07" or prototypeKey == "P.08"
	local isOverpass = prototypeKey == "P.09" or prototypeKey == "P.10" or prototypeKey == "P.11" or prototypeKey == "P.12"
	local isDangerous = not isSafe or prototypeKey == "P.01" or prototypeKey == "P.03" or prototypeKey == "P.05" or prototypeKey == "P.13" or prototypeKey == "P.14"

	-- Validasi Aksesibilitas Ekstrem (Inklusivitas)
	local isSteepStairsNoLift = prototypeKey == "P.09" or (prototypeKey == "P.10" and not isPatched)

	local title = "Misi: Pengujian Penyeberangan (Rani & Teman Difabel)"
	local detail: string
	if isPelican then
		detail = "Lampu penyeberangan aktif: kendaraan berhenti di belakang stop line dan hitung mundur berbunyi."
	elseif isOverpass then
		detail = if isSteepStairsNoLift
			then "JPO bertangga curam: pejalan kaki biasa melintas, namun kursi roda tidak dapat menaiki tangga."
			else "JPO ramp landai: kendaraan melintas lancar di bawah; Rani dan Budi menyeberang aman di atas."
	elseif isSpeedControl then
		detail = "Marka kejut / speed bump: kendaraan melambat halus dan pejalan kaki menyeberang tertib."
	else
		detail = "Peringatan bahaya: kendaraan melaju kencang, rem mendadak, dan pejalan kaki terpaksa mundur!"
	end

	setMission("SIMULATION", title, detail, 0, 1)
	setSignalLamp(isPelican or (isSafe and not isOverpass))
	notifyAll("SIMULATION_BEAT", if isSafe then "SAFETY_PASS" else "SAFETY_FAIL")

	task.spawn(function()
		local simulationFolder = getSimulationFolder()
		local npc, humanoid, root = getRaniHumanoid()
		if root and not root.Anchored then
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
		end

		local destination = workspace:FindFirstChild("Crosswalk_Destination")
		local entry = workspace:FindFirstChild("Crosswalk_Entry")

		-- Posisi awal di entry
		if humanoid and root and entry and entry:IsA("BasePart") then
			local entryCFrame = entry.CFrame
			if (root.Position - entry.Position).Magnitude > 6 then
				moveHumanoidTo(humanoid, getHumanoidMarkerTarget(humanoid, entry), 4.0)
			end
			root.CFrame = entryCFrame * CFrame.new(-1.8, 0, 0)
		end

		-- [UPGRADE] Spawn aktor kedua: Pengguna Ekstrem (Budi) di sebelah Rani
		local extremeNpc, extremeHumanoid, extremeRoot = nil, nil, nil
		if entry and entry:IsA("BasePart") then
			local extremeStart = entry.CFrame * CFrame.new(1.8, 0, 0)
			extremeNpc, extremeHumanoid, extremeRoot = spawnExtremeUser(extremeStart)
		end

		-- Perilaku Kendaraan Reaktif
		local hasMovingVehicle = false
		if simulationFolder then
			for vehicleNumber = 1, 2 do
				local targetKind = "Stop"
				local vehicleDuration = 3.5

				if isOverpass then
					targetKind = "Pass"
					vehicleDuration = 2.8 -- Lalu lintas bawah mengalir lancar
				elseif isDangerous then
					targetKind = "Pass"
					vehicleDuration = 2.2 -- Melaju kencang
				elseif isPelican then
					targetKind = "Stop"
					vehicleDuration = 3.0 -- Berhenti total di stop line
				elseif isSpeedControl then
					targetKind = "Stop"
					vehicleDuration = 4.0 -- Melambat halus
				end

				local movingVehicle, targetMarker = getVehicleAndMarker(simulationFolder, vehicleNumber, targetKind)
				if movingVehicle and targetMarker then
					hasMovingVehicle = true
					local homePivot = vehicleHomePivots[movingVehicle]
					if homePivot then
						movingVehicle:PivotTo(homePivot)
					end

					task.spawn(function()
						tweenModelTo(movingVehicle, targetMarker.CFrame, vehicleDuration)
					end)
				end
			end
		end

		-- Perilaku Pejalan Kaki (Rani & Budi)
		if humanoid and root and destination and destination:IsA("BasePart") then
			local startPosition = root.Position
			local direction = destination.Position - startPosition
			if direction.Magnitude > 0.1 then
				direction = direction.Unit
			end

			if isDangerous then
				-- Skenario Berisiko / Rem Mendadak / Distraksi
				if prototypeKey == "P.13" or prototypeKey == "P.14" then
					if npc then showActorDialogue(npc, "Membaca panduan HP... eh?", 2) end
				else
					if npc then showActorDialogue(npc, "Ayo kita coba seberang...", 2) end
				end

				-- Langkah awal masuk ke jalan
				moveHumanoidTo(humanoid, startPosition + direction * 4, 1.8)
				if extremeHumanoid and extremeRoot then
					task.spawn(function()
						moveHumanoidTo(extremeHumanoid, extremeRoot.Position + direction * 3, 1.8)
					end)
				end

				task.wait(1.2)
				playSound(hornSound)

				if npc then
					showActorDialogue(npc, "Awas mobil kencang! Hampir tertabrak!", 3.5, true)
					playRaniFlinch(npc, humanoid)
				end
				if extremeNpc then
					showActorDialogue(extremeNpc, "Bahaya sekali! Kursi roda susah mundur cepat!", 3.5, true)
				end

				-- Mundur kembali ke trotoar aman
				moveHumanoidTo(humanoid, startPosition - direction * 2, 2.5)
				if extremeHumanoid and extremeRoot then
					task.spawn(function()
						moveHumanoidTo(extremeHumanoid, extremeRoot.Position - direction * 3, 2.5)
					end)
				end

			elseif isSteepStairsNoLift then
				-- Skenario Kegagalan Inklusivitas (JPO Tangga Curam)
				if npc then
					showActorDialogue(npc, "Huft... tangganya 40 trap, melelahkan sekali!", 4)
				end
				task.spawn(function()
					moveHumanoidTo(humanoid, getHumanoidMarkerTarget(humanoid, destination), 7.0)
				end)

				task.wait(1.0)
				if extremeNpc and extremeHumanoid then
					-- Budi berhenti di kaki tangga, tidak bisa naik
					showActorDialogue(extremeNpc, "Tangganya curam tanpa ramp/lift... Kursi rodaku tidak bisa naik!", 4.5, true)
					if extremeRoot then
						extremeHumanoid:MoveTo(extremeRoot.Position + Vector3.new(1, 0, 0))
						task.wait(0.8)
						extremeHumanoid:MoveTo(extremeRoot.Position - Vector3.new(1, 0, 0))
					end
				end

			else
				-- Skenario Aman & Inklusif
				if isPelican then
					if npc then showActorDialogue(npc, "Lampu hijau menyala dan tombol berbunyi bip!", 3) end
					if extremeNpc then showActorDialogue(extremeNpc, "Waktu hitung mundurnya jelas untuk menyeberang!", 3) end
				elseif isOverpass then
					if npc then showActorDialogue(npc, "JPO ramp landai ini teduh dan aman!", 3) end
					if extremeNpc then showActorDialogue(extremeNpc, "Asyik, ramp-nya bisa dilewati kursi roda!", 3) end
				else
					if npc then showActorDialogue(npc, "Mobilnya melambat dan memberi jalan!", 3) end
					if extremeNpc then showActorDialogue(extremeNpc, "Jalanan rata dan nyaman!", 3) end
				end

				-- Menyeberang bersama ke seberang
				task.spawn(function()
					moveHumanoidTo(humanoid, getHumanoidMarkerTarget(humanoid, destination), 7.0)
				end)
				if extremeHumanoid and extremeRoot then
					task.spawn(function()
						local destOffset = getHumanoidMarkerTarget(extremeHumanoid, destination) + Vector3.new(2.5, 0, 0)
						moveHumanoidTo(extremeHumanoid, destOffset, 7.5)
					end)
				end

				task.wait(3.5)
				if npc then showActorDialogue(npc, "Alhamdulillah, kita sampai di sekolah dengan aman!", 3.5) end
				if extremeNpc then showActorDialogue(extremeNpc, "Desain penyeberangan ini sangat inklusif!", 3.5) end
			end
		end

		task.wait(4.5)

		if thisRunId ~= simulationRunId then
			cleanupExtremeActor()
			return
		end

		missionProgress = 1
		missionDetail = "Simulasi selesai. Rani dan Budi memberikan umpan balik; rapor evaluasi tim siap dibuka."
		sendMissionState(nil)

		local callback = onComplete
		callback()

		-- Bersihkan aktor sementara setelah laporan siap tampil
		task.delay(4, cleanupExtremeActor)
	end)
end

function SpatialMissionManager.ResetSimulation()
	cleanupExtremeActor()
end

return SpatialMissionManager
