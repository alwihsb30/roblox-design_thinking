# CrossSafe — Implementasi dan Catatan Audit

Dokumen ini mencatat arsitektur sesi individu CrossSafe, relasi node/prototipe, validasi server, dan komponen Roblox Studio yang masih perlu dibuat.

## File dan penempatan di Roblox Studio

| File hasil | Jenis Roblox | Lokasi |
|---|---|---|
| `DecisionTreeData.lua` | ModuleScript | `ReplicatedStorage/DecisionTreeData` |
| `EvaluationService.lua` | ModuleScript | `ServerScriptService/EvaluationService` |
| `ClueQuestManager.lua` | ModuleScript | `ServerScriptService/ClueQuestManager` |
| `SpatialMissionManager.lua` | ModuleScript | `ServerScriptService/SpatialMissionManager` |
| `GameManager.lua` | Script | `ServerScriptService/GameManager` |
| `CrossSafeClient.client.lua` | LocalScript | `StarterGui/CrossSafeClient` |

`GameManager` membuat folder `ReplicatedStorage/GameNetwork` dan objek jaringan berikut saat server berjalan:

- `SubmitChoice` — RemoteEvent untuk mengirim `nodeKey` dan pilihan yang ingin diambil.
- `SyncGameState` — RemoteEvent untuk menerima prompt, hasil, dan status transaksi.
- `ChooseIteration` — RemoteEvent untuk memilih `QUICK_PATCH` atau `DEEP_PIVOT`.
- `StartSession` — RemoteEvent untuk memulai permainan setelah pemain berbicara dengan Rani; permintaan dicek jaraknya oleh server.
- `GetGameState` — RemoteFunction untuk mengambil status sesi saat pemain membuka UI di dekat Rani.

`ClueQuestManager` membuat prompt pada tiga Part bernama `Clue_Rambu`, `Clue_Marka`, dan `Clue_Penerangan` di `Workspace/InvestigationClues`. Klaim bukti dan progres disimpan oleh server sebagai progres per pemain tunggal pada server; setiap klaim unik menonaktifkan prompt dan dikirim melalui `SyncGameState` (`CLUE_FOUND`/`CLUE_PROGRESS`). `GameManager` menolak memulai sesi bila jumlah bukti belum 3/3, termasuk jika klien memanggil RemoteEvent langsung.

`SpatialMissionManager` membuat prompt server pada `WarRoom.Whiteboard`, `BlueprintStations.Station_A/Station_B`, `MaterialSupply.Crate`, dan `InteractionStation.PrototypeSlot`. Fase server berganti ke `MISSION` setelah Empathize dan Define; pilihan Ideate baru ditampilkan setelah setidaknya satu blueprint dipindai. Setelah pilihan Prototype, pembelian masuk ke ledger dan pemain harus membawa Tool server yang memiliki atribut `CrossSafeMaterial` ke slot. Model hanya dipasang sesudah Tool sah digunakan pada prompt slot. `SIMULATION` menjalankan `Humanoid:MoveTo()` untuk Rani, tween kendaraan pada server, serta lampu keselamatan sebelum `SHOW_EVALUATION_REPORT` dikirim. SubmitChoice dan StartSession tidak dapat melewati gerbang misi.

`CrossSafeClient.client.lua` menyediakan HUD misi permanen dan card temuan empat detik pada GUI terpisah dari panel pilihan. Panel pilihan mulai tersembunyi. Jika pemain berbicara dengan Rani sebelum misi lengkap, ia melihat penolakan serta progres dan tombol mulai tidak tersedia; setelah 3/3, interaksi berikutnya menampilkan tombol mulai. Saat UI dibuka lagi di dekat Rani, klien mengambil status melalui `GetGameState:InvokeServer()` dan menampilkan hanya ID yang ada di `AllowedChoiceKeys` atau `AllowedIterationActions`. Pemain memilih langsung dari panel. Pilihan tahap biasa dikirim melalui `SubmitChoice:FireServer(ActiveNodeKey, choiceId)`; Quick Patch dan Deep Pivot dikirim melalui `ChooseIteration:FireServer(action)`. Server memvalidasi fase, node aktif, cabang pilihan, anggaran, dan status Safety Gate sebelum memprosesnya. Klien juga menangani `RANI_GATEKEEPER`, `CLUE_FOUND`, dan `CLUE_PROGRESS` dari `SyncGameState`.

Selama `MISSION`/`SIMULATION`, Quest Tracker tetap terlihat dan panel pilihan disembunyikan. Blueprint mana pun memenuhi gate Ideate; hubungan node/choice tetap ditentukan pohon keputusan dan server. Setiap server hanya menampung satu pemain.

