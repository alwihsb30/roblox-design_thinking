# CrossSafe — Roblox Design Thinking

Game pembelajaran Design Thinking tentang keselamatan penyeberangan sekolah. Sesi tim memakai modal Rp10.000.000, misi lapangan, voting bersama, Safety Gate, Quick Patch, dan Deep Pivot.

## Misi 1: Olah TKP

Sebelum voting Tahap 1 terbuka, tim harus menemukan tiga bukti pada `Workspace/InvestigationClues`:

- `Clue_Rambu` — rambu sekolah tertutup daun.
- `Clue_Marka` — marka zebra cross pudar/licin.
- `Clue_Penerangan` — tiang penerangan mati.

Progres dibagi oleh seluruh pemain di server. `ClueQuestManager` membuat prompt Periksa dan mengunci klaim tiap bukti di server. HUD menampilkan jumlah temuan; Rani belum mengizinkan sesi dimulai sebelum 3/3.

## Setup cepat di Roblox Studio

1. Masukkan `ClueQuestManager.lua` sebagai ModuleScript di `ServerScriptService`; perbarui `GameManager` dan `CrossSafeClient`.
2. Di mode Edit, jalankan isi `CreateInvestigationClues_CommandBar.lua` dari View > Command Bar.
3. Pindahkan Part placeholder ke lokasi bukti pada map. Pastikan nama folder dan Part tidak berubah.
4. Jalankan Play Test, periksa tiga titik, lalu kembali ke Rani setelah tracker mencapai 3/3.

Panduan rinci dan checklist pengujian ada di [Panduan Roblox Studio](Panduan_Membuat_CrossSafe_di_Roblox_Studio.md). Ringkasan otoritas dan asumsi ada di [Audit setup](CrossSafe_Setup_Audit.md).
