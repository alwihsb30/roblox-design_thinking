--!strict
-- Misi ruang dan aksi fisik CrossSafe. Dipanggil dari GameManager (server).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

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

function SpatialMissionManager.RunTestingSimulation(safetyStatus: string, onComplete: () -> ())
	simulationRunId += 1
	local thisRunId = simulationRunId
	local isSafe = safetyStatus == "PASS"
	local title = "Misi: Kawal Rani menyeberang"
	local detail = if isSafe
		then "Simulasi aman: lampu penyeberangan menyala dan kendaraan berhenti di belakang garis stop."
		else "Simulasi berisiko: kendaraan melintas, klakson berbunyi, dan Rani mundur menjauhi jalan."
	setMission("SIMULATION", title, detail, 0, 1)
	setSignalLamp(isSafe)
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
		if humanoid and root and entry and entry:IsA("BasePart") and (root.Position - entry.Position).Magnitude > 3 then
			moveHumanoidTo(humanoid, getHumanoidMarkerTarget(humanoid, entry), 6.5)
		end
		local hasMovingVehicle = false
		if simulationFolder then
			for vehicleNumber = 1, 2 do
				local movingVehicle, targetMarker = getVehicleAndMarker(simulationFolder, vehicleNumber, if isSafe then "Stop" else "Pass")
				if movingVehicle and targetMarker then
					hasMovingVehicle = true
					local homePivot = vehicleHomePivots[movingVehicle]
					if homePivot then
						movingVehicle:PivotTo(homePivot)
					end
				task.spawn(function()
					tweenModelTo(movingVehicle, targetMarker.CFrame, if isSafe then 3.5 else 2.8)
				end)
				end
			end
		end

		if humanoid and root and destination and destination:IsA("BasePart") then
			if isSafe then
				moveHumanoidTo(humanoid, getHumanoidMarkerTarget(humanoid, destination), 7.5)
			else
				local startPosition = root.Position
				local direction = destination.Position - startPosition
				if direction.Magnitude > 0.1 then
					direction = direction.Unit
					local neck = if npc then findRaniNeck(npc) else nil
					local originalNeckTransform = neck and neck.Transform
					if neck then
						neck.Transform = CFrame.Angles(math.rad(35), 0, 0)
					end
					moveHumanoidTo(humanoid, startPosition + direction * 5, 3)
					if neck and originalNeckTransform then
						neck.Transform = originalNeckTransform
					end
					playSound(hornSound)
					if npc then
						playRaniFlinch(npc, humanoid)
					end
					moveHumanoidTo(humanoid, startPosition - direction * 3, 3)
				end
			end
		end

		if hasMovingVehicle then
			task.wait(if isSafe then 3.6 else 2.9)
		else
			task.wait(1)
		end
		if thisRunId ~= simulationRunId then
			return
		end
		missionProgress = 1
		missionDetail = "Simulasi selesai. Rani memberi umpan balik; rapor evaluasi tim siap dibuka."
		sendMissionState(nil)
		local callback = onComplete
		callback()
	end)
end

return SpatialMissionManager

