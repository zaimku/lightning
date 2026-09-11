# Pearl/PRL di Nosana

## Jalankan sekarang dari terminal Jupyter

Deployment template PyTorch yang sudah aktif menyediakan JupyterLab dan
terminal. Buka endpoint, pilih **File > New > Terminal**, lalu jalankan satu
perintah berikut:

```bash
python3 -c 'import urllib.request; urllib.request.urlretrieve("https://raw.githubusercontent.com/zaimku/lightning/main/nosana-start.sh", "/tmp/nosana-start.sh")' && bash /tmp/nosana-start.sh
```

Bootstrap memakai durasi `0`, artinya miner tidak memiliki timer internal dan
terus berjalan sampai dihentikan manual atau container dihentikan Nosana.
Perintah `run.sh` menjalankan miner di background, menunggu sampai accepted
share, lalu mengembalikan prompt terminal. Jupyter dan deployment harus tetap
hidup.

Setiap start/deploy otomatis membuat nama worker baru dengan format:

```text
nosana-<ID acak 128-bit, 32 karakter heksadesimal>
```

Contoh: `nosana-6c2cb94181094fbfae441c31a7289dd8`. ID berasal dari generator UUID
kernel Linux, bukan dari `$RANDOM`, timestamp, hostname, atau nomor urut pendek.
Peluang dua deployment menghasilkan ID yang sama dapat diabaikan secara praktis.

Bootstrap memakai `python3` bawaan image dan tidak membutuhkan `git` atau
`curl`. Jika `curl` tersedia pada image lain, skrip tetap dapat memakainya.

Cek status dari terminal yang sama atau terminal baru:

```bash
cd /workspace/lightning && bash status.sh
```

Ikuti log:

```bash
tail -f /root/lightning-herominers/current.log
```

Hentikan miner:

```bash
cd /workspace/lightning && bash stop.sh
```

## Berjalan terus tanpa overlap dua GPU

Perintah terminal di atas hanya berlaku untuk container Revision 1 yang sedang
aktif. Jangan memakai strategy `INFINITE` untuk akun yang hanya mengizinkan satu
GPU: strategi itu menjadwalkan job pengganti sebelum job lama mencapai timeout,
sehingga keduanya dapat overlap.

Gunakan strategy `SIMPLE-EXTEND`. Pada setiap timeout enam jam, Nosana
memperpanjang job yang sama untuk periode enam jam berikutnya, bukan menyiapkan
job/GPU pengganti.

Strategy bukan bagian dari `nosana-job.json` dan tidak dapat diganti melalui
revision job definition. Dokumentasi API Nosana juga tidak menyediakan operasi
untuk mengubah strategy deployment aktif. Karena itu:

1. Stop deployment `INFINITE` lama.
2. Tunggu sampai statusnya `STOPPED` dan tidak ada job/replica aktif.
3. Buat deployment baru agar tidak terjadi overlap.
4. Pakai isi [`nosana-job.json`](./nosana-job.json) sebagai job definition.
5. Pilih GPU market RTX 4090, strategy `SIMPLE-EXTEND`, timeout 360 menit, dan
   satu replica.
6. Start deployment dan pantau bagian **Logs**.

Revision ini tidak menjalankan Jupyter dan tidak mengekspos port 8888. Container
langsung mengambil skrip dari GitHub lalu menjalankan PeakMiner di foreground. Variabel
`LOG_TO_STDOUT=1` menyalin log miner ke log job Nosana sehingga event
`connected`, `new job`, `accepted`, dan `rejected` terlihat di dashboard.

Nilai durasi runner pada revision adalah `0` (tanpa timer internal). Timeout enam
jam tetap merupakan lease milik Nosana. `SIMPLE-EXTEND` memperpanjang lease itu;
skrip miner sendiri tidak dan tidak perlu mereset timer Nosana. Miner tetap
memakai worker ID yang sama selama job/container yang sama diperpanjang. Jika
deployment benar-benar dimulai ulang dan container baru dibuat, worker ID baru
akan dibuat otomatis.

Perpanjangan berhenti jika saldo/kredit tidak cukup, deployment dihentikan, atau
job gagal. Berbeda dari `INFINITE`, `SIMPLE-EXTEND` tidak ditujukan untuk membuat
replica pengganti sebelum timeout.

Tanda sehat:

- preflight menampilkan NVIDIA GeForce RTX 4090 dan compute capability 8.9;
- setidaknya satu endpoint HeroMiners lolos tes koneksi;
- log berisi `connected`, `new job`, dan `accepted`;
- GPU utilization naik dan rejected tidak bertambah terus-menerus.

## Keamanan endpoint Revision 1

Template Jupyter Nosana menonaktifkan token dan password. Jangan membagikan URL
endpoint. Setelah Revision miner aktif, stop container Jupyter lama supaya
terminal root publik dan biaya job lama tidak tetap berjalan.

## Referensi Nosana

- <https://docs.nosana.com/deployments/jobs/job-definition/schema.html>
- <https://docs.nosana.com/deployments/strategies.html>
- <https://docs.nosana.com/api/manage-deployments.html>
