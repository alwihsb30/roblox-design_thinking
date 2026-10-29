# CrossSafe — Roblox Design Thinking

CrossSafe adalah game pembelajaran Design Thinking untuk merancang penyeberangan sekolah yang aman. Satu server memakai satu tim dan modal awal Rp10.000.000.

## Alur permainan

1. **Misi 1 — Olah TKP:** temukan tiga bukti jalan untuk membuka diskusi dengan Rani.
2. **Tahap 1 — Empathize:** mulai voting bersama melalui Rani.
3. **Tahap 2 — Define:** datangi Whiteboard di Pos Satpam untuk membuka musyawarah.
4. **Tahap 3 — Ideate:** baca minimal satu blueprint di bengkel atau lab komputer.
5. **Tahap 4 — Prototype:** pilih rancangan lewat voting, ambil Tool material di crate, lalu rakit pada PrototypeSlot.
6. **Tahap 5 — Testing:** amati simulasi Rani dan kendaraan. Rapor tampil setelah simulasi.
7. Gunakan Quick Patch atau Deep Pivot sesuai hasil Safety Gate dan saldo tim.

## Setup Roblox Studio

- Untuk mulai dari nol, buat **place Baseplate baru** dan ikuti [Panduan Setup Map Baru](Panduan_Setup_MapBaru_CrossSafe.md).
- Jalankan hanya `CreateCrossSafeFreshMap_CommandBar.lua` di **View → Command Bar** saat mode Edit. Generator ini membuat satu layout graybox lengkap; jangan jalankan generator lama Misi 1/spatial pada map yang sama.
- Tambahkan tujuh script pada layanan yang ditunjukkan di panduan. Nama object harus sama persis dengan nama modul.
- Tambahkan rig `Rani_NPC` dari **Avatar → Rig Builder**. Prompt interaksi dibuat otomatis saat Play.
- Jangan buat `GameNetwork`, RemoteEvent, atau ProximityPrompt manual; server menyiapkannya saat Play. Isi SoundId pada `AssemblySound` dan `HornSound` bila ingin efek audio.

Panduan teknis lengkap ada di [Panduan Roblox Studio](Panduan_Membuat_CrossSafe_di_Roblox_Studio.md); audit alur dan asumsi ada di [Audit setup](CrossSafe_Setup_Audit.md).

Uji gerbang dan progres bersama melalui **Test → Server & Clients**. Sesi, progres, dan ledger bersifat per server dan tidak tersimpan setelah server ditutup.

