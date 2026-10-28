--!strict
-- CrossSafe: pohon keputusan, biaya, risiko, dan data prototipe.
-- 15 node pertanyaan/state + 30 sisi pilihan + 16 daun prototipe.

export type SafetyRating = "PASS" | "CONDITIONAL" | "FAIL"
export type RiskTag = "NONE" | "PROCESS_BIAS" | "ACCESSIBILITY" | "DISTRACTION"

export type Choice = {
	Text: string,
	Points: number,
	RiskTag: RiskTag,
	NextNode: string,
}

export type DecisionNode = {
	Stage: number,
	Prompt: string,
	Choices: { [string]: Choice },
}

export type QuickPatch = {
	Name: string,
	Cost: number,
	ModelName: string,
	ResolvesRiskTags: { [string]: boolean },
	RaniFeedback: string,
}

export type Prototype = {
	ParentChoiceId: string,
	Name: string,
	Cost: number,
	Points: number,
	SafetyRating: SafetyRating,
	ModelName: string,
	UserNeedAddressed: string,
	SafetyRiskDescription: string,
	RaniFeedback: string,
	QuickPatch: QuickPatch?,
}

local Nodes: { [string]: DecisionNode } = {
	["Stage1_Root"] = {
		Stage = 1,
		Prompt = "Rani terlihat cemas di pinggir jalan raya depan sekolah. Bagaimana tim memulai penyelidikan?",
		Choices = {
			["1.A"] = {
				Text = "Bertanya kepada pengendara: 'Kenapa kalian selalu melaju kencang di depan sekolah?'",
				Points = 10,
				RiskTag = "PROCESS_BIAS",
				NextNode = "Stage2_From1A",
			},
			["1.B"] = {
				Text = "Bertanya kepada Rani: 'Apa momen yang paling membuatmu ragu saat hendak menyeberang?'",
				Points = 25,
				RiskTag = "NONE",
				NextNode = "Stage2_From1B",
			},
		},
	},
	["Stage2_From1A"] = {
		Stage = 2,
		Prompt = "Berdasarkan pengamatan awal, bagaimana tim merumuskan masalah?",
		Choices = {
			["2.A1"] = {
				Text = "Pengendara motor tidak memiliki etika dan sengaja mengabaikan keselamatan siswa.",
				Points = 10,
				RiskTag = "PROCESS_BIAS",
				NextNode = "Stage3_From2A1",
			},
			["2.A2"] = {
				Text = "Jalan yang lurus dan mulus tidak memberi isyarat fisik yang cukup untuk memperlambat kendaraan.",
				Points = 25,
				RiskTag = "NONE",
				NextNode = "Stage3_From2A2",
			},
		},
	},
	["Stage2_From1B"] = {
		Stage = 2,
		Prompt = "Rani takut terjebak di tengah jalan empat lajur. Kebutuhan apa yang perlu dijawab?",
		Choices = {
			["2.B1"] = {
				Text = "Siswa perlu dipisahkan dari bidang aspal karena kendaraan dan pejalan kaki berbagi ruang.",
				Points = 10,
				RiskTag = "PROCESS_BIAS",
				NextNode = "Stage3_From2B1",
			},
			["2.B2"] = {
				Text = "Rani membutuhkan kepastian hak dan waktu menyeberang tanpa harus menebak laju kendaraan.",
				Points = 25,
				RiskTag = "NONE",
				NextNode = "Stage3_From2B2",
			},
		},
	},
	["Stage3_From2A1"] = {
		Stage = 3,
		Prompt = "Bagaimana merespons dugaan bahwa pengendara mengabaikan aturan?",
		Choices = {
			["3.A1a"] = {
				Text = "Memasang spanduk peringatan berukuran besar di atas jalan.",
				Points = 10,
				RiskTag = "PROCESS_BIAS",
				NextNode = "Stage4_From3A1a",
			},
			["3.A1b"] = {
				Text = "Memasang pita kejut berulang sebelum zebra cross agar pengendara mendapat isyarat getaran.",
				Points = 25,
				RiskTag = "NONE",
				NextNode = "Stage4_From3A1b",
			},
		},
	},
	["Stage3_From2A2"] = {
		Stage = 3,
		Prompt = "Bagaimana merekayasa perlambatan kendaraan dengan lebih aman?",
		Choices = {
			["3.A2a"] = {
				Text = "Membangun polisi tidur aspal tajam setinggi 15 cm di badan jalan.",
				Points = 10,
				RiskTag = "PROCESS_BIAS",
				NextNode = "Stage4_From3A2a",
			},
			["3.A2b"] = {
				Text = "Membangun speed table landai dan rata dengan jalur penyeberangan.",
				Points = 25,
				RiskTag = "NONE",
				NextNode = "Stage4_From3A2b",
			},
		},
	},
	["Stage3_From2B1"] = {
		Stage = 3,
		Prompt = "Bagaimana menyediakan lintasan yang dapat benar-benar digunakan siswa?",
		Choices = {
			["3.B1a"] = {
				Text = "Membangun JPO dengan tangga tegak yang memindahkan pejalan kaki dari jalan.",
				Points = 10,
				RiskTag = "ACCESSIBILITY",
				NextNode = "Stage4_From3B1a",
			},
			["3.B1b"] = {
				Text = "Membangun JPO dengan ramp landai yang lebih mudah diakses.",
				Points = 25,
				RiskTag = "NONE",
				NextNode = "Stage4_From3B1b",
			},
		},
	},
	["Stage3_From2B2"] = {
		Stage = 3,
		Prompt = "Bagaimana memberi Rani kepastian tanpa mengalihkan perhatiannya dari jalan?",
		Choices = {
			["3.B2a"] = {
				Text = "Mengembangkan aplikasi ponsel CrossSmart dengan peta dan panduan saat menyeberang.",
				Points = 10,
				RiskTag = "DISTRACTION",
				NextNode = "Stage4_From3B2a",
			},
			["3.B2b"] = {
				Text = "Memasang tiang antarmuka publik dengan tombol fisik dan sinyal penyeberangan.",
				Points = 25,
				RiskTag = "NONE",
				NextNode = "Stage4_From3B2b",
			},
		},
	},
	["Stage4_From3A1a"] = {
		Stage = 4,
		Prompt = "Pilih prototipe untuk gagasan spanduk peringatan visual:",
		Choices = {
			["P.01"] = { Text = "Spanduk kain + lampu sorot putih (Rp 2.500.000)", Points = 10, RiskTag = "NONE", NextNode = "TERMINAL" },
			["P.02"] = { Text = "Rambu LED hazard kuning tenaga surya (Rp 4.500.000)", Points = 25, RiskTag = "NONE", NextNode = "TERMINAL" },
		},
	},
	["Stage4_From3A1b"] = {
		Stage = 4,
		Prompt = "Pilih prototipe untuk pita kejut jalan:",
		Choices = {
			["P.03"] = { Text = "Cat marka putih biasa (Rp 1.500.000)", Points = 10, RiskTag = "NONE", NextNode = "TERMINAL" },
			["P.04"] = { Text = "Pita termoplastik merah kasar antiselip (Rp 3.500.000)", Points = 25, RiskTag = "NONE", NextNode = "TERMINAL" },
		},
	},
	["Stage4_From3A2a"] = {
		Stage = 4,
		Prompt = "Pilih prototipe untuk peninggian jalan:",
		Choices = {
			["P.05"] = { Text = "Gundukan aspal tajam tanpa cat (Rp 2.000.000)", Points = 10, RiskTag = "NONE", NextNode = "TERMINAL" },
			["P.06"] = { Text = "Speed bump karet kuning-hitam dengan reflektor (Rp 4.000.000)", Points = 25, RiskTag = "NONE", NextNode = "TERMINAL" },
		},
	},
	["Stage4_From3A2b"] = {
		Stage = 4,
		Prompt = "Pilih prototipe untuk speed table penyeberangan:",
		Choices = {
			["P.07"] = { Text = "Speed table curam tanpa drainase (Rp 5.000.000)", Points = 10, RiskTag = "NONE", NextNode = "TERMINAL" },
			["P.08"] = { Text = "Paving berpori landai dengan rasio 1:10 (Rp 7.500.000)", Points = 25, RiskTag = "NONE", NextNode = "TERMINAL" },
		},
	},
	["Stage4_From3B1a"] = {
		Stage = 4,
		Prompt = "Pilih prototipe untuk JPO bertangga:",
		Choices = {
			["P.09"] = { Text = "JPO tangga tegak terbuka (Rp 6.000.000)", Points = 10, RiskTag = "NONE", NextNode = "TERMINAL" },
			["P.10"] = { Text = "JPO tangga dengan kanopi (Rp 8.000.000)", Points = 25, RiskTag = "NONE", NextNode = "TERMINAL" },
		},
	},
	["Stage4_From3B1b"] = {
		Stage = 4,
		Prompt = "Pilih prototipe untuk JPO ramp:",
		Choices = {
			["P.11"] = { Text = "JPO ramp terbuka tanpa peneduh (Rp 7.000.000)", Points = 10, RiskTag = "NONE", NextNode = "TERMINAL" },
			["P.12"] = { Text = "JPO ramp dengan kanopi dan lampu surya (Rp 9.500.000)", Points = 25, RiskTag = "NONE", NextNode = "TERMINAL" },
		},
	},
	["Stage4_From3B2a"] = {
		Stage = 4,
		Prompt = "Pilih prototipe aplikasi CrossSmart:",
		Choices = {
			["P.13"] = { Text = "Aplikasi peta berbasis teks (Rp 3.000.000)", Points = 10, RiskTag = "DISTRACTION", NextNode = "TERMINAL" },
			["P.14"] = { Text = "Aplikasi dengan suara dan radar bus (Rp 6.000.000)", Points = 25, RiskTag = "DISTRACTION", NextNode = "TERMINAL" },
		},
	},
	["Stage4_From3B2b"] = {
		Stage = 4,
		Prompt = "Pilih prototipe untuk tiang antarmuka trotoar:",
		Choices = {
			["P.15"] = { Text = "Tiang tombol biasa + lampu tanpa angka (Rp 4.000.000)", Points = 10, RiskTag = "NONE", NextNode = "TERMINAL" },
			["P.16"] = { Text = "Tiang tombol taktil + hitung mundur + bip (Rp 6.500.000)", Points = 25, RiskTag = "NONE", NextNode = "TERMINAL" },
		},
	},
}

