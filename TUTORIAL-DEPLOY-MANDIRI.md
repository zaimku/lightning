# Tutorial deploy mandiri - Lightning AI Studio

Panduan ini menggunakan terminal Studio, bukan notebook. Lightning menyatakan
skrip terminal tetap berjalan saat browser ditutup, sedangkan notebook memiliki
batasan berbeda untuk background execution.

## 1. Buat atau buka Studio

Buka <https://studio.lightning.ai/> lalu buat Studio atau hidupkan Studio yang
sudah ada. Studio biasanya mulai pada mesin CPU. Gunakan pemilih mesin di kanan
atas untuk switch ke GPU sebelum menjalankan miner.

Pilih GPU dengan compute capability 8.0 atau lebih baru, misalnya:

- L4 atau L40S;
- A10;
- RTX 30/40 series;
- A100;
- H100/H200;
- B200.

T4/sm_75 ditolak oleh preflight karena workload Pearl saat ini tidak cocok.
Ketersediaan tipe GPU mengikuti pilihan yang benar-benar ditampilkan pada akun
dan Teamspace Anda; skrip tidak menebak atau membeli mesin.

## 2. Masukkan paket ke Studio

### Opsi A - clone repository

Dari terminal Studio:

```bash
cd /teamspace/studios/this_studio
git clone https://github.com/zaimku/lightning.git lightning-ai
cd lightning-ai
```

Perintah di atas untuk repo mandiri yang berisi `run.sh` di root.
Jika memakai repo lengkap `alphapool-modal`, masuk ke subfolder
`providers/lightning-ai` setelah clone.

### Opsi B - upload memakai Lightning CLI

Pada PowerShell lokal, pasang CLI dan login:

```powershell
py -m pip install --upgrade lightning-sdk
```

```powershell
lightning login
```

Lihat nama Studio dan Teamspace:

```powershell
lightning studio list
```

Upload folder provider:

```powershell
lightning studio cp -r .\providers\lightning-ai lit://OWNER/TEAMSPACE/studios/STUDIO-NAME/lightning-ai
```

Masuk melalui SSH resmi Lightning:

```powershell
lightning studio ssh --teamspace OWNER/TEAMSPACE --name STUDIO-NAME
```

Di Studio:

```bash
cd /teamspace/studios/this_studio/lightning-ai
```

## 3. Jalankan 24 jam

Berikan permission eksekusi sekali:

```bash
chmod +x ./*.sh
```

Jalankan:

```bash
bash run.sh 86400
```

Worker dibuat otomatis dengan prefix `lightning`. Untuk nama tetap:

```bash
bash run.sh 86400 lightning01
```

Runner melakukan hal berikut:

1. menolak start jika miner lain masih aktif;
2. memastikan Studio benar-benar memakai GPU NVIDIA;
3. menolak GPU dengan compute capability di bawah 8.0;
4. mencari `libstdc++` yang menyediakan `GLIBCXX_3.4.29`;
5. mengunduh PeakMiner dan memverifikasi SHA-256 sebelum eksekusi;
6. menguji setiap endpoint pool dan melewati endpoint yang tidak dapat dicapai;
7. menjalankan miner dengan `nohup`;
8. menunggu accepted share hingga 180 detik.

Browser boleh ditutup setelah proses dimulai. Workload terminal tetap berjalan di
background dan Studio yang sedang menjalankan workload tidak dianggap idle.

## 4. Durasi dan konfigurasi custom

Durasi dapat berupa `0` untuk tanpa timer, atau 60 sampai 86.400 detik. Contoh
enam jam:

```bash
bash run.sh 21600
```

Tanpa timer internal (berjalan sampai dihentikan manual atau Studio berhenti):

```bash
bash run.sh 0 lightning01
```

Wallet custom hanya untuk command tersebut:

```bash
PEARL_WALLET="prl1..." bash run.sh 86400 lightning02
```

Pool custom, dipisahkan koma tanpa spasi:

```bash
POOL_ENDPOINTS="sg.pearl.herominers.com:1200,hk.pearl.herominers.com:1200" bash run.sh 86400
```

Urutan pool default:

```text
us2 -> us -> sg -> hk -> de
```

Preflight TCP menyaring endpoint yang tidak dapat dijangkau. PeakMiner menerima
endpoint tersisa sebagai primary dan failover sesuai urutan.

## 5. Status dan log

### Mengurangi daya GPU (opsional)

Untuk memperbarui repo mandiri dan meminta batas daya 85%:

```bash
cd /teamspace/studios/this_studio/lightning
bash stop.sh
git pull --ff-only
GPU_POWER_LIMIT=85% bash run.sh 86400
bash status.sh
```

Jika folder clone bernama `lightning-ai`, sesuaikan perintah `cd`.
Variabel diwariskan ke runner background. Nilai yang diterima adalah `1%` sampai
`100%`; driver bisa menolak nilai di bawah batas minimum hardware.
Runner memeriksa apakah binary yang digunakan mendukung `--gpu-power`.