Data pilihan boleh dibaca klien untuk menampilkan teks, tetapi server tetap memeriksa node aktif, daftar pilihan yang diizinkan, jalur sebelumnya, biaya, saldo, dan tahap sesi. Jangan menerima skor atau saldo dari klien.

## Struktur pohon dan konsistensi data

Pohon memiliki **15 node pertanyaan/state**, **30 sisi pilihan**, dan **16 daun prototipe**:

- Tahap 1: 1 node dan 2 pilihan.
- Tahap 2: 2 node dan 4 pilihan.
- Tahap 3: 4 node dan 8 pilihan.
- Tahap 4: 8 node pemilihan prototipe dan 16 pilihan.

Dengan demikian “30” adalah jumlah sisi pilihan, bukan jumlah node pertanyaan. ID pada pilihan Tahap 1–3 menjadi `ParentChoiceId` bagi dua prototipe di bawahnya. Harga dan poin pada pilihan Tahap 4 disamakan dengan metadata prototipenya. `DecisionTreeData.Validate()` memeriksa jumlah, keterjangkauan node, transisi antartahap, induk prototipe, poin, dan batas biaya. `GameManager` menjalankan pemeriksaan itu saat mulai; server berhenti dengan pesan jelas bila tabel tidak konsisten.

Skor Design Thinking adalah empat keputusan, satu dari setiap tahap: masing-masing bernilai 10 atau 25, sehingga skor berada pada rentang 40–100. `PROCESS_BIAS` memengaruhi catatan pembelajaran, tetapi tidak otomatis menyatakan ada bahaya fisik. `ACCESSIBILITY` menghasilkan status keselamatan bersyarat; `DISTRACTION` menghasilkan status gagal. Status prototipe juga ikut diperiksa.

## Pilihan individu, anggaran, dan siklus iterasi

- Saldo awal pemain Rp10.000.000. Pembelian dan Quick Patch dicatat dalam ledger server; Deep Pivot mengembalikan 50% harga prototipe yang dijual. Biaya putaran sebelumnya dan biaya patch tetap tercatat.
- Tidak ada voting atau timer. Pemain memilih satu jawaban langsung pada setiap tahap; server memeriksa pilihan itu dan segera memindahkan sesi ke misi berikutnya.
- Quick Patch dan Deep Pivot dipilih langsung oleh pemain. Jika status `FAIL`, pilihan yang tersedia hanya Deep Pivot.
- Jika pemain keluar, status sesi dan progres misi direset sebelum pemain berikutnya masuk ke server yang sama. Sesi pemain tunggal tidak memakai voting atau antrean peserta.
- Setelah Deep Pivot, 50% harga prototipe lama masuk kembali ke saldo. Pemain kembali ke Tahap 2 dengan jawaban empati `1.B` dipertahankan, sehingga tahap Define dan seterusnya diulang dengan modal tersisa.
- Pilihan yang tidak memiliki prototipe terjangkau dari saldo saat ini disembunyikan server sejak tahap sebelumnya. Ini mencegah pemain terjebak setelah melakukan salvage.
- Deep Pivot juga diperiksa terhadap saldo proyeksi setelah pengembalian 50%. Jika tidak ada prototipe yang terjangkau pada putaran baru, sistem mengakhiri iterasi dengan laporan keselamatan dan catatan bahwa anggaran membatasi perbaikan.
- Status `FAIL` membatasi rating maksimal dua bintang dan mewajibkan Deep Pivot bila saldo setelah salvage masih cukup untuk membeli satu prototipe pada rute mulai Tahap 2. Jika iterasi sudah tidak mungkin didanai, laporan tetap menunjukkan `FAIL` dan maksimal dua bintang, tetapi menandai bahwa saldo menghalangi pivot. `CONDITIONAL` membatasi rating maksimal tiga bintang; Quick Patch tersedia bila prototipe memiliki paket patch dan saldo cukup. Status `PASS` memakai rating skor biasa.
- Quick Patch memerlukan Rp2.000.000, dicatat sekali, dan hanya dapat dipakai untuk risiko yang dinyatakan dapat diselesaikan oleh metadata prototipe. Patch mengubah status keselamatan, bukan skor metodologi. Jika skor belum lima bintang, Deep Pivot tetap dapat dipilih.
- Rating skor sebelum pembatas keselamatan: 1 bintang di bawah 50; 2 mulai 50; 3 mulai 65; 4 mulai 80; 5 mulai 95. Safety Gate membatasi bintang maksimal 2 untuk `FAIL` dan maksimal 3 untuk `CONDITIONAL`.