local Prototypes: { [string]: Prototype } = {
	["P.01"] = {
		ParentChoiceId = "3.A1a", Name = "Spanduk kain + lampu sorot LED putih", Cost = 2500000, Points = 10,
		SafetyRating = "FAIL", ModelName = "Proto_P01_BannerLight",
		UserNeedAddressed = "Visibilitas zona sekolah pada malam hari.",
		SafetyRiskDescription = "Lampu putih yang menyilaukan dapat mengganggu pandangan pengendara dan memicu kecelakaan.",
		RaniFeedback = "Kak, lampunya menyilaukan! Mobil tadi oleng dan hampir menabrak tiang trotoar!",
	},
	["P.02"] = {
		ParentChoiceId = "3.A1a", Name = "Rambu LED hazard kuning tenaga surya", Cost = 4500000, Points = 25,
		SafetyRating = "CONDITIONAL", ModelName = "Proto_P02_HazardSolar",
		UserNeedAddressed = "Peringatan visual yang terlihat tanpa menyilaukan.",
		SafetyRiskDescription = "Rambu bersifat pasif; pengendara yang terburu-buru dapat mengabaikannya.",
		RaniFeedback = "Rambunya terlihat jelas, tetapi beberapa motor tetap melaju cepat.",
		QuickPatch = { Name = "Tambahkan marka pengurang kecepatan", Cost = 2000000, ModelName = "Patch_P02_RumbleStrip", ResolvesRiskTags = {}, RaniFeedback = "Marka tambahannya membuat pengendara lebih sadar untuk memperlambat laju." },
	},
	["P.03"] = {
		ParentChoiceId = "3.A1b", Name = "Cat marka putih biasa", Cost = 1500000, Points = 10,
		SafetyRating = "FAIL", ModelName = "Proto_P03_PaintLine",
		UserNeedAddressed = "Penandaan zebra cross dengan biaya rendah.",
		SafetyRiskDescription = "Cat yang licin saat basah dapat membuat pengendara motor tergelincir ketika mengerem.",
		RaniFeedback = "Saat gerimis, seorang pengendara tergelincir di marka cat. Itu membuatku takut.",
	},
	["P.04"] = {
		ParentChoiceId = "3.A1b", Name = "Pita getar termoplastik merah kasar antiselip", Cost = 3500000, Points = 25,
		SafetyRating = "PASS", ModelName = "Proto_P04_RumbleStrip",
		UserNeedAddressed = "Memberi isyarat getar agar kendaraan melambat sebelum zebra cross.",
		SafetyRiskDescription = "Getaran memberi pengendara peringatan sebelum penyeberangan.",
		RaniFeedback = "Kendaraan melambat saat melewati pita getar. Aku jadi lebih berani melangkah.",
	},
	["P.05"] = {
		ParentChoiceId = "3.A2a", Name = "Gundukan aspal tajam 15 cm tanpa penanda", Cost = 2000000, Points = 10,
		SafetyRating = "FAIL", ModelName = "Proto_P05_SharpBump",
		UserNeedAddressed = "Memaksa kendaraan mengurangi kecepatan.",
		SafetyRiskDescription = "Gundukan tajam dapat merusak kendaraan dan membahayakan pengendara maupun kendaraan darurat.",
		RaniFeedback = "Warga protes karena ambulans terbentur gundukan dan barang di dalamnya jatuh.",
	},
	["P.06"] = {
		ParentChoiceId = "3.A2a", Name = "Speed bump karet kuning-hitam reflektor", Cost = 4000000, Points = 25,
		SafetyRating = "CONDITIONAL", ModelName = "Proto_P06_RubberBump",
		UserNeedAddressed = "Perlambatan kendaraan dengan penanda reflektif.",
		SafetyRiskDescription = "Tanpa penerangan tambahan, pejalan kaki masih sulit terlihat pada malam hari.",
		RaniFeedback = "Mobil melambat, tetapi malam hari masih terlalu gelap untuk melihatku.",
		QuickPatch = { Name = "Tambahkan lampu penerangan zona", Cost = 2000000, ModelName = "Patch_P06_Lighting", ResolvesRiskTags = {}, RaniFeedback = "Lampu tambahannya membantu pengendara melihat area penyeberangan pada malam hari." },
	},
	["P.07"] = {
		ParentChoiceId = "3.A2b", Name = "Speed table curam tanpa saluran drainase", Cost = 5000000, Points = 10,
		SafetyRating = "CONDITIONAL", ModelName = "Proto_P07_SteepTable",
		UserNeedAddressed = "Menyediakan lintasan datar bagi pejalan kaki.",
		SafetyRiskDescription = "Tanpa drainase, air hujan dapat menggenang dan menghalangi siswa menyeberang.",
		RaniFeedback = "Saat hujan air menggenang di depan zebra cross dan sepatuku basah.",
		QuickPatch = { Name = "Tambahkan saluran drainase", Cost = 2000000, ModelName = "Patch_P07_Drainage", ResolvesRiskTags = {}, RaniFeedback = "Saluran baru mengurangi genangan dan membuat lintasan lebih nyaman." },
	},
	["P.08"] = {
		ParentChoiceId = "3.A2b", Name = "Speed table paving berpori landai rasio 1:10", Cost = 7500000, Points = 25,
		SafetyRating = "PASS", ModelName = "Proto_P08_PavingTable",
		UserNeedAddressed = "Perlambatan bertahap, akses lebih landai, dan resapan air.",
		SafetyRiskDescription = "Permukaan landai memberi akses lebih nyaman dan membantu kendaraan melambat bertahap.",
		RaniFeedback = "Permukaannya rata dengan trotoar dan kendaraan melaju lebih pelan. Aku nyaman menyeberang.",
	},
	["P.09"] = {
		ParentChoiceId = "3.B1a", Name = "JPO tangga tegak terbuka 40 trap", Cost = 6000000, Points = 10,
		SafetyRating = "FAIL", ModelName = "Proto_P09_SteepBridge",
		UserNeedAddressed = "Memisahkan pejalan kaki dari jalan raya.",
		SafetyRiskDescription = "Tangga yang melelahkan membuat siswa berisiko menolak JPO dan menerobos jalan.",
		RaniFeedback = "Tangga ini melelahkan. Beberapa siswa memilih menerobos jalan karena takut terlambat.",
	},
	["P.10"] = {
		ParentChoiceId = "3.B1a", Name = "JPO tangga besi dengan kanopi", Cost = 8000000, Points = 25,
		SafetyRating = "CONDITIONAL", ModelName = "Proto_P10_CoveredStairs",
		UserNeedAddressed = "Mengurangi panas dan hujan saat melewati JPO.",
		SafetyRiskDescription = "Tangga beratap tetap tidak mudah digunakan oleh pengguna kursi roda atau siswa yang sulit menaiki tangga.",
		RaniFeedback = "Jembatannya teduh, tetapi temanku yang kakinya cedera tidak dapat menaiki tangga.",
		QuickPatch = { Name = "Tambahkan lift aksesibel pada JPO", Cost = 2000000, ModelName = "Patch_P10_AccessLift", ResolvesRiskTags = { ACCESSIBILITY = true }, RaniFeedback = "Lift tambahan membuat JPO lebih mudah diakses oleh teman-temanku." },
	},
	["P.11"] = {
		ParentChoiceId = "3.B1b", Name = "JPO ramp landai tanpa peneduh", Cost = 7000000, Points = 10,
		SafetyRating = "CONDITIONAL", ModelName = "Proto_P11_OpenRamp",
		UserNeedAddressed = "Menyediakan lintasan JPO yang lebih mudah diakses.",
		SafetyRiskDescription = "Ramp terbuka dapat menjadi licin saat hujan dan panas pada siang hari.",
		RaniFeedback = "Ramp mudah dilewati, tetapi sangat panas dan menyilaukan saat siang hari.",
		QuickPatch = { Name = "Tambahkan kanopi dan lapisan antiselip", Cost = 2000000, ModelName = "Patch_P11_Canopy", ResolvesRiskTags = {}, RaniFeedback = "Kanopi dan permukaan tambahan membuat ramp lebih nyaman saat panas maupun hujan." },
	},
	["P.12"] = {
		ParentChoiceId = "3.B1b", Name = "JPO ramp spiral dengan kanopi dan lampu surya", Cost = 9500000, Points = 25,
		SafetyRating = "PASS", ModelName = "Proto_P12_MasterBridge",
		UserNeedAddressed = "Lintasan inklusif yang terlindung cuaca dan terlihat pada malam hari.",
		SafetyRiskDescription = "Solusi aman tetapi memakai sebagian besar modal tim.",
		RaniFeedback = "Jembatannya teduh dan terasa aman. Aku bisa menyeberang tanpa khawatir kendaraan di bawah.",
	},
	["P.13"] = {
		ParentChoiceId = "3.B2a", Name = "Aplikasi CrossSmart berbasis peta teks", Cost = 3000000, Points = 10,
		SafetyRating = "FAIL", ModelName = "Proto_P13_AppBasic",
		UserNeedAddressed = "Informasi penyeberangan melalui ponsel.",
		SafetyRiskDescription = "Membaca ponsel di dekat jalan mengalihkan perhatian dan mengurangi kewaspadaan situasional.",
		RaniFeedback = "Saat membaca layar HP, aku hampir terserempet motor dari samping!",
	},
	["P.14"] = {
		ParentChoiceId = "3.B2a", Name = "Aplikasi CrossSmart dengan suara dan radar bus", Cost = 6000000, Points = 25,
		SafetyRating = "FAIL", ModelName = "Proto_P14_AppAdvanced",
		UserNeedAddressed = "Panduan digital penyeberangan personal.",
		SafetyRiskDescription = "Layar atau audio ponsel dapat mengalihkan pandangan atau pendengaran dari bahaya lalu lintas.",
		RaniFeedback = "Suara aplikasi jelas, tetapi perhatianku teralihkan dari jalan saat motor berbelok.",
	},
	["P.15"] = {
		ParentChoiceId = "3.B2b", Name = "Tiang tombol mekanik + lampu simbol statis", Cost = 4000000, Points = 10,
		SafetyRating = "CONDITIONAL", ModelName = "Proto_P15_BasicPole",
		UserNeedAddressed = "Antarmuka fisik untuk meminta giliran menyeberang.",
		SafetyRiskDescription = "Tanpa informasi durasi, pejalan kaki masih ragu apakah waktu aman cukup untuk menyeberang.",
		RaniFeedback = "Tombolnya berfungsi, tetapi aku masih khawatir lampu berubah saat aku di tengah jalan.",
		QuickPatch = { Name = "Tambahkan layar hitung mundur dan audio bip", Cost = 2000000, ModelName = "Patch_P15_Countdown", ResolvesRiskTags = {}, RaniFeedback = "Angka hitung mundur dan bip membuatku lebih yakin kapan harus menyeberang." },
	},
	["P.16"] = {
		ParentChoiceId = "3.B2b", Name = "Tiang tombol kuning taktil + hitung mundur + audio bip", Cost = 6500000, Points = 25,
		SafetyRating = "PASS", ModelName = "Proto_P16_MasterPole",
		UserNeedAddressed = "Kepastian waktu melalui antarmuka visual, audio, dan sentuhan.",
		SafetyRiskDescription = "Tombol mudah dikenali dan hitung mundur memberi isyarat waktu yang jelas tanpa melihat ponsel.",
		RaniFeedback = "Tombol kuningnya mudah ditemukan dan angka mundurnya membuatku tenang untuk melangkah.",
	},
}

