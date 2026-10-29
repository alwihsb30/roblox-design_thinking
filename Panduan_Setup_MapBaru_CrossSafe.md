# Panduan setup CrossSafe di map baru

Panduan ini untuk mulai bersih tanpa menghapus map lama. Hasil generator berupa graybox sederhana; nanti bentuk dan warnanya boleh dipercantik, tetapi nama objek dan susunan folder harus dipertahankan.

## 1. Buat place Baseplate baru

1. Buka Roblox Studio, pilih **File → New → Baseplate**.
2. Simpan sebagai place baru, misalnya `CrossSafe_MapBaru.rbxl`. Jangan buka atau timpa place lama.
3. Atur kapasitas place menjadi **1 pemain** melalui pengaturan place di Creator Dashboard. Roblox mengatur batas ini lewat setting place, bukan dari Script. Lihat [dokumentasi MaxPlayers](https://create.roblox.com/docs/reference/engine/classes/Players#MaxPlayers).
4. Pastikan panel **Explorer**, **Properties**, **Output**, dan **Command Bar** terlihat. Command Bar ada di **View → Command Bar**.

## 2. Buat semua prop map sekaligus

1. Di repositori CrossSafe, buka file `CreateCrossSafeFreshMap_CommandBar.lua`.
2. Salin seluruh isi file, bukan hanya sebagian.
3. Pastikan Studio dalam mode **Edit** (tombol Play belum ditekan), lalu tempel ke Command Bar dan tekan **Enter**.
5. Tunggu pesan `CrossSafe fresh-map graybox siap` di Output, lalu tekan **Ctrl+S**.

Jalankan generator ini satu kali saja pada Baseplate baru. Generator tidak menghapus apa pun; ia berhenti dengan pesan kesalahan bila mendeteksi objek CrossSafe yang sama, untuk mencegah prop bertumpuk. Layout mencakup jalan dan zebra cross, tiga bukti, Pos Satpam, dua meja blueprint, crate material, tempat rakit, lampu, mobil, marker, dan titik spawn.

### Opsional: tambahkan hiasan visual

Setelah generator map selesai, buat `Workspace.EnvironmentDecorations` sebagai Folder. Buka `CreateCrossSafeDecorationPack_CommandBar.lua`, salin seluruh isinya ke **View → Command Bar** saat mode Edit, lalu tekan **Enter** satu kali. Script menambah gerbang sekolah, atap Pos Satpam dan meja blueprint, pepohonan, garis lajur, serta pencahayaan pagi di dalam `EnvironmentDecorations.CrossSafe_VisualDressing`. Script tidak menghapus atau mengganti nama objek misi.

## 3. Pasang enam objek script game

Untuk setiap file di repositori, buat object lewat tombol **+** pada layanan di Explorer, ubah namanya agar sama persis, buka editor, hapus isi default, lalu salin seluruh isi file ke editor.

| File sumber | Buat object ini | Letakkan di |
|---|---|---|
| `DecisionTreeData.lua` | ModuleScript bernama `DecisionTreeData` | `ReplicatedStorage` |
| `GameManager.lua` | Script bernama `GameManager` | `ServerScriptService` |
| `EvaluationService.lua` | ModuleScript bernama `EvaluationService` | `ServerScriptService` |
| `ClueQuestManager.lua` | ModuleScript bernama `ClueQuestManager` | `ServerScriptService` |
| `SpatialMissionManager.lua` | ModuleScript bernama `SpatialMissionManager` | `ServerScriptService` |
| `CrossSafeClient.client.lua` | LocalScript bernama `CrossSafeClient` | `StarterGui` |

File `.lua` dari GitHub adalah kode sumber. Menyalinnya ke Studio sebagai object dengan jenis dan nama di tabel ini diperlukan; sekadar drag atau simpan file di komputer tidak memasangnya ke dalam game.

## 4. Tambahkan Rani

1. Buka tab **Avatar → Rig Builder**, lalu buat rig R15.
2. Di Explorer, ubah nama Model menjadi `Rani_NPC` dan pastikan Model menjadi anak langsung `Workspace`.
3. Pindahkan Rani dekat marker kuning `Crosswalk_Entry` di sisi selatan jalan.
4. Pastikan di dalam Model ada `Humanoid` dan `HumanoidRootPart`. `HumanoidRootPart.Anchored` harus **false**. Bersihkan benda yang menghalangi lintasan lurus Rani menuju marker hijau `Crosswalk_Destination`.

Saat game berjalan, server membuat prompt bicara di Rani dan prompt misi lainnya. Tidak perlu membuat prompt, folder `GameNetwork`, atau RemoteEvent secara manual.

## 5. Uji dari awal

1. Tekan **Play**. Quest Tracker akan terlihat. Dekati Rani dan tekan **E** sebelum mencari bukti; ia harus meminta kamu memeriksa tiga titik.
2. Periksa `Clue_Rambu`, `Clue_Marka`, dan `Clue_Penerangan` dengan menahan **E**. Tracker harus berubah sampai `[3/3]`.
3. Bicara dengan Rani lagi dan pilih tombol **Mulai sesi bersama Rani**. Pilihan Empathize sekarang terbuka.
4. Setelah memilih jawaban Empathize, pergi ke Pos Satpam dan tekan **E** pada `Whiteboard`. Pilih jawaban Define.
5. Baca salah satu meja di `BlueprintStations` dengan **E**, lalu pilih jawaban Ideate dan prototipe.
6. Pergi ke crate, ambil komponen, dan bawa Tool yang muncul sampai ke `PrototypeSlot`. Tekan **E** dan tahan 1,5 detik.
7. Amati simulasi Rani dan kendaraan. Kartu rapor baru muncul setelah simulasi selesai.

Untuk mencoba jalur aman yang tersedia di data saat ini, pilih `1.B`, lalu `2.B2`, `3.B2b`, dan `P.16`. Pilih jawaban tersebut langsung pada panel.

Gunakan **Test → Start** untuk bermain sendiri. Kapasitas server harus diatur menjadi satu pemain agar progres dan keputusan tetap milik pemain yang sedang bermain.

## 6. Bila ada yang tidak muncul

- Lihat pesan merah di **View → Output** dan periksa penulisan nama serta jenis Script/ModuleScript pada tabel.
- Pastikan generator dijalankan di mode Edit dan semua enam objek script serta `Rani_NPC` sudah ada sebelum Play. Jika memperbarui place lama, hapus `ServerScriptService/VotingHandler`.
- Pastikan tiga part bukti menjadi anak langsung `Workspace.InvestigationClues`, papan berada di `Workspace.WarRoom.Whiteboard`, dan Rani punya `HumanoidRootPart` yang tidak terkunci.
- Efek suara bersifat pilihan. Untuk mengaktifkannya, isi properti `SoundId` pada `AssemblySound` dan `HornSound` dengan audio yang dapat digunakan oleh experience.
- Jangan menjalankan `CreateInvestigationClues_CommandBar.lua` atau `CreateSpatialMissions_CommandBar.lua` pada map baru ini; generator tunggal di langkah 2 sudah membuat keduanya beserta seluruh map.

