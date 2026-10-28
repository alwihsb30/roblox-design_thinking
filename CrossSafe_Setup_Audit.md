# CrossSafe — Implementasi dan Catatan Audit

Dokumen ini menjelaskan lima skrip backend dan satu LocalScript UI, aturan yang dipakai saat keputusan bertentangan, dan komponen Roblox Studio yang masih perlu dibuat.

## File dan penempatan di Roblox Studio

| File hasil | Jenis Roblox | Lokasi |
|---|---|---|
| `DecisionTreeData.lua` | ModuleScript | `ReplicatedStorage/DecisionTreeData` |
| `VotingHandler.lua` | ModuleScript | `ServerScriptService/VotingHandler` |
| `EvaluationService.lua` | ModuleScript | `ServerScriptService/EvaluationService` |
| `ClueQuestManager.lua` | ModuleScript | `ServerScriptService/ClueQuestManager` |
| `GameManager.lua` | Script | `ServerScriptService/GameManager` |
| `CrossSafeClient.client.lua` | LocalScript | `StarterGui/CrossSafeClient` |

`GameManager` membuat folder `ReplicatedStorage/GameNetwork` dan objek jaringan berikut saat server berjalan:

- `SubmitVote` — RemoteEvent untuk mengirim `nodeKey` dan `choiceKey`.
- `SyncGameState` — RemoteEvent untuk menerima prompt, hasil, dan status transaksi.
- `TriggerIteration` — RemoteEvent untuk meminta `QUICK_PATCH` atau `DEEP_PIVOT`.
- `StartSession` — RemoteEvent untuk memulai permainan setelah pemain berbicara dengan Rani; permintaan dicek jaraknya oleh server.
- `GetGameState` — RemoteFunction untuk mengambil status sesi saat pemain membuka UI di dekat Rani.

`ClueQuestManager` membuat prompt pada tiga Part bernama `Clue_Rambu`, `Clue_Marka`, dan `Clue_Penerangan` di `Workspace/InvestigationClues`. Klaim bukti dan progres disimpan oleh server sebagai progres bersama per server; setiap klaim unik menonaktifkan prompt dan dikirim melalui `SyncGameState` (`CLUE_FOUND`/`CLUE_PROGRESS`). `GameManager` menolak memulai sesi bila jumlah bukti belum 3/3, termasuk jika klien memanggil RemoteEvent langsung.

`CrossSafeClient.client.lua` menyediakan HUD misi permanen dan card temuan empat detik pada GUI terpisah dari panel diskusi. Panel voting mulai tersembunyi. Jika pemain berbicara dengan Rani sebelum misi lengkap, ia melihat penolakan serta progres dan tombol mulai tidak tersedia; setelah 3/3, interaksi berikutnya menampilkan tombol mulai. Saat UI dibuka lagi di dekat Rani, klien mengambil status melalui `GetGameState:InvokeServer()` dan menampilkan hanya ID yang ada di `AllowedChoiceKeys` atau `AllowedIterationActions`. Ia menggunakan `VoteToken` terbaru dari status atau prompt. Saat pemain memilih tahap biasa, ia memanggil `SubmitVote:FireServer(ActiveNodeKey, VoteToken, choiceId)`. Saat memilih iterasi, setiap anggota tim mengirim suaranya melalui `TriggerIteration:FireServer(VoteToken, "QUICK_PATCH")` atau `TriggerIteration:FireServer(VoteToken, "DEEP_PIVOT")`; server menyelesaikan voting bersama sebelum membelanjakan atau mengembalikan saldo. Klien juga menangani `RANI_GATEKEEPER`, `CLUE_FOUND`, dan `CLUE_PROGRESS` dari `SyncGameState`.

Data pilihan boleh dibaca klien untuk menampilkan teks, tetapi server tetap memeriksa node aktif, daftar pilihan yang diizinkan, jalur sebelumnya, biaya, saldo, dan tahap sesi. Jangan menerima skor atau saldo dari klien.