local Constants = {
	RootNode = "Stage1_Root",
	TerminalNode = "TERMINAL",
	InitialBudget = 10000000,
	VoteDurationSeconds = 60,
	ExpectedQuestionNodes = 15,
	ExpectedChoiceEdges = 30,
	ExpectedPrototypeLeaves = 16,
}

local RiskDescriptions = {
	PROCESS_BIAS = "Pilihan ini menunjukkan asumsi atau rumusan masalah yang belum berpusat pada bukti kebutuhan Rani.",
	ACCESSIBILITY = "Solusi berisiko tidak dapat digunakan oleh semua pejalan kaki.",
	DISTRACTION = "Menggunakan layar atau audio ponsel di dekat jalan dapat mengalihkan perhatian dari lalu lintas.",
}

-- Pemeriksaan relasi dipakai GameManager saat server mulai dan dapat dipanggil saat audit.
local function validateData(): (boolean, string?)
	local nodeCount = 0
	local edgeCount = 0
	local prototypeReferenceCount: { [string]: number } = {}
	local nodesByStage: { [number]: number } = {}
	local expectedNodesByStage: { [number]: number } = { [1] = 1, [2] = 2, [3] = 4, [4] = 8 }

	for nodeKey, node in pairs(Nodes) do
		nodeCount += 1
		if node.Stage < 1 or node.Stage > 4 then
			return false, string.format("Nomor tahap tidak valid pada node %s", nodeKey)
		end
		nodesByStage[node.Stage] = (nodesByStage[node.Stage] or 0) + 1
		local choicesInNode = 0
		for choiceKey, choice in pairs(node.Choices) do
			edgeCount += 1
			choicesInNode += 1
			if node.Stage < 4 then
				local nextNode = Nodes[choice.NextNode]
				if not nextNode or nextNode.Stage ~= node.Stage + 1 then
					return false, string.format("Relasi node tidak valid: %s/%s -> %s", nodeKey, choiceKey, choice.NextNode)
				end
			else
				local prototype = Prototypes[choiceKey]
				if choice.NextNode ~= Constants.TerminalNode or not prototype then
					return false, string.format("Daun prototipe tidak valid pada %s/%s", nodeKey, choiceKey)
				end
				if prototype.Points ~= choice.Points then
					return false, string.format("Poin pilihan dan prototipe berbeda untuk %s", choiceKey)
				end
				if prototype.Cost <= 0 or prototype.Cost % 1 ~= 0 or prototype.Cost > Constants.InitialBudget then
					return false, string.format("Biaya prototipe tidak valid untuk %s", choiceKey)
				end
				if (prototype.SafetyRating == "CONDITIONAL") ~= (prototype.QuickPatch ~= nil) then
					return false, string.format("Paket Quick Patch harus tersedia tepat untuk prototipe CONDITIONAL: %s", choiceKey)
				end
				if prototype.QuickPatch and prototype.QuickPatch.Cost ~= 2000000 then
					return false, string.format("Biaya Quick Patch harus Rp2.000.000 untuk %s", choiceKey)
				end
				prototypeReferenceCount[choiceKey] = (prototypeReferenceCount[choiceKey] or 0) + 1
			end
		end
		if choicesInNode ~= 2 then
			return false, string.format("Node %s harus memiliki dua pilihan; ditemukan %d", nodeKey, choicesInNode)
		end
	end

	if nodeCount ~= Constants.ExpectedQuestionNodes then
		return false, string.format("Jumlah node %d; seharusnya %d", nodeCount, Constants.ExpectedQuestionNodes)
	end
	if edgeCount ~= Constants.ExpectedChoiceEdges then
		return false, string.format("Jumlah sisi pilihan %d; seharusnya %d", edgeCount, Constants.ExpectedChoiceEdges)
	end
	for stage, expectedCount in pairs(expectedNodesByStage) do
		if nodesByStage[stage] ~= expectedCount then
			return false, string.format("Jumlah node tahap %d adalah %d; seharusnya %d", stage, nodesByStage[stage] or 0, expectedCount)
		end
	end

	local prototypeCount = 0
	for prototypeKey, prototype in pairs(Prototypes) do
		prototypeCount += 1
		if prototypeReferenceCount[prototypeKey] ~= 1 then
			return false, string.format("Prototipe %s harus muncul tepat sekali di node tahap 4", prototypeKey)
		end
		local parentMatches = false
		for _, stage3Node in pairs(Nodes) do
			if stage3Node.Stage == 3 then
				local parentChoice = stage3Node.Choices[prototype.ParentChoiceId]
				local stage4Node = parentChoice and Nodes[parentChoice.NextNode]
				if stage4Node and stage4Node.Stage == 4 and stage4Node.Choices[prototypeKey] then
					parentMatches = true
					break
				end
			end
		end
		if not parentMatches then
			return false, string.format("Induk prototipe %s tidak cocok dengan pilihan %s", prototypeKey, prototype.ParentChoiceId)
		end
	end
	if prototypeCount ~= Constants.ExpectedPrototypeLeaves then
		return false, string.format("Jumlah prototipe %d; seharusnya %d", prototypeCount, Constants.ExpectedPrototypeLeaves)
	end

	local visited: { [string]: boolean } = {}
	local queue = { Constants.RootNode }
	local queueIndex = 1
	while queueIndex <= #queue do
		local currentKey = queue[queueIndex]
		queueIndex += 1
		if not visited[currentKey] then
			visited[currentKey] = true
			local currentNode = Nodes[currentKey]
			if currentNode and currentNode.Stage < 4 then
				for _, choice in pairs(currentNode.Choices) do
					table.insert(queue, choice.NextNode)
				end
			end
		end
	end
	for nodeKey in pairs(Nodes) do
		if not visited[nodeKey] then
			return false, string.format("Node tidak dapat dicapai dari root: %s", nodeKey)
		end
	end

	return true, nil
end

local DecisionTreeData = {
	Constants = Constants,
	Nodes = Nodes,
	Prototypes = Prototypes,
	RiskDescriptions = RiskDescriptions,
	Validate = validateData,
}

return DecisionTreeData
