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

- Masukkan `DecisionTreeData.lua` ke `ReplicatedStorage` sebagai ModuleScript.
- Masukkan `GameManager.lua` sebagai Script serta `ClueQuestManager.lua`, `SpatialMissionManager.lua`, `VotingHandler.lua`, dan `EvaluationService.lua` sebagai ModuleScript di `ServerScriptService`.
- Masukkan `CrossSafeClient.client.lua` sebagai LocalScript di `StarterGui`.
- Jalankan `CreateInvestigationClues_CommandBar.lua` dan `CreateSpatialMissions_CommandBar.lua` melalui **View → Command Bar** saat mode Edit.
- Pindahkan graybox dan marker ke lokasi map sebenarnya. Pastikan Rani punya Humanoid dan HumanoidRootPart, serta jalur ke Crosswalk_Destination bebas penghalang.
- Isi SoundId pada `AssemblySound` dan `HornSound` dengan audio yang dapat dipakai experience.

Prompt dibuat oleh script server saat Play. Jangan buat salinan `GameNetwork`/RemoteEvent secara manual. Panduan lengkap ada di [Panduan Roblox Studio](Panduan_Membuat_CrossSafe_di_Roblox_Studio.md); audit alur dan asumsi ada di [Audit setup](CrossSafe_Setup_Audit.md).

Uji gerbang dan progres bersama melalui **Test → Server & Clients**. Sesi, progres, dan ledger bersifat per server dan tidak tersimpan setelah server ditutup.

