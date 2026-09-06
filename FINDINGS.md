# Catatan desain provider Lightning AI

Paket ini dibuat berdasarkan dokumentasi teknis resmi Lightning AI yang diperiksa
pada 6 September 2026. Pemeriksaan Terms of Service sengaja tidak dilakukan
sesuai permintaan pengguna.

## Fakta platform yang memengaruhi desain

- Studio dimulai melalui browser dan dapat di-switch dari CPU ke mesin GPU.
- Terminal Studio mendukung pekerjaan background setelah browser ditutup.
- Studio yang sedang menjalankan workload tidak dianggap idle; setelah pekerjaan
  selesai, auto-sleep dapat menghentikan mesin.
- File di home dan `/teamspace/studios/this_studio` dipersistenkan saat sleep atau
  perpindahan mesin.
- Studio umumnya restart pada CPU kecuali pengaturan Teamspace diubah.
- Lightning CLI mendukung `studio cp`, `studio list`, dan `studio ssh`.
- On-start action berada di `~/.lightning_studio/on_start.sh`, tetapi paket ini
  tidak memakainya karena miner tidak boleh otomatis mencoba start pada CPU.
- Lightning menyatakan additional virtual environment tidak didukung di Studio;
  karena itu paket mencari library C++ yang sudah ada dan tidak membuat Conda
  environment baru.

## Keputusan implementasi

- Semua runtime disimpan di `~/lightning-herominers/`, yaitu storage persisten.
- `run.sh` menjalankan core miner dengan `nohup`, merekam PID, lalu memverifikasi
  accepted share.
- `status.sh` dan `stop.sh` dapat dipakai dari terminal kedua.
- Preflight membaca compute capability dari `nvidia-smi` dan menolak sm_75/T4.
- Satu proses PeakMiner memakai semua GPU NVIDIA yang terlihat.
- PeakMiner dipin ke 2.14.0 dengan SHA-256
  `8c03a1f790a54dd05d5ca75e8bfb3b1a8c3e7db24fd2a33f43c8b38bbf164646`.
- URL GitHub resmi dicoba lebih dahulu. Mirror hanya menjadi fallback dan hasilnya
  tetap wajib cocok dengan checksum terpin.
- Pool tidak dipilih berdasarkan asumsi region. Lima endpoint diuji dari Studio
  dan hanya yang benar-benar dapat dijangkau yang digunakan.
- HTTP API miner dinonaktifkan dengan `--api-port 0`; tidak ada port Studio yang
  perlu diekspos.

## Yang belum diverifikasi langsung

- Tidak ada akun, Studio ID, atau GPU Lightning yang diberikan pada sesi ini.
- Skrip belum dijalankan pada mesin Lightning nyata.
- Jenis GPU, image Linux, versi driver, latency pool, hashrate, power, dan biaya
  aktual harus dicatat saat uji pertama.
- Daftar mesin dapat berbeda menurut cloud, Teamspace, tier, dan availability.

## Checklist uji pertama

1. Catat GPU, compute capability, driver, OS, dan filesystem.
2. Pastikan preflight memilih `libstdc++` yang benar.
3. Pastikan binary lolos SHA-256.
4. Catat endpoint pool yang lolos tes TCP dan latency miner.
5. Pastikan log menunjukkan `connected`, `new job`, dan `vardiff`.
6. Pastikan utilization GPU tinggi dan tidak berstatus `ERR`.
7. Tunggu accepted share serta pastikan rejected tidak bertambah berulang.
8. Tutup browser sebentar dan pastikan proses tetap hidup.
9. Jalankan `stop.sh`, lalu pastikan Studio sleep/stop dan pemakaian GPU berhenti.

