# Lightning AI Studio ke HeroMiners

Untuk Nosana, lihat [panduan Nosana](./NOSANA.md) dan
[`nosana-job.json`](./nosana-job.json).

Paket ini menjalankan PeakMiner untuk Pearl/PRL langsung dari terminal Lightning
AI Studio. Paket tidak membuat Studio, memilih GPU, memakai kredit, atau mengubah
provider lain di repository.

## Ringkas

1. Buat/buka Studio di <https://studio.lightning.ai/>.
2. Switch dari CPU ke GPU yang kompatibel (sm_80 atau lebih baru; T4 ditolak).
3. Upload folder ini atau clone repository ke Studio.
4. Jalankan dari terminal Studio:

```bash
cd /teamspace/studios/this_studio
git clone https://github.com/zaimku/lightning.git lightning-ai
cd lightning-ai
chmod +x ./*.sh
bash run.sh 86400
```

Cek status dari terminal kedua:

```bash
bash status.sh
```

Hentikan miner:

```bash
bash stop.sh
```

Untuk meminta batas daya 85% dari daya default GPU, hentikan sesi lama lalu mulai:

```bash
bash stop.sh
GPU_POWER_LIMIT=85% bash run.sh 86400
```

Ini membatasi daya, bukan jumlah core atau utilisasi. GPU bisa tetap melaporkan
utilisasi 100%; tidak menjamin 15% idle. Opsi memerlukan izin driver dan mungkin
ditolak di Studio. Periksa batas daya aktual melalui `bash status.sh` dan log.
Tanpa `GPU_POWER_LIMIT`, skrip tidak meminta perubahan batas daya.

`run.sh` menjalankan workload di background, menunggu GPU aktif, dan baru
menyatakan sukses setelah menemukan accepted share atau timeout verifikasi.

Repo tujuan paket ini adalah `https://github.com/zaimku/lightning`.
Jenis GPU dipilih sendiri di Studio; skrip hanya mendeteksi GPU yang aktif.
Paket ini belum diuji pada GPU Lightning AI nyata.

Konfigurasi default:

- PeakMiner 2.14.0 dengan SHA-256 terpin;
- wallet repository yang sama;
- durasi 86.400 detik;
- semua GPU NVIDIA yang terlihat oleh Studio;
- endpoint HeroMiners diuji dan yang tidak dapat dijangkau dilewati;
- state, binary, dan log disimpan di `~/lightning-herominers/`.

Panduan lengkap: [TUTORIAL-DEPLOY-MANDIRI.md](./TUTORIAL-DEPLOY-MANDIRI.md).
