--!strict
-- ModuleScript di ServerScriptService. Menghitung skor dari jalur sah, lalu menerapkan Safety Gate.
local EvaluationService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DecisionTreeData = require(ReplicatedStorage:WaitForChild("DecisionTreeData"))

export type SafetyStatus = "PASS" | "CONDITIONAL" | "FAIL"

-- [UPGRADE] Tipe data metrik evaluasi multidimensi
export type MultidimensionalScores = {
	SafetyIndex: number,      -- 0-100%
	TrafficCongestion: number, -- 0-100%
	InclusivityScore: number,  -- 0-100%
	BudgetEfficiency: number,  -- 0-100%
}

-- [UPGRADE] Catatan kualitatif per dimensi evaluasi
export type DimensionNotes = {
	SafetyNote: string,
	TrafficNote: string,
	InclusivityNote: string,
	BudgetNote: string,
}

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
	-- [UPGRADE] Field metrik dan narasi multidimensi
	MultidimensionalScores: MultidimensionalScores,
	DimensionNotes: DimensionNotes,
	ReportSummary: string,
}

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

-- [UPGRADE] Fungsi kalkulasi multidimensi sesuai metodologi Design Thinking
function EvaluationService.CalculateMultidimensionalScores(
	prototype: any,
	pathRiskTags: { [string]: boolean },
	remainingBudget: number,
	isPatched: boolean?,
	safetyStatus: SafetyStatus
): (MultidimensionalScores, DimensionNotes, string)
	local baseSafety = prototype.BaseSafetyScore or 50
	local baseTraffic = prototype.TrafficImpact or 30
	local baseInclusivity = prototype.InclusivityScore or 50

	-- 1. Perhitungan SafetyIndex (0 - 100)
	local safetyIndex = baseSafety
	if pathRiskTags.PROCESS_BIAS then
		safetyIndex -= 5
	end
	if pathRiskTags.DISTRACTION or safetyStatus == "FAIL" then
		safetyIndex = math.min(safetyIndex, 40)
	end
	if isPatched then
		safetyIndex = math.min(100, safetyIndex + 20)
	end
	safetyIndex = math.clamp(math.round(safetyIndex), 0, 100)

	-- 2. Perhitungan TrafficCongestion (0 - 100)
	local trafficCongestion = baseTraffic
	if isPatched and prototype.QuickPatch and prototype.QuickPatch.ModelName == "Patch_P02_RumbleStrip" then
		trafficCongestion += 5
	end
	trafficCongestion = math.clamp(math.round(trafficCongestion), 0, 100)

	-- 3. Perhitungan InclusivityScore (0 - 100)
	local inclusivityScore = baseInclusivity
	if pathRiskTags.ACCESSIBILITY then
		if isPatched and prototype.QuickPatch and prototype.QuickPatch.ResolvesRiskTags and prototype.QuickPatch.ResolvesRiskTags.ACCESSIBILITY == true then
			inclusivityScore = math.max(inclusivityScore, 85)
		else
			inclusivityScore = math.min(inclusivityScore, 30)
		end
	elseif isPatched and prototype.QuickPatch and prototype.QuickPatch.ModelName == "Patch_P11_Canopy" then
		inclusivityScore = math.min(100, inclusivityScore + 15)
	end
	inclusivityScore = math.clamp(math.round(inclusivityScore), 0, 100)

	-- 4. Perhitungan BudgetEfficiency (0 - 100)
	local initialBudget = DecisionTreeData.Constants.InitialBudget
	local budgetEfficiency = math.clamp(math.round((remainingBudget / initialBudget) * 100), 0, 100)

	-- Teks narasi evaluasi per dimensi
	local safetyNote: string
	if safetyIndex >= 80 then
		safetyNote = "Proteksi pejalan kaki sangat tinggi; meminimalisir risiko benturan dengan kendaraan."
	elseif safetyIndex >= 50 then
		safetyNote = "Proteksi pejalan kaki memadai, namun pengendara masih membutuhkan kewaspadaan situasional."
	else
		safetyNote = "Tingkat keselamatan kritis; desain memicu distraksi atau bahaya silau bagi penyeberang."
	end

	local trafficNote: string
	if trafficCongestion <= 20 then
		trafficNote = "Lalu lintas mengalir sangat lancar tanpa hambatan berarti bagi kendaraan umum/darurat."
	elseif trafficCongestion <= 50 then
		trafficNote = "Lalu lintas melambat secara teratur dan terkendali di sekitar zona sekolah."
	else
		trafficNote = "Hambatan lalu lintas tinggi; berpotensi menimbulkan kemacetan atau mengganggu ambulans."
	end

	local inclusivityNote: string
	if inclusivityScore >= 80 then
		inclusivityNote = "Sangat ramah difabel, lansia, dan anak; akses bebas hambatan tangga curam."
	elseif inclusivityScore >= 45 then
		inclusivityNote = "Aksesibilitas moderat; masih terdapat tantangan bagi pengguna kursi roda atau pejalan kaki rentan."
	else
		inclusivityNote = "Aksesibilitas rendah; eksklusif bagi pengguna berkemampuan fisik penuh tanpa fasilitas ramah difabel."
	end

	local budgetNote: string
	if budgetEfficiency >= 50 then
		budgetNote = string.format("Efisiensi biaya sangat baik (Sisa: %s); hemat modal untuk pemeliharaan masa depan.", formatRupiah(remainingBudget))
	elseif budgetEfficiency >= 20 then
		budgetNote = string.format("Alokasi anggaran seimbang (Sisa: %s); proporsional terhadap infrastruktur fisik.", formatRupiah(remainingBudget))
	else
		budgetNote = string.format("Anggaran hampir habis (Sisa: %s); investasi modal intensif mendekati batas plafon.", formatRupiah(remainingBudget))
	end

	local scores: MultidimensionalScores = {
		SafetyIndex = safetyIndex,
		TrafficCongestion = trafficCongestion,
		InclusivityScore = inclusivityScore,
		BudgetEfficiency = budgetEfficiency,
	}

	local notes: DimensionNotes = {
		SafetyNote = safetyNote,
		TrafficNote = trafficNote,
		InclusivityNote = inclusivityNote,
		BudgetNote = budgetNote,
	}

	local reportSummary = string.format(
		"METRIK MULTIDIMENSI:\n" ..
		"• Safety Index: %d%% (%s)\n" ..
		"• Traffic Congestion: %d%% (%s)\n" ..
		"• Inclusivity Score: %d%% (%s)\n" ..
		"• Budget Efficiency: %d%% (%s)",
		scores.SafetyIndex, notes.SafetyNote,
		scores.TrafficCongestion, notes.TrafficNote,
		scores.InclusivityScore, notes.InclusivityNote,
		scores.BudgetEfficiency, notes.BudgetNote
	)

	return scores, notes, reportSummary
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

	-- [UPGRADE] Kalkulasi metrik multidimensi dan narasi diagnosis
	local multiScores, dimensionNotes, reportSummary = EvaluationService.CalculateMultidimensionalScores(
		prototype,
		pathRiskTags,
		remainingBudget,
		appliedPatch ~= nil,
		safetyStatus
	)

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
		-- [UPGRADE] Field metrik multidimensi & narasi baru
		MultidimensionalScores = multiScores,
		DimensionNotes = dimensionNotes,
		ReportSummary = reportSummary,
	}
end

return EvaluationService
