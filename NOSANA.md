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

## Auto-start pada setiap job strategi Infinite

Perintah terminal di atas hanya berlaku untuk container Revision 1 yang sedang
aktif. Ketika strategi Infinite mengganti job setelah timeout, container baru
tidak otomatis mengulang perintah manual.

Untuk auto-start:

1. Stop deployment lama agar tidak ada dua job yang memakai GPU/kredit.
2. Edit job definition dan buat Revision baru.
3. Ganti seluruh job definition dengan isi [`nosana-job.json`](./nosana-job.json).
4. Pertahankan GPU market RTX 4090, strategy `INFINITE`, timeout 6 jam, dan satu
   replica.
5. Start deployment dan pantau bagian **Logs**.

Revision ini tidak menjalankan Jupyter dan tidak mengekspos port 8888. Container
langsung mengambil skrip dari GitHub lalu menjalankan PeakMiner di foreground. Variabel
`LOG_TO_STDOUT=1` menyalin log miner ke log job Nosana sehingga event
`connected`, `new job`, `accepted`, dan `rejected` terlihat di dashboard.

Nilai durasi runner pada revision adalah `0` (tanpa timer internal). Timeout enam
jam tetap merupakan batas milik Nosana. Strategy `INFINITE` harus membuat job
pengganti agar mining berlanjut setelah container lama dihentikan platform.

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
