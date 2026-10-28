# CrossSafe — Roblox Design Thinking

Game pembelajaran Design Thinking untuk merancang penyeberangan sekolah yang aman. Sesi tim memiliki anggaran awal Rp10.000.000, voting bersama, Safety Gate, Quick Patch, dan Deep Pivot.

## Mulai di Roblox Studio

1. Buat Baseplate dan tambahkan ModuleScript `DecisionTreeData` ke `ReplicatedStorage`.
2. Tambahkan `GameManager` (Script), `VotingHandler` (ModuleScript), dan `EvaluationService` (ModuleScript) ke `ServerScriptService`.
3. Tambahkan `CrossSafeClient.client.lua` sebagai LocalScript ke `StarterGui`. Hapus/nonaktifkan GUI atau LocalScript CrossSafe lama agar tidak ada duplikat yang selalu tampil.
4. Tambahkan Model bernama `Rani_NPC` sebagai anak langsung `Workspace`. Model harus berisi HumanoidRootPart, Head, PrimaryPart, atau Part lain. Server membuat ProximityPrompt `TalkToRaniPrompt` otomatis.
5. Jalankan game dan dekati Rani. Tekan prompt **Ajak bicara**, baca dialog pembuka, lalu pilih **Mulai diskusi bersama Rani**. GUI tidak tampil dan voting tidak berjalan sebelum interaksi ini.
6. Untuk model visual, tambahkan `ServerStorage/PrototypeModels` dan `Workspace/InteractionStation/PrototypeSlot`; daftar nama model ada di panduan.

## Berkas

- [Panduan lengkap Roblox Studio](Panduan_Membuat_CrossSafe_di_Roblox_Studio.md)
- [Audit setup dan asumsi gameplay](CrossSafe_Setup_Audit.md)
- Backend: `DecisionTreeData.lua`, `VotingHandler.lua`, `GameManager.lua`, `EvaluationService.lua`
- UI: `CrossSafeClient.client.lua`

Uji voting di tab **Test** menggunakan **Server & Clients** dengan tiga klien. Runtime Roblox Studio masih perlu diverifikasi setelah file dipasang.