Game dirancang untuk satu pemain per server. GameManager menolak pemain kedua sebagai pengaman; atur Maximum Players menjadi 1 di pengaturan place. Progres dan saldo bersifat in-memory dan direset saat pemain keluar.

## Objek Studio untuk visual prototipe

Untuk menampilkan model terpilih, buat struktur berikut:

```text
ServerStorage
└── PrototypeModels (Folder)
    ├── Proto_P01_BannerLight (Model)
    ├── ... seluruh nama ModelName P.01–P.16 di DecisionTreeData.lua ...
    ├── Patch_P02_RumbleStrip (Model)
    ├── Patch_P06_Lighting (Model)
    ├── Patch_P07_Drainage (Model)
    ├── Patch_P10_AccessLift (Model)
    ├── Patch_P11_Canopy (Model)
    └── Patch_P15_Countdown (Model)

Workspace
└── InteractionStation (Model atau Folder)
    └── PrototypeSlot (BasePart)
```

Model prototipe sebaiknya memiliki pivot yang sesuai dengan titik pemasangan. `PrototypeSlot` diperlukan untuk misi angkut/rakit dan pemasangan. Jika model dekoratif belum ada di `ServerStorage.PrototypeModels`, GameManager menampilkan graybox berlabel. Model patch adalah overlay opsional untuk tampilan; evaluasi keselamatan patch tetap dikelola server.

Model `Workspace.Rani_NPC` memerlukan `Humanoid` dan `HumanoidRootPart` untuk simulasi, selain Part tempat prompt bicara. `Workspace.InvestigationClues` memerlukan tiga BasePart dengan nama yang sesuai. Untuk misi 2–5, sediakan `WarRoom.Whiteboard`, minimal satu `BlueprintStations.Station_A/Station_B`, `MaterialSupply.Crate`, `InteractionStation.PrototypeSlot`, `Crosswalk_Destination`, `Crosswalk_Entry`, dan folder `CrossSafeSimulation` dengan `SignalLamp`, `Vehicle_1`, `VehicleStop_1`, serta `VehiclePass_1`. Helper Command Bar membuat dua stasiun, dua mobil, dan semua marker default; posisi/wajah marker harus disesuaikan ke map. Jalur Rani perlu bebas penghalang dan rig tidak boleh Anchored.

`AssemblySound` dan `HornSound` dibuat tanpa `SoundId`; audio harus diisi dengan asset yang dapat diakses experience. Animasi kaget `CrossSafeFlinch` opsional; fallback-nya adalah lompat dan langkah mundur. Status `CONDITIONAL` memakai simulasi risiko seperti `FAIL`, tetapi Safety Gate dan laporan tetap menggunakan status asli dari EvaluationService.

## Asumsi rancangan yang dipakai

1. Jalur aplikasi ponsel (`3.B2a`, P.13, dan P.14) selalu gagal pada Safety Gate karena risiko distraksi di dekat lalu lintas, meski poin ide/prototipenya tinggi.
2. JPO bertangga pada `3.B1a` memiliki risiko aksesibilitas. P.10 dapat dimitigasi dengan patch akses lift; P.09 tetap gagal karena beban penggunaan membuat siswa berpotensi menolak JPO.
3. Paket Quick Patch spesifik untuk tiap prototipe bersyarat. Ini melengkapi spesifikasi yang hanya menyebut biaya patch Rp2 juta, tetapi tidak merinci risiko yang diperbaiki.
4. Deep Pivot mengulang dari Define dan mempertahankan pilihan wawancara empati `1.B`, sesuai mekanik “kembali ke Tahap 2” pada rancangan.
5. Ledger dan sesi bersifat in-memory. Data tidak bertahan setelah server Roblox ditutup; penyimpanan lintas sesi memerlukan DataStoreService dan kebijakan reset tambahan.

## Batas implementasi

Backend menyediakan data pilihan, ledger, evaluasi, iterasi, interaksi Rani, misi bukti, gate ruang, material/assembly, dan simulasi testing. `CrossSafeClient.client.lua` menyediakan Quest Tracker, notifikasi temuan, dan panel pilihan yang disembunyikan selama misi. Simulasi adalah graybox server-driven; NPC bergerak dengan `Humanoid:MoveTo`, mobil dipindahkan dengan tween model, dan jalur harus disusun di Studio. Implementasi belum memakai PathfindingService atau DataStore. Pemeriksaan runtime tetap perlu dilakukan di Roblox Studio dengan satu pemain.

