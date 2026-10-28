# Panduan Membuat CrossSafe di Roblox Studio

Panduan ini memakai enam ModuleScript/Script server dan satu `LocalScript` UI. Permainan memakai satu tim bersama per server, modal awal Rp10.000.000, Misi 1 pencarian bukti, misi fisik Pos Satpam dan Blueprint, pengangkutan material, perakitan prototipe, simulasi penyeberangan, Safety Gate, Quick Patch, dan Deep Pivot.

## 1. Siapkan project Roblox

1. Buka Roblox Studio dan buat project **Baseplate**.
2. Simpan project melalui **File → Save to Roblox** atau **Publish to Roblox**.
3. Tampilkan panel **Explorer**, **Properties**, dan **Output** melalui tab **View**. Explorer dipakai untuk membuat struktur objek; Properties untuk mengubah nama dan pengaturan objek; Output untuk melihat error dan peringatan.
4. Buat objek sesuai susunan berikut. Nama harus sama persis.

```text
ReplicatedStorage
└── DecisionTreeData (ModuleScript)

ServerScriptService
├── GameManager (Script)
├── ClueQuestManager (ModuleScript)
├── SpatialMissionManager (ModuleScript)
├── VotingHandler (ModuleScript)
└── EvaluationService (ModuleScript)

StarterGui
└── CrossSafeClient (LocalScript)

ServerStorage
└── PrototypeModels (Folder)                  [opsional untuk visual]

Workspace
├── Rani_NPC (Model)                          [wajib untuk memulai sesi]
├── InvestigationClues (Folder)                [wajib untuk misi awal]
│   ├── Clue_Rambu (Part)
│   ├── Clue_Marka (Part)
│   └── Clue_Penerangan (Part)
├── WarRoom (Folder)
│   └── Whiteboard (Part)
├── BlueprintStations (Folder)
│   ├── Station_A (Part)
│   └── Station_B (Part)
├── MaterialSupply (Folder)
│   └── Crate (Part)
├── InteractionStation (Model atau Folder)
│   └── PrototypeSlot (Part)
├── Crosswalk_Entry (Part)
├── Crosswalk_Destination (Part)
└── CrossSafeSimulation (Folder)
    ├── SignalLamp (Part + PointLight)
    ├── StopLine (Part)
    ├── Vehicle_1, Vehicle_2 (Model)
    ├── VehicleStop_1, VehicleStop_2 (Part marker)
    ├── VehiclePass_1, VehiclePass_2 (Part marker)
    └── HornSound (Sound)
```