## Struktur pohon dan konsistensi data

Pohon memiliki **15 node pertanyaan/state**, **30 sisi pilihan**, dan **16 daun prototipe**:

- Tahap 1: 1 node dan 2 pilihan.
- Tahap 2: 2 node dan 4 pilihan.
- Tahap 3: 4 node dan 8 pilihan.
- Tahap 4: 8 node pemilihan prototipe dan 16 pilihan.

Dengan demikian “30” adalah jumlah sisi pilihan, bukan jumlah node pertanyaan. ID pada pilihan Tahap 1–3 menjadi `ParentChoiceId` bagi dua prototipe di bawahnya. Harga dan poin pada pilihan Tahap 4 disamakan dengan metadata prototipenya. `DecisionTreeData.Validate()` memeriksa jumlah, keterjangkauan node, transisi antartahap, induk prototipe, poin, dan batas biaya. `GameManager` menjalankan pemeriksaan itu saat mulai; server berhenti dengan pesan jelas bila tabel tidak konsisten.

Skor Design Thinking adalah empat keputusan, satu dari setiap tahap: masing-masing bernilai 10 atau 25, sehingga skor berada pada rentang 40–100. `PROCESS_BIAS` memengaruhi pembelajaran dan tie-break, tetapi tidak otomatis menyatakan ada bahaya fisik. `ACCESSIBILITY` menghasilkan status keselamatan bersyarat; `DISTRACTION` menghasilkan status gagal. Status prototipe juga ikut diperiksa.

## Voting, anggaran, dan siklus iterasi

- Saldo awal tim Rp10.000.000. Pembelian dan Quick Patch dicatat dalam ledger server; Deep Pivot mengembalikan 50% harga prototipe yang dijual. Biaya putaran sebelumnya dan biaya patch tetap tercatat.
- Voting ditutup setelah seluruh pemain aktif memilih atau setelah 60 detik. Pemain dapat mengubah pilihannya sebelum penutupan. Saat batas waktu tercapai, suara yang masuk dihitung; hasil seri dipecahkan berurutan berdasarkan keselamatan, poin lebih tinggi, biaya lebih rendah, lalu ID. Jika belum ada suara, tie-break yang sama memilih opsi bawaan.
- Pilihan Quick Patch dan Deep Pivot juga memakai voting tim. Jika keduanya seri atau tidak ada suara sampai batas waktu, Quick Patch diprioritaskan karena biayanya lebih rendah; sesi yang berstatus `FAIL` hanya menawarkan Deep Pivot.
- Pemain yang keluar dihapus dari pemilih aktif. Jika seluruh pemain keluar, voting dijeda dan dilanjutkan saat pemain baru bergabung. Pemain yang masuk di tengah voting ikut dalam voting itu.
- Setelah Deep Pivot, 50% harga prototipe lama masuk kembali ke saldo. Tim kembali ke Tahap 2 dengan jawaban empati `1.B` dipertahankan, sehingga tahap Define dan seterusnya diulang dengan modal tersisa.
- Pilihan yang tidak memiliki prototipe terjangkau dari saldo saat ini disembunyikan server sejak tahap sebelumnya. Ini mencegah tim terjebak setelah melakukan salvage.
- Deep Pivot juga diperiksa terhadap saldo proyeksi setelah pengembalian 50%. Jika tidak ada prototipe yang terjangkau pada putaran baru, sistem mengakhiri iterasi dengan laporan keselamatan dan catatan bahwa anggaran membatasi perbaikan.
- Status `FAIL` membatasi rating maksimal dua bintang dan mewajibkan Deep Pivot bila saldo setelah salvage masih cukup untuk membeli satu prototipe pada rute mulai Tahap 2. Jika iterasi sudah tidak mungkin didanai, laporan tetap menunjukkan `FAIL` dan maksimal dua bintang, tetapi menandai bahwa saldo menghalangi pivot. `CONDITIONAL` membatasi rating maksimal tiga bintang; Quick Patch tersedia bila prototipe memiliki paket patch dan saldo cukup. Status `PASS` memakai rating skor biasa.
- Quick Patch memerlukan Rp2.000.000, dicatat sekali, dan hanya dapat dipakai untuk risiko yang dinyatakan dapat diselesaikan oleh metadata prototipe. Patch mengubah status keselamatan, bukan skor metodologi. Jika skor belum lima bintang, Deep Pivot tetap dapat dipilih.
- Rating skor sebelum pembatas keselamatan: 1 bintang di bawah 50; 2 mulai 50; 3 mulai 65; 4 mulai 80; 5 mulai 95. Safety Gate membatasi bintang maksimal 2 untuk `FAIL` dan maksimal 3 untuk `CONDITIONAL`.