`85%` berarti 85% dari batas daya default, bukan 85% utilisasi atau 85% core.
Tidak ada jaminan 15% idle atau kapasitas khusus untuk aplikasi lain. Hashrate
bisa turun dan utilisasi masih bisa 100%. Batas VRAM tidak berubah.

Penerapan membutuhkan izin driver/NVML; container Lightning dapat menolaknya.
`GPU_POWER_LIMIT_REQUESTED` hanya mencatat permintaan. Periksa `GPU_POWER_LIMITS`
di `status.sh`: configured/enforced menunjukkan batas aktual dalam watt, dan
bandingkan dengan default. Periksa pesan error di `current.log`/`launcher.log`.
Miner yang aktif dan accepted belum membuktikan pembatasan daya berhasil.
Jika batas tidak berubah, hentikan miner dan periksa akses pengaturan GPU
dengan penyedia; jangan menganggap mode hemat sudah aktif.

Untuk menjalankan tanpa meminta batas daya baru, hentikan miner lalu jalankan
`bash run.sh 86400` tanpa variabel tersebut. Ini tidak menjamin pengaturan driver
sebelumnya sudah kembali; periksa batas aktual setelah sesi berhenti.

Referensi opsi resmi: <https://github.com/peakminer/peakminer#cli-reference>.
Mode ini belum diuji pada GPU Lightning nyata.

### Memeriksa proses

Dari terminal Studio lain:

```bash
cd /teamspace/studios/this_studio/lightning-ai
bash status.sh
```

Jika memakai repo lengkap, sesuaikan path ke folder provider hasil clone.

Status sehat mempunyai:

- `STATUS=RUNNING`;
- utilization GPU tinggi;
- `ACCEPTED` terus bertambah;
- `REJECTED=0` atau tidak bertambah berulang;
- event `connected`, `new job`, dan `vardiff`.

Ikuti log aktif:

```bash
tail -f ~/lightning-herominers/current.log
```

Output setup/launcher:

```bash
tail -f ~/lightning-herominers/launcher.log
```

Semua log sesi berada di:

```text
~/lightning-herominers/logs/
```

## 6. Menghentikan miner

```bash
bash stop.sh
```

Setelah miner berhenti, Studio dapat auto-sleep. Untuk menghentikan pemakaian GPU
segera, gunakan tombol mesin di kanan atas dan pilih sleep/stop. Jangan menghapus
Studio jika file persisten masih dibutuhkan.

## 7. Restart Studio

File di home Studio dan `/teamspace/studios/this_studio` bersifat persisten, jadi
binary dan log tidak perlu diunduh ulang. Namun Studio biasanya restart pada CPU.
Switch kembali ke GPU sebelum menjalankan `run.sh` lagi.

Paket tidak memasang miner ke `.lightning_studio/on_start.sh`. Auto-start sengaja
tidak digunakan agar miner tidak mencoba berjalan ketika Studio bangun pada CPU
atau ketika pengguna hanya ingin membuka file.

## 8. Troubleshooting

### `GPU NVIDIA tidak terdeteksi`

Studio masih memakai mesin CPU. Switch ke GPU lalu ulangi `run.sh`.

### GPU ditolak sebagai `sm_75`

Itu biasanya T4. Pilih L4, A10, A100, RTX 30/40, H100, atau GPU sm_80+ lain.

### `GLIBCXX_3.4.29 tidak ditemukan`

Gunakan Base Studio Linux yang lebih baru atau perbarui paket `libstdc++6` pada
Studio. Skrip juga otomatis mencari library kompatibel di `/opt/conda`,
`$CONDA_PREFIX`, dan Miniconda milik user tanpa membuat virtual environment baru.

### Tidak ada endpoint pool yang dapat dijangkau

Periksa DNS serta egress TCP port 1200. Override `POOL_ENDPOINTS` dengan endpoint
yang dapat dicapai dari region/cloud tempat Studio berjalan.

### Proses hidup tetapi accepted tetap nol

Periksa `current.log`. Pastikan ada `new job`, GPU tidak `ERR`, utilization naik,
dan tidak ada rejected berulang. `run.sh` memberi peringatan bila accepted belum
muncul setelah 180 detik tanpa otomatis membuat miner kedua.

### Studio tidur sebelum pekerjaan selesai

Pastikan proses memang masih hidup lewat `status.sh`. Menurut dokumentasi
Lightning, Studio yang menjalankan workload tidak dihitung idle. Periksa juga
pengaturan auto-sleep Teamspace/Studio bila mesin tetap berhenti.

## 9. Dokumentasi teknis resmi yang dipakai

- <https://lightning.ai/docs/overview/ai-studio/>
- <https://lightning.ai/docs/overview/ai-studio/background-execution>
- <https://lightning.ai/docs/overview/ai-studio/auto-sleep>
- <https://lightning.ai/docs/overview/ai-studio/environment-persistence>
- <https://lightning.ai/docs/overview/cli/studio>
- <https://lightning.ai/docs/overview/ai-studio/on-start-actions>
