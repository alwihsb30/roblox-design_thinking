--!strict
-- ModuleScript di ServerScriptService. Menghitung skor dari jalur sah, lalu menerapkan Safety Gate.
local EvaluationService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DecisionTreeData = require(ReplicatedStorage:WaitForChild("DecisionTreeData"))

export type SafetyStatus = "PASS" | "CONDITIONAL" | "FAIL"

export type FullReport = {
	ScoreDT: number,
	SafetyStatus: SafetyStatus,
	StarRating: number,
	RemainingBudget: number,
	VerdictTitle: string,
	UserNeedAddressed: string,
	CriticalRiskNote: string,
	RaniStatement: string,
	SelectedPrototypeKey: string,
	IsPatched: boolean,
	CanQuickPatch: boolean,
	CanDeepPivot: boolean,
	MustDeepPivot: boolean,
	PivotBlockedByBudget: boolean,
}

local function getBaseStarRating(score: number): number
	if score >= 95 then
		return 5
	elseif score >= 80 then
		return 4
	elseif score >= 65 then
		return 3
	elseif score >= 50 then
		return 2
	end
	return 1
end

local function hasAffordablePrototypeFromNode(nodeKey: string, budget: number): boolean
	local node = DecisionTreeData.Nodes[nodeKey]
	if not node then
		return false
	end
	for choiceKey, choice in pairs(node.Choices) do
		if node.Stage == 4 then
			local prototype = DecisionTreeData.Prototypes[choiceKey]
			if prototype and prototype.Cost <= budget then
				return true
			end
		elseif hasAffordablePrototypeFromNode(choice.NextNode, budget) then
			return true
		end
	end
	return false
end

local function buildRiskNote(pathRiskTags: { [string]: boolean }, prototype: any, patch: any?, pivotBlockedByBudget: boolean): string
	local notes: { string } = {}
	if pathRiskTags.PROCESS_BIAS then
		table.insert(notes, DecisionTreeData.RiskDescriptions.PROCESS_BIAS)
	end
	if pathRiskTags.DISTRACTION then
		table.insert(notes, DecisionTreeData.RiskDescriptions.DISTRACTION)
	end
	if pathRiskTags.ACCESSIBILITY then
		if patch and patch.ResolvesRiskTags.ACCESSIBILITY == true then
			table.insert(notes, "Risiko aksesibilitas pada jalur awal telah dimitigasi.")
		else
			table.insert(notes, DecisionTreeData.RiskDescriptions.ACCESSIBILITY)
		end
	end
	if patch then
		table.insert(notes, "Mitigasi diterapkan: " .. patch.Name .. ".")
	else
		table.insert(notes, prototype.SafetyRiskDescription)
	end
	if pivotBlockedByBudget then
		table.insert(notes, "Saldo setelah salvage tidak cukup untuk membeli prototipe yang terjangkau pada putaran baru; iterasi tidak dapat dilanjutkan.")
	end
	return table.concat(notes, " ")
end