Sesi saat ini adalah satu tim bersama untuk satu server. Tiga pemain tetap menjadi ukuran kelompok yang disarankan dalam rancangan pembelajaran; implementasi juga menangani jumlah pemain yang berbeda. Untuk beberapa tim yang bermain bersamaan, buat satu sesi/ledger per tim dan batasi remote ke anggota tim masing-masing.

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

Model prototipe sebaiknya memiliki pivot yang sesuai dengan titik pemasangan. Jika model atau `PrototypeSlot` belum ada, sistem tetap menghitung permainan dan mencatat transaksi, tetapi menulis peringatan dan melewati visual model. Model patch adalah overlay opsional untuk tampilan; evaluasi keselamatan patch tetap dikelola server.

Model `Workspace.Rani_NPC` dan folder `Workspace.InvestigationClues` berisi tiga BasePart bernama tepat sesuai spesifikasi diperlukan. `GameManager` menambahkan ProximityPrompt `TalkToRaniPrompt` pada Rani; `ClueQuestManager` membuat prompt Periksa pada tiap bukti dan mengatur HoldDuration 1 detik. Jalan empat lajur, zebra cross, dan rambu menjadi aset lingkungan; VotingDesk fisik tidak diperlukan. Pastikan simulasi lalu lintas tetap berupa representasi edukatif dan tidak menyuruh pemain melakukan tindakan menyeberang yang berbahaya di dunia nyata.

## Asumsi rancangan yang dipakai

1. Jalur aplikasi ponsel (`3.B2a`, P.13, dan P.14) selalu gagal pada Safety Gate karena risiko distraksi di dekat lalu lintas, meski poin ide/prototipenya tinggi.
2. JPO bertangga pada `3.B1a` memiliki risiko aksesibilitas. P.10 dapat dimitigasi dengan patch akses lift; P.09 tetap gagal karena beban penggunaan membuat siswa berpotensi menolak JPO.
3. Paket Quick Patch spesifik untuk tiap prototipe bersyarat. Ini melengkapi spesifikasi yang hanya menyebut biaya patch Rp2 juta, tetapi tidak merinci risiko yang diperbaiki.
4. Deep Pivot mengulang dari Define dan mempertahankan pilihan wawancara empati `1.B`, sesuai mekanik “kembali ke Tahap 2” pada rancangan.
5. Ledger dan sesi bersifat in-memory. Data tidak bertahan setelah server Roblox ditutup; penyimpanan lintas sesi memerlukan DataStoreService dan kebijakan reset tambahan.

## Batas implementasi

Backend menyediakan data, voting, ledger, evaluasi, iterasi, interaksi Rani, serta misi bukti. `CrossSafeClient.client.lua` menyediakan HUD misi, notifikasi temuan, dialog, dan UI voting starter. Animasi Rani, simulasi lampu lalu lintas, countdown yang tersinkron, DataStore, dan isolasi sesi beberapa tim belum termasuk dan perlu dibuat terpisah bila dibutuhkan. Pemeriksaan runtime terakhir tetap perlu dilakukan di Roblox Studio dengan folder dan Part bukti ditempatkan serta pengujian beberapa klien.

