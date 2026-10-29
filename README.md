# CrossSafe — Roblox Design Thinking

CrossSafe adalah game edukasi Design Thinking untuk merancang penyeberangan sekolah yang aman. Permainan dirancang untuk **satu pemain per server** dengan modal awal Rp10.000.000. Pilihan Tahap 1–4 langsung menjadi keputusan pemain, tanpa voting atau menunggu pemain lain.

## Alur permainan

1. Temukan tiga bukti bahaya di jalan.
2. Bicara dengan Rani dan mulai sesi.
3. Pilih jawaban Empathize berdasarkan kebutuhan Rani.
4. Bawa temuan ke Whiteboard Pos Satpam untuk membuka Define.
5. Baca satu blueprint di bengkel atau lab untuk membuka Ideate.
6. Pilih prototipe, ambil material, lalu rakit di PrototypeSlot.
7. Amati simulasi penyeberangan, baca rapor, lalu pilih Quick Patch atau Deep Pivot jika tersedia.

## Setup Roblox Studio

- Buat place Baseplate baru dan ikuti [Panduan Setup Map Baru](Panduan_Setup_MapBaru_CrossSafe.md).
- Atur kapasitas **Maximum Players** menjadi **1** pada pengaturan place.
- Jalankan `CreateCrossSafeFreshMap_CommandBar.lua` sekali di **View → Command Bar** saat mode Edit.
- Pasang enam objek script: empat Script/ModuleScript di `ServerScriptService`, satu ModuleScript di `ReplicatedStorage`, dan satu LocalScript di `StarterGui`. Nama dan lokasi lengkap tercantum di panduan setup.
- Jika memperbarui place lama, hapus `ServerScriptService/VotingHandler` dan ganti isi script sesuai file pada branch ini.
- Tambahkan rig `Rani_NPC` dari **Avatar → Rig Builder** sebelum Play. Prompt dibuat otomatis saat server mulai.
- Jangan membuat `GameNetwork`, RemoteEvent, atau ProximityPrompt manual. Isi SoundId pada `AssemblySound` dan `HornSound` jika ingin efek audio.

Roblox mengatur kapasitas pemain dari pengaturan place. Sesi, misi, dan saldo di memori akan direset saat pemain keluar dan server memulai sesi baru.
