--!strict
-- ModuleScript di ServerScriptService. Semua suara dan hasil seri ditentukan server.
local VotingHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DecisionTreeData = require(ReplicatedStorage:WaitForChild("DecisionTreeData"))

type VoteCallback = (winningChoice: string?) -> ()

type VoteSession = {
	Token: number,
	NodeKey: string,
	AllowedChoices: { [string]: boolean },
	Participants: { [Player]: boolean },
	VotesByPlayer: { [Player]: string },
	Callback: VoteCallback,
	IsActive: boolean,
	TimerThread: thread?,
}

local activeSession: VoteSession? = nil
local nextSessionToken = 0

local SAFETY_ORDER = {
	PASS = 1,
	CONDITIONAL = 2,
	FAIL = 3,
}

local RISK_ORDER = {
	NONE = 0,
	PROCESS_BIAS = 0,
	ACCESSIBILITY = 1,
	DISTRACTION = 2,
}

local function getParticipantCount(session: VoteSession): number
	local count = 0
	for player in pairs(session.Participants) do
		if player.Parent == Players then
			count += 1
		end
	end
	return count
end

local function allParticipantsVoted(session: VoteSession): boolean
	local participantCount = 0
	for player in pairs(session.Participants) do
		if player.Parent == Players then
			participantCount += 1
			if not session.VotesByPlayer[player] then
				return false
			end
		end
	end
	return participantCount > 0
end

local function candidateRank(session: VoteSession, choiceKey: string): (number, number, number)
	if session.NodeKey == "ITERATION" then
		-- Quick Patch menjadi tie-break pilihan karena biayanya lebih rendah daripada menjual prototipe.
		return choiceKey == "QUICK_PATCH" and 0 or 1, 0, 0
	end
	local node = DecisionTreeData.Nodes[session.NodeKey]
	local choice = node.Choices[choiceKey]
	local prototype = DecisionTreeData.Prototypes[choiceKey]
	if prototype then
		return SAFETY_ORDER[prototype.SafetyRating], -prototype.Points, prototype.Cost
	end
	return RISK_ORDER[choice.RiskTag], -choice.Points, 0
end

local function resolveTie(session: VoteSession, tiedChoices: { string }): string
	table.sort(tiedChoices, function(a: string, b: string): boolean
		local riskA, pointsA, costA = candidateRank(session, a)
		local riskB, pointsB, costB = candidateRank(session, b)
		if riskA ~= riskB then
			return riskA < riskB
		end
		if pointsA ~= pointsB then
			return pointsA < pointsB
		end
		if costA ~= costB then
			return costA < costB
		end
		return a < b
	end)
	return tiedChoices[1]
end