Cara termudah membuat graybox adalah menjalankan `CreateInvestigationClues_CommandBar.lua` dan `CreateSpatialMissions_CommandBar.lua` di Command Bar saat mode Edit. Helper kedua menerima `InteractionStation` yang berupa Folder maupun Model. Roblox menjalankan `LocalScript` di `StarterGui` untuk tiap pemain. `GameManager` membuat `GameNetwork`, empat `RemoteEvent`, dan satu `RemoteFunction` otomatis ketika server dimulai; jangan buat salinan remotes secara manual. `GameManager`, `ClueQuestManager`, dan `SpatialMissionManager` membuat prompt pada objek yang sesuai. [Panduan lokasi script](https://create.roblox.com/docs/scripting/locations)

Jika project sudah memiliki `ScreenGui` CrossSafe lama atau salinan `CrossSafeClient` di `StarterPlayerScripts`, hapus/nonaktifkan duplikat itu. UI baru dibuat oleh LocalScript ini dan memulai dalam keadaan tersembunyi; GUI lama yang masih ada bisa tetap tampil terpisah.

## 2. Masukkan kode ke objek yang benar

Buka masing-masing file hasil dan salin seluruh isinya ke objek Studio yang namanya cocok:

- `DecisionTreeData.lua` → `ReplicatedStorage/DecisionTreeData`.
- `VotingHandler.lua` → `ServerScriptService/VotingHandler`.
- `EvaluationService.lua` → `ServerScriptService/EvaluationService`.
- `ClueQuestManager.lua` → `ServerScriptService/ClueQuestManager` (**ModuleScript**).
- `SpatialMissionManager.lua` → `ServerScriptService/SpatialMissionManager` (**ModuleScript**).
- `GameManager.lua` → `ServerScriptService/GameManager`.
- `CrossSafeClient.client.lua` → `StarterGui/CrossSafeClient`.

Hapus kode bawaan seperti `print("Hello world!")` sebelum menempel kode. Pastikan `DecisionTreeData` adalah **ModuleScript**, `GameManager` adalah **Script**, empat pengelola server lainnya adalah **ModuleScript**, dan file UI adalah **LocalScript**. Nama file di komputer boleh memiliki ekstensi `.lua` atau `.client.lua`; nama objek di Explorer mengikuti susunan di atas.

`CrossSafeClient` membuat Quest Tracker terus tampil; panel musyawarah dimulai tersembunyi. Setelah Misi 1 selesai, interaksi Rani memulai Tahap 1 Empathize. Sesudah itu pemain harus menuju papan satpam untuk membuka Define, membaca minimal satu blueprint untuk membuka Ideate, lalu memilih prototipe lewat voting. Prototipe baru dipasang setelah pemain mengambil Tool material dan merakitnya di `PrototypeSlot`. Rapor hanya dibuka sesudah simulasi Rani menyeberang. Untuk membuka voting yang sudah diizinkan lagi, dekati Rani; saat gerbang misi masih aktif prompt Rani hanya mengirim status tracker. Server menentukan pilihan tim, skor, biaya, status keselamatan, dan hasil iterasi. Remote Roblox memang dirancang untuk komunikasi klien-server; validasi penting tetap dilakukan di sisi server. [Dokumentasi RemoteEvent](https://create.roblox.com/docs/scripting/events/remote)

## 3. Siapkan Misi 1: Olah TKP

Misi bukti harus selesai sebelum voting Tahap 1 terbuka. Progres adalah progres satu tim per server: bila satu pemain menemukan bukti, semua pemain melihat jumlah yang sama.

Cara tercepat membuat folder dan tiga Part placeholder:

1. Di Roblox Studio, buka **View → Command Bar** dalam mode Edit (jangan sedang Play).
2. Buka file `CreateInvestigationClues_CommandBar.lua`, salin seluruh isinya ke Command Bar, lalu tekan Enter.
3. Skrip membuat `Workspace/InvestigationClues` dan tiga Part placeholder di dekat origin. Pindahkan Part ke lokasi yang sesuai di map: `Clue_Rambu` di tikungan/rambu tertutup daun, `Clue_Marka` di zebra cross, `Clue_Penerangan` di tiang lampu yang mati. Posisi awal hanyalah contoh.
4. Pastikan ketiga objek adalah **BasePart** dan anak langsung dari folder itu. Tidak perlu menambahkan ProximityPrompt secara manual.

| Nama Part | Tempatkan di | Nama objek prompt | Deskripsi temuan |
|---|---|---|---|
| `Clue_Rambu` | Tikungan dengan rambu sekolah tertutup daun | Rambu Tertutup Daun | Rambu Zona Sekolah tertutup daun lebat! Supir dari tikungan tidak bisa melihat peringatan ini. |
| `Clue_Marka` | Zebra cross yang pudar dan licin | Marka Zebra Cross | Garis zebra cross sudah terkelupas dan licin. Tidak ada marka kejut untuk memperlambat roda mobil. |
| `Clue_Penerangan` | Trotoar dekat tiang lampu/sensor yang mati | Tiang Lampu Jalan | Lampu penerangan mati total dan tidak ada penanda visual aktif saat kondisi jalan berkabut/gelap. |

Saat server berjalan, `ClueQuestManager` membuat prompt pada tiap Part dengan `ActionText = Periksa`, `HoldDuration = 1`, dan nama objek sesuai bukti. Prompt hanya menerima klaim pertama untuk tiap bukti; server membagi progres, menonaktifkan prompt yang sudah ditemukan, dan memberi tahu semua klien.

## 4. Siapkan misi fisik Tahap 2–5

Jalankan `CreateSpatialMissions_CommandBar.lua` dari **View → Command Bar** dalam mode Edit. Skrip menambahkan objek graybox di sekitar `Z = 100` agar terpisah dari marker Misi 1 yang biasanya dibuat di origin. Helper juga membuat tulisan papan analisis dan kartu blueprint yang terlihat di dunia; part yang sudah ada tidak dipindah atau diubah:

- `WarRoom.Whiteboard` — papan analisis Pos Satpam. Rani meminta tim membawa temuan ke sini setelah Tahap 1; hanya prompt fisik **Buka Papan Analisis** yang membuka voting Define.
- `BlueprintStations.Station_A` — meja Bengkel Konstruksi Jalan, berisi inspirasi marka jalan dan speed table.
- `BlueprintStations.Station_B` — meja Lab Komputer/Elektronik, berisi inspirasi Smart Traffic dan sensor penyeberangan.
- `MaterialSupply.Crate` dan `InteractionStation.PrototypeSlot` — pemain mengambil Tool `Material_Komponen_Prototipe`, membawanya dalam keadaan terpasang, lalu menahan prompt rakit selama 1,5 detik.
- `Crosswalk_Entry` dan `Crosswalk_Destination` — titik awal dan tujuan Rani.
- `CrossSafeSimulation` — lampu, garis stop, dua mobil graybox, dan marker posisi berhenti/lanjut.

Pindahkan objek ke map sebenarnya. Letakkan `Whiteboard` di dalam Pos Satpam. Atur Station A di bengkel dan Station B di lab, lalu pindahkan `BlueprintCard_A`/`BlueprintCard_B` bersama mejanya. Tempatkan `Crate` di depan toko/gudang, `PrototypeSlot` di zebra cross, lalu sejajarkan `Crosswalk_Entry`/`Crosswalk_Destination` dengan kedua trotoar. Putar dan pindahkan `VehicleStop_1/2` ke belakang garis henti; pindahkan `VehiclePass_1/2` ke seberang zebra cross. Part marker biru kehijauan sengaja terlihat saat setup supaya mudah disusun; jadikan transparan setelah posisinya benar.

`Rani_NPC` harus berupa rig tidak terkunci (unanchored) yang memiliki `Humanoid` dan `HumanoidRootPart`. Pastikan jalur berjalan dari titik masuk menuju tujuan tidak terhalang. Jika tersedia, tambahkan `Animation` bernama `CrossSafeFlinch` ke model Rani dengan animasi kaget milik Anda. Tanpa animasi itu, simulasi memakai gerakan lompat dan mundur sebagai fallback.

Helper membuat `AssemblySound` di `PrototypeSlot` dan `HornSound` di `CrossSafeSimulation` tanpa audio ID. Isi `SoundId` dengan audio milik Anda atau audio bebas pakai dari Creator Store agar suara perakitan dan klakson terdengar; Roblox meminta `SoundId` menunjuk ke asset audio yang dapat diakses oleh experience. [Dokumentasi Sound Roblox](https://create.roblox.com/docs/sound)

Di Tahap 3, membaca salah satu stasiun A/B sudah cukup untuk membuka voting Ideate tim. Pilihan Ideate tetap mengikuti cabang Define di pohon keputusan. Setelah voting Prototype, biaya tetap dicatat ke ledger Rp10 juta saat pilihan diterima; jika model katalog belum disiapkan, server menampilkan graybox berlabel di PrototypeSlot. Model asli tetap dapat dibuat di `ServerStorage/PrototypeModels`.

Pada Testing, `SafetyStatus == PASS` menyalakan lampu, menghentikan mobil di marker sebelum garis, dan mengarahkan Rani ke tujuan. Status `FAIL` maupun `CONDITIONAL` memakai simulasi berisiko: mobil melintasi marker, klakson berbunyi, Rani berjalan menunduk lalu kaget dan mundur. Rapor baru dibuka setelah urutan simulasi selesai. `Humanoid:MoveTo()` dapat berhenti bila rig terhalang atau tidak mencapai target; jalur NPC perlu bebas penghalang. [Dokumentasi Humanoid.MoveTo](https://create.roblox.com/docs/reference/engine/classes/Humanoid)

## 5. Buat lingkungan belajar sederhana

Mulai dengan graybox dari Part biasa; model 3D rinci bisa ditambahkan kemudian.

1. Buat jalan empat lajur, trotoar, zebra cross, garis henti, pagar pembatas, serta rambu sekolah. Tempatkan tiga Part bukti tepat di lingkungan yang relevan. Gunakan warna dan papan informasi agar skenario mudah dibaca.
2. Tambahkan NPC **Model** bernama `Rani_NPC` sebagai tokoh wawancara, misalnya rig dari **Avatar → Rig Builder**. Pastikan model memiliki `Humanoid`, `HumanoidRootPart`, dan jalur bebas menuju zebra cross. `GameManager` membuat prompt `TalkToRaniPrompt` secara otomatis. Saat didekati, tekan **E** untuk berbicara dengan Rani.
3. Pastikan `InteractionStation.PrototypeSlot` berada di area perakitan. Model terpilih dipasang setelah Tool dibawa ke slot; tanpa model katalog, graybox bernama prototipe tetap ditampilkan.
4. Buat lingkungan sebagai representasi aman untuk diskusi desain. Jangan meminta pemain meniru tindakan menyeberang yang berisiko di dunia nyata.

Untuk menjalankan semua misi tahap 2–5, semua objek yang disebut pada bagian sebelumnya harus ada dan diposisikan di map. `Rani_NPC` dan `Crosswalk_Destination` diperlukan untuk simulasi bergerak. Model katalog prototipe bersifat opsional karena graybox otomatis akan muncul bila belum dibuat.

## 6. Tambahkan model prototipe (opsional, untuk tampilan)

Di `ServerStorage/PrototypeModels`, buat satu **Model** untuk setiap nama berikut. Model sederhana dari Part sudah cukup untuk graybox. Nama wajib sama dengan kode:

```text
Proto_P01_BannerLight       Proto_P02_HazardSolar
Proto_P03_PaintLine         Proto_P04_RumbleStrip
Proto_P05_SharpBump          Proto_P06_RubberBump
Proto_P07_SteepTable         Proto_P08_PavingTable
Proto_P09_SteepBridge        Proto_P10_CoveredStairs
Proto_P11_OpenRamp           Proto_P12_MasterBridge
Proto_P13_AppBasic           Proto_P14_AppAdvanced
Proto_P15_BasicPole          Proto_P16_MasterPole
```

Enam model overlay Quick Patch juga opsional:

```text
Patch_P02_RumbleStrip
Patch_P06_Lighting
Patch_P07_Drainage
Patch_P10_AccessLift
Patch_P11_Canopy
Patch_P15_Countdown
```

Atur pivot tiap Model agar berada di titik yang sesuai pada `PrototypeSlot`. Untuk graybox, buat bagian model `Anchored` agar tidak jatuh atau mengganggu pemain. Jika nama model belum tersedia, GameManager membuat balok pratinjau berlabel sebagai pengganti. Model Quick Patch masih opsional untuk visual; evaluasi patch tetap dihitung server.

## 7. Jalankan dan uji alur

1. Buka **View → Output**, lalu tekan **Play**. Saat server dimulai, `DecisionTreeData.Validate()` memeriksa hubungan node, pilihan, prototipe, skor, dan harga. Perbaiki error yang muncul di Output sebelum melanjutkan.
2. Pastikan panel voting belum tampil, tetapi Quest Tracker menunjukkan `[0/3]`. Dekati satu bukti dan tekan **Periksa** selama satu detik. Tracker harus berubah menjadi `[1/3]`, pop-up harus tampil empat detik, dan prompt bukti itu harus hilang.
3. Berinteraksi dengan Rani sebelum semua bukti terkumpul. Rani harus menolak membuka Tahap 1, menunjukkan progres saat ini, dan tidak menampilkan tombol mulai.
4. Periksa dua bukti lainnya. Setelah `[3/3]`, kembali ke Rani dan tekan **Ajak bicara**; dialog Rani sekarang menampilkan tombol **Mulai diskusi bersama Rani**.
5. Tekan tombol mulai. Panel voting Tahap 1 harus terbuka. Tombol **×** menyembunyikan panel; prompt Rani dapat membuka kembali UI selama sesi berjalan.
6. Untuk memeriksa progres bersama, buka tab **Test**, pilih **Server & Clients**, atur jumlah klien menjadi 3, lalu mulai simulasi. Minta klien berbeda menemukan bukti; semua tracker harus menunjukkan jumlah yang sama. [Mode pengujian Studio](https://create.roblox.com/docs/studio/testing-modes)
7. Selesaikan voting Empathize. Sesudah suara tim ditutup, panel harus menghilang dan tracker mengarahkan pemain ke `WarRoom.Whiteboard`. Dekati papan dan tahan prompt **Buka Papan Analisis**; hanya sesudah aksi ini voting Define boleh terbuka.
8. Selesaikan voting Define. Tracker berpindah ke misi Blueprint. Baca `Station_A` atau `Station_B`; interaksi di salah satu meja sudah cukup untuk membuka voting Ideate. Sebelum scan, panel Ideate harus tetap tertutup.
9. Selesaikan voting Ideate, lalu pilih prototipe di Tahap 4. Saldo harus berkurang sesuai biaya prototipe di ledger server; model belum muncul sebelum material dirakit.
10. Datangi `MaterialSupply.Crate`, ambil Tool, bawa sambil terpasang ke `PrototypeSlot`, lalu tahan prompt rakit 1,5 detik. Tool harus hilang dan model terpilih/graybox berlabel muncul.
11. Untuk jalur aman, pilih `1.B` → `2.B2` → baca blueprint Station B → `3.B2b` → `P.16`. Lampu menyala, kedua mobil bergerak ke marker di belakang garis stop, Rani berjalan ke `Crosswalk_Destination`, lalu rapor muncul.
12. Untuk jalur gagal, pilih `1.B` → `2.B2` → Station B → `3.B2a` → `P.14`. Mobil bergerak melewati zebra cross, klakson (jika SoundId diset) berbunyi, Rani menunduk/kaget/mundur, dan rapor baru muncul setelah gerakan selesai. Status harus `FAIL` serta mengikuti aturan Safety Gate.
13. Buka tab **Test → Server & Clients** dengan tiga klien. Biarkan satu pemain membuka papan atau membaca blueprint; semua klien harus melihat tracker progres yang sama. Pastikan tahap lanjutan hanya terbuka setelah prompt fisik server aktif.
14. Uji Quick Patch: setelah laporan bersyarat, lakukan voting Quick Patch; model patch dipasang dan simulasi menyeberang diputar lagi sebelum laporan diperbarui. Uji Deep Pivot: ledger mengembalikan salvage 50%, tracker kembali mengarahkan tim ke Pos Satpam, dan Define harus dibuka lagi secara fisik.

Untuk mempercepat uji timer di Studio, ubah `VoteDurationSeconds` pada `DecisionTreeData.Constants` sementara, lalu pulihkan durasi 60 detik sebelum menerbitkan game. Voting harus diuji dengan server dan beberapa klien karena tes satu pemain tidak menguji pengumpulan suara tim.

## 8. Cara membaca sistem poin dan keselamatan

- Setiap tahap menyumbang 10 atau 25 poin; skor Design Thinking berkisar 40–100.
- Pembelian prototipe dan Quick Patch mengurangi saldo server. Quick Patch berbiaya Rp2.000.000 dan memperbaiki risiko tertentu; patch tidak menambah skor metodologi.
- Deep Pivot menjual prototipe lama dengan pengembalian 50% biaya dan membawa tim kembali ke Define, dengan jawaban `1.B` dipertahankan.
- Safety Gate dapat membatasi bintang: `FAIL` maksimal dua bintang; `CONDITIONAL` maksimal tiga bintang.
- Sesi satu server adalah satu tim. Implementasi ini belum membuat sesi terpisah untuk beberapa tim dalam satu server atau penyimpanan kemajuan setelah server tutup.

Lihat `CrossSafe_Setup_Audit.md` untuk asumsi audit dan rincian batas implementasi. Sebelum menerbitkan, pastikan tidak ada error pada Output, semua pilihan UI terbaca pada ukuran layar target, jalur Rani bebas penghalang, marker mobil akurat, serta audio memiliki izin dan dapat diputar. Eksekusi runtime perlu dilakukan di Roblox Studio.

