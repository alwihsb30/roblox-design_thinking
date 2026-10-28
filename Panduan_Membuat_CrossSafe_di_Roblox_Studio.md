# Panduan Membuat CrossSafe di Roblox Studio

Panduan ini memakai lima file backend dan satu `LocalScript` UI starter. Permainan memakai satu tim bersama per server, modal awal Rp10.000.000, misi pencarian tiga bukti, voting bersama, Safety Gate, Quick Patch, dan Deep Pivot.

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
└── InteractionStation (Model atau Folder)    [opsional untuk visual]
    └── PrototypeSlot (Part)                  [opsional untuk visual]
```

Untuk menambah objek, klik kanan layanan/folder yang dituju di Explorer, pilih **Insert Object**, lalu cari jenis objek di atas. Roblox menjalankan `LocalScript` di `StarterGui` untuk tiap pemain. `GameManager` membuat `GameNetwork`, empat `RemoteEvent`, dan satu `RemoteFunction` otomatis ketika server dimulai; jangan buat salinan remotes secara manual. Script juga membuat ProximityPrompt pada `Rani_NPC` dan tiga part bukti. [Panduan lokasi script](https://create.roblox.com/docs/scripting/locations)

Jika project sudah memiliki `ScreenGui` CrossSafe lama atau salinan `CrossSafeClient` di `StarterPlayerScripts`, hapus/nonaktifkan duplikat itu. UI baru dibuat oleh LocalScript ini dan memulai dalam keadaan tersembunyi; GUI lama yang masih ada bisa tetap tampil terpisah.

## 2. Masukkan kode ke objek yang benar

Buka masing-masing file hasil dan salin seluruh isinya ke objek Studio yang namanya cocok:

- `DecisionTreeData.lua` → `ReplicatedStorage/DecisionTreeData`.
- `VotingHandler.lua` → `ServerScriptService/VotingHandler`.
- `EvaluationService.lua` → `ServerScriptService/EvaluationService`.
- `ClueQuestManager.lua` → `ServerScriptService/ClueQuestManager` (**ModuleScript**).
- `GameManager.lua` → `ServerScriptService/GameManager`.
- `CrossSafeClient.client.lua` → `StarterGui/CrossSafeClient`.

Hapus kode bawaan seperti `print("Hello world!")` sebelum menempel kode. Pastikan `DecisionTreeData` adalah **ModuleScript**, bukan `Script`; tiga file server diletakkan di `ServerScriptService`; dan file UI adalah **LocalScript**. Nama file di komputer boleh memiliki ekstensi `.lua` atau `.client.lua`; nama objek di Explorer mengikuti susunan di atas.

`CrossSafeClient` membuat panel UI saat pemain bergabung, tetapi panel dimulai tersembunyi. Sesi juga menunggu di server sampai pemain mendekati Rani, menekan prompt **Ajak bicara**, lalu memilih **Mulai diskusi bersama Rani** pada dialog. Sesudah itu, tombol UI mengirim ID pilihan beserta token voting ke server. Untuk membuka UI lagi selama permainan, dekati Rani dan tekan prompt lagi; tombol **×** menutup UI. Server menentukan pilihan tim, skor, biaya, status keselamatan, dan hasil iterasi. Remote Roblox memang dirancang untuk komunikasi klien-server; validasi penting tetap dilakukan di sisi server. [Dokumentasi RemoteEvent](https://create.roblox.com/docs/scripting/events/remote)

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

## 4. Buat lingkungan belajar sederhana

Mulai dengan graybox dari Part biasa; model 3D rinci bisa ditambahkan kemudian.

1. Buat jalan empat lajur, trotoar, zebra cross, garis henti, pagar pembatas, serta rambu sekolah. Tempatkan tiga Part bukti tepat di lingkungan yang relevan. Gunakan warna dan papan informasi agar skenario mudah dibaca.
2. Tambahkan NPC **Model** bernama `Rani_NPC` sebagai tokoh wawancara, misalnya rig dari **Avatar → Rig Builder**. Pastikan model memiliki `HumanoidRootPart`, `Head`, `PrimaryPart`, atau setidaknya satu Part. `GameManager` membuat ProximityPrompt bernama `TalkToRaniPrompt` secara otomatis pada part yang ditemukan. Saat didekati, tekan **E** (keyboard) atau tombol prompt pada perangkat untuk berbicara dengan Rani.
3. Buat `InteractionStation` dan Part bernama `PrototypeSlot` jika ingin model terpilih muncul di dunia. Atur ukuran dan `CFrame` Part sebagai titik pemasangan. Kode akan mengkloning model prototipe ke posisi itu.
4. Buat lingkungan sebagai representasi aman untuk diskusi desain. Jangan meminta pemain meniru tindakan menyeberang yang berisiko di dunia nyata.

Jalan, rambu, dan stasiun bukan prasyarat agar voting dan evaluasi berjalan. `Rani_NPC` dibutuhkan sebagai pemicu interaksi dan awal permainan. Tanpa `PrototypeSlot` atau model prototipe, server tetap menjalankan logika permainan dan memberi peringatan di Output; hanya visual model yang dilewati.

## 5. Tambahkan model prototipe (opsional, untuk tampilan)

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

Atur pivot tiap Model agar berada di titik yang sesuai pada `PrototypeSlot`. Untuk graybox, buat bagian model `Anchored` agar tidak jatuh atau mengganggu pemain. Bila nama model belum tersedia, transaksi dan evaluasi tetap berlangsung, tetapi tampilan prototipe/patch tersebut tidak muncul.

## 6. Jalankan dan uji alur

1. Buka **View → Output**, lalu tekan **Play**. Saat server dimulai, `DecisionTreeData.Validate()` memeriksa hubungan node, pilihan, prototipe, skor, dan harga. Perbaiki error yang muncul di Output sebelum melanjutkan.
2. Pastikan panel voting belum tampil, tetapi Quest Tracker menunjukkan `[0/3]`. Dekati satu bukti dan tekan **Periksa** selama satu detik. Tracker harus berubah menjadi `[1/3]`, pop-up harus tampil empat detik, dan prompt bukti itu harus hilang.
3. Berinteraksi dengan Rani sebelum semua bukti terkumpul. Rani harus menolak membuka Tahap 1, menunjukkan progres saat ini, dan tidak menampilkan tombol mulai.
4. Periksa dua bukti lainnya. Setelah `[3/3]`, kembali ke Rani dan tekan **Ajak bicara**; dialog Rani sekarang menampilkan tombol **Mulai diskusi bersama Rani**.
5. Tekan tombol mulai. Panel voting Tahap 1 harus terbuka. Tombol **×** menyembunyikan panel; prompt Rani dapat membuka kembali UI selama sesi berjalan.
6. Untuk memeriksa progres bersama, buka tab **Test**, pilih **Server & Clients**, atur jumlah klien menjadi 3, lalu mulai simulasi. Minta klien berbeda menemukan bukti; semua tracker harus menunjukkan jumlah yang sama. [Mode pengujian Studio](https://create.roblox.com/docs/studio/testing-modes)
7. Periksa jalur aman: pilih jawaban Empathize `1.B`, Define `2.B2`, Ideate `3.B2b`, lalu pilih prototipe `P.16`. Cocokkan saldo dan laporan Safety Gate.
8. Periksa cabang ponsel: dari `1.B`, pilih `2.B2`, lalu `3.B2a` dan prototipe `P.13` atau `P.14`. Laporan harus menandai risiko distraksi sebagai `FAIL` dan meminta Deep Pivot bila saldo memungkinkan.
9. Periksa Quick Patch dengan prototipe bersyarat yang memiliki patch, misalnya `P.15` atau `P.10`. Untuk Deep Pivot, amati pengembalian salvage 50%, pilihan Empathize `1.B` yang dipertahankan, dan permainan yang kembali ke Tahap 2.

Untuk mempercepat uji timer di Studio, ubah `VoteDurationSeconds` pada `DecisionTreeData.Constants` sementara, lalu pulihkan durasi 60 detik sebelum menerbitkan game. Voting harus diuji dengan server dan beberapa klien karena tes satu pemain tidak menguji pengumpulan suara tim.

## 7. Cara membaca sistem poin dan keselamatan

- Setiap tahap menyumbang 10 atau 25 poin; skor Design Thinking berkisar 40–100.
- Pembelian prototipe dan Quick Patch mengurangi saldo server. Quick Patch berbiaya Rp2.000.000 dan memperbaiki risiko tertentu; patch tidak menambah skor metodologi.
- Deep Pivot menjual prototipe lama dengan pengembalian 50% biaya dan membawa tim kembali ke Define, dengan jawaban `1.B` dipertahankan.
- Safety Gate dapat membatasi bintang: `FAIL` maksimal dua bintang; `CONDITIONAL` maksimal tiga bintang.
- Sesi satu server adalah satu tim. Implementasi ini belum membuat sesi terpisah untuk beberapa tim dalam satu server atau penyimpanan kemajuan setelah server tutup.

Lihat `CrossSafe_Setup_Audit.md` untuk asumsi audit dan rincian batas implementasi. Sebelum menerbitkan, pastikan tidak ada error pada Output, semua pilihan UI terbaca pada ukuran layar target, dan pengujian beberapa klien sudah selesai. Backend telah diperiksa secara statis; eksekusi runtime terakhir perlu dilakukan di Roblox Studio.