local function concludeVote(session: VoteSession)
	if activeSession ~= session or not session.IsActive then
		return
	end
	if session.TimerThread then
		pcall(task.cancel, session.TimerThread)
		session.TimerThread = nil
	end
	session.IsActive = false
	activeSession = nil
	if getParticipantCount(session) == 0 then
		session.Callback(nil)
		return
	end

	local tally: { [string]: number } = {}
	for player, choiceKey in pairs(session.VotesByPlayer) do
		if session.Participants[player] and player.Parent == Players then
			tally[choiceKey] = (tally[choiceKey] or 0) + 1
		end
	end

	local highestCount = -1
	local winners: { string } = {}
	for choiceKey in pairs(session.AllowedChoices) do
		local voteCount = tally[choiceKey] or 0
		if voteCount > highestCount then
			highestCount = voteCount
			winners = { choiceKey }
		elseif voteCount == highestCount then
			table.insert(winners, choiceKey)
		end
	end

	if #winners == 0 then
		session.Callback(nil)
		return
	end
	session.Callback(#winners == 1 and winners[1] or resolveTie(session, winners))
end

function VotingHandler.IsActive(): boolean
	return activeSession ~= nil and activeSession.IsActive
end

function VotingHandler.GetActiveToken(): number?
	if activeSession and activeSession.IsActive then
		return activeSession.Token
	end
	return nil
end

local function startSession(
	nodeKey: string,
	durationSeconds: number,
	allowedChoiceKeys: { string },
	onComplete: VoteCallback,
	isIterationSession: boolean
): boolean
	if activeSession then
		VotingHandler.CancelSession()
	end

	local node = DecisionTreeData.Nodes[nodeKey]
	if isIterationSession then
		assert(nodeKey == "ITERATION", "Kunci sesi iterasi tidak valid")
	else
		assert(node, "Node voting tidak ditemukan: " .. tostring(nodeKey))
	end
	assert(typeof(durationSeconds) == "number" and durationSeconds > 0 and durationSeconds <= 600, "Durasi voting tidak valid")
	assert(typeof(onComplete) == "function", "Callback voting tidak valid")
	assert(#allowedChoiceKeys > 0, "Voting harus memiliki setidaknya satu pilihan")

	local allowed: { [string]: boolean } = {}
	for _, choiceKey in ipairs(allowedChoiceKeys) do
		if isIterationSession then
			assert(choiceKey == "QUICK_PATCH" or choiceKey == "DEEP_PIVOT", "Pilihan iterasi tidak dikenal")
		else
			assert(node and node.Choices[choiceKey], string.format("Pilihan %s bukan anak dari node %s", choiceKey, nodeKey))
		end
		assert(not allowed[choiceKey], "Daftar pilihan voting memuat ID ganda")
		allowed[choiceKey] = true
	end

	local participants: { [Player]: boolean } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		participants[player] = true
	end
	if next(participants) == nil then
		return false
	end

	nextSessionToken += 1
	local session: VoteSession = {
		Token = nextSessionToken,
		NodeKey = nodeKey,
		AllowedChoices = allowed,
		Participants = participants,
		VotesByPlayer = {},
		Callback = onComplete,
		IsActive = true,
		TimerThread = nil,
	}
	activeSession = session
	session.TimerThread = task.delay(durationSeconds, function()
		if activeSession == session and session.IsActive then
			session.TimerThread = nil
			concludeVote(session)
		end
	end)
	return true
end

function VotingHandler.StartSession(
	nodeKey: string,
	durationSeconds: number,
	allowedChoiceKeys: { string },
	onComplete: VoteCallback
): boolean
	return startSession(nodeKey, durationSeconds, allowedChoiceKeys, onComplete, false)
end

function VotingHandler.StartIterationSession(
	durationSeconds: number,
	allowedActions: { string },
	onComplete: VoteCallback
): boolean
	return startSession("ITERATION", durationSeconds, allowedActions, onComplete, true)
end

function VotingHandler.CastVote(player: Player, nodeKey: string, sessionToken: number, choiceKey: string): boolean
	local session = activeSession
	if not session or not session.IsActive then
		return false
	end
	if typeof(nodeKey) ~= "string" or nodeKey ~= session.NodeKey then
		return false
	end
	if typeof(sessionToken) ~= "number" or sessionToken ~= session.Token then
		return false
	end
	if typeof(choiceKey) ~= "string" or not session.AllowedChoices[choiceKey] then
		return false
	end
	if not session.Participants[player] or player.Parent ~= Players then
		return false
	end

	-- Pemain boleh mengubah suara sebelum voting ditutup; hanya suara terakhir yang dihitung.
	session.VotesByPlayer[player] = choiceKey
	if allParticipantsVoted(session) then
		concludeVote(session)
	end
	return true
end

function VotingHandler.CancelSession()
	local session = activeSession
	if not session then
		return
	end
	activeSession = nil
	session.IsActive = false
	if session.TimerThread then
		pcall(task.cancel, session.TimerThread)
		session.TimerThread = nil
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	if activeSession and activeSession.IsActive then
		activeSession.Participants[player] = true
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local session = activeSession
	if not session or not session.IsActive then
		return
	end
	session.Participants[player] = nil
	session.VotesByPlayer[player] = nil
	if getParticipantCount(session) > 0 and allParticipantsVoted(session) then
		concludeVote(session)
	end
end)

return VotingHandler