function EvaluationService.EvaluateFullSession(
	pathHistory: { string },
	prototypeKey: string,
	remainingBudget: number,
	isPatched: boolean?
): FullReport
	if typeof(remainingBudget) ~= "number" or remainingBudget % 1 ~= 0
		or remainingBudget < 0 or remainingBudget > DecisionTreeData.Constants.InitialBudget then
		error("Saldo evaluasi di luar rentang yang diizinkan")
	end
	if #pathHistory ~= 3 then
		error(string.format("Riwayat keputusan harus berisi tiga pilihan tahap 1-3; ditemukan %d", #pathHistory))
	end

	local score = 0
	local currentNodeKey = DecisionTreeData.Constants.RootNode
	local pathRiskTags: { [string]: boolean } = {}
	for index, choiceKey in ipairs(pathHistory) do
		local node = DecisionTreeData.Nodes[currentNodeKey]
		if not node or node.Stage ~= index then
			error(string.format("Urutan node tidak sah pada pilihan ke-%d", index))
		end
		local choice = node.Choices[choiceKey]
		if not choice then
			error(string.format("Pilihan %s bukan anak sah dari node %s", tostring(choiceKey), currentNodeKey))
		end
		score += choice.Points
		if choice.RiskTag ~= "NONE" then
			pathRiskTags[choice.RiskTag] = true
		end
		currentNodeKey = choice.NextNode
	end

	local prototype = DecisionTreeData.Prototypes[prototypeKey]
	if not prototype then
		error("Prototipe tidak terdaftar: " .. tostring(prototypeKey))
	end
	local prototypeNode = DecisionTreeData.Nodes[currentNodeKey]
	if not prototypeNode or prototypeNode.Stage ~= 4 or not prototypeNode.Choices[prototypeKey] then
		error(string.format("Prototipe %s tidak tersedia setelah jalur yang dipilih", prototypeKey))
	end
	if prototype.ParentChoiceId ~= pathHistory[3] then
		error(string.format("Induk prototipe %s tidak sesuai dengan pilihan ideate terakhir", prototypeKey))
	end
	if prototypeNode.Choices[prototypeKey].Points ~= prototype.Points then
		error("Poin pilihan prototipe dan metadata prototipe tidak sama: " .. prototypeKey)
	end
	score += prototype.Points
	if score < 40 or score > 100 then
		error(string.format("Skor desain %d di luar rentang 40-100", score))
	end

	local hasFatalRisk = pathRiskTags.DISTRACTION == true or prototype.SafetyRating == "FAIL"
	local hasConditionalRisk = pathRiskTags.ACCESSIBILITY == true or prototype.SafetyRating == "CONDITIONAL"
	local safetyStatus: SafetyStatus = "PASS"
	if hasFatalRisk then
		safetyStatus = "FAIL"
	elseif hasConditionalRisk then
		safetyStatus = "CONDITIONAL"
	end

	local patch = prototype.QuickPatch
	local patchResolvesPathRisk = not pathRiskTags.ACCESSIBILITY
	if pathRiskTags.ACCESSIBILITY then
		patchResolvesPathRisk = patch ~= nil and patch.ResolvesRiskTags.ACCESSIBILITY == true
	end
	local canApplyPatch = safetyStatus == "CONDITIONAL"
		and patch ~= nil
		and patchResolvesPathRisk
		and remainingBudget >= patch.Cost

	local appliedPatch: any? = nil
	if isPatched == true then
		if safetyStatus ~= "CONDITIONAL" or not patch or not patchResolvesPathRisk then
			error("Quick Patch tidak dapat diterapkan pada risiko desain ini")
		end
		appliedPatch = patch
		safetyStatus = "PASS"
	end

	local stars = getBaseStarRating(score)
	if safetyStatus == "FAIL" then
		stars = math.min(stars, 2)
	elseif safetyStatus == "CONDITIONAL" then
		stars = math.min(stars, 3)
	end

	local title: string
	if isPatched == true then
		title = "DESAIN DIPERBAIKI MELALUI QUICK PATCH"
	elseif safetyStatus == "FAIL" then
		title = "KEGAGALAN KRITIS: DESAIN MEMBAHAYAKAN KESELAMATAN SISWA"
	elseif safetyStatus == "CONDITIONAL" then
		title = "SOLUSI BERSYARAT: MASIH ADA RISIKO KESELAMATAN YANG PERLU DIMINIMALKAN"
	elseif score == 100 then
		title = "MASTER OF FRUGAL INNOVATION (DESAIN SEMPURNA)"
	elseif score >= 85 then
		title = "DESAIN EFEKTIF DAN AMAN"
	elseif score >= 65 then
		title = "SOLUSI AMAN, MASIH DAPAT DIITERASI"
	else
		title = "SOLUSI AMAN DENGAN SKOR PROSES AWAL"
	end

	local projectedPivotBudget = remainingBudget + math.floor(prototype.Cost * 0.5)
	local pivotHasAffordableRoute = hasAffordablePrototypeFromNode("Stage2_From1B", projectedPivotBudget)
	local canDeepPivot = stars < 5 and pivotHasAffordableRoute
	local pivotBlockedByBudget = stars < 5 and not pivotHasAffordableRoute
	local mustDeepPivot = safetyStatus == "FAIL" and canDeepPivot
	local statement = if appliedPatch then appliedPatch.RaniFeedback else prototype.RaniFeedback
	return {
		ScoreDT = score,
		SafetyStatus = safetyStatus,
		StarRating = stars,
		RemainingBudget = remainingBudget,
		VerdictTitle = title,
		UserNeedAddressed = prototype.UserNeedAddressed,
		CriticalRiskNote = buildRiskNote(pathRiskTags, prototype, appliedPatch, pivotBlockedByBudget),
		RaniStatement = statement,
		SelectedPrototypeKey = prototypeKey,
		IsPatched = appliedPatch ~= nil,
		CanQuickPatch = isPatched ~= true and canApplyPatch,
		CanDeepPivot = canDeepPivot,
		MustDeepPivot = mustDeepPivot,
		PivotBlockedByBudget = pivotBlockedByBudget,
	}
end

return EvaluationService
