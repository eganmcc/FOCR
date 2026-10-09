# Panduan Deploy FOCR Web

Dokumen ini untuk tim DevOps yang **belum pernah men-deploy aplikasi Flutter Web**, untuk
server ini FOCR Web hanyalah **website statis**: kumpulan file HTML, JavaScript, WebAssembly dan
gambar.

- **Tidak perlu** menginstal Flutter, Node.js, PHP, Java, database, atau backend apa pun di server.
- Cukup sajikan isi folder `public/` dengan web server biasa (nginx, Apache, Caddy, IIS, S3 +
  CloudFront, dll).
- Semua proses OCR berjalan **di browser pengguna**. Server hanya mengirim file.

---

## 1. Isi paket

File: `FOCR-web-<versi>.tar.gz` (atau `.zip`, isinya sama). Cek integritasnya dulu dengan checksum
di file `.sha256`:

```bash
shasum -a 256 -c FOCR-web-0.1.0-build4.sha256
# atau: sha256sum -c FOCR-web-0.1.0-build4.sha256
```

Setelah diekstrak:

```
FOCR-web-0.1.0-build4/
├── public/              ← WEB ROOT. Isi folder inilah yang disajikan web server.
│   ├── index.html       ← halaman utama aplikasi
│   ├── main.dart.js     ← kode aplikasi
│   ├── sw.js            ← service worker (mode offline)
│   ├── canvaskit/       ← mesin render Flutter (WebAssembly, ±28 MB)
│   ├── tesseract/       ← mesin OCR + data bahasa (±14 MB)
│   └── ...
├── nginx/focr.conf      ← konfigurasi nginx yang sudah siap pakai
├── Dockerfile           ← untuk deploy sebagai container (opsional)
├── BUILD_INFO.txt       ← versi & build id
└── PANDUAN-DEPLOY.md    ← dokumen ini
```

Ukuran `public/` ±47 MB. Ini wajar, karena mesin render dan mesin OCR ikut dibundel supaya aplikasi
bisa bekerja offline.

---

## 2. Syarat wajib (baca dulu)

| # | Syarat | Kenapa |
|---|---|---|
| 1 | **HTTPS** (sertifikat valid) | Browser hanya mengizinkan **kamera** dan **service worker (offline)** di HTTPS. Di HTTP biasa, fitur scan kamera dan offline **tidak akan jalan**. Pengecualian: `http://localhost` untuk tes lokal. |
| 2 | File `.wasm` dikirim dengan `Content-Type: application/wasm` | Kalau salah, mesin render gagal dimuat dan layar tetap putih. |
| 3 | File `tesseract/lang/eng.traineddata.gz` dikirim **apa adanya**: **tanpa** header `Content-Encoding: gzip` | Mesin OCR membuka kompresi file ini sendiri. Kalau server/CDN menambahkan `Content-Encoding: gzip`, browser membuka kompresinya duluan dan OCR gagal. |
| 4 | `index.html`, `main.dart.js`, `sw.js`, `flutter_bootstrap.js`, `version.json` **tidak di-cache lama** (`Cache-Control: no-cache`) | Nama file Flutter tidak berubah antar versi. Kalau di-cache lama, pengguna tidak mendapat versi baru setelah deploy. |
| 5 | Aplikasi diletakkan di **root domain/subdomain**, mis. `https://focr.perusahaan.co.id/` | Paket ini dibuild untuk path `/`. Kalau harus di sub-path (mis. `/focr/`), lihat bagian 7. |

Semua poin 2–4 **sudah diatur** di `nginx/focr.conf`. Kalau memakai web server lain, terapkan aturan
yang sama secara manual.

---

## 3. Pilihan A: Docker (paling mudah)

Butuh Docker di mesin build/server.

```bash
tar -xzf FOCR-web-0.1.0-build4.tar.gz
cd FOCR-web-0.1.0-build4

docker build -t focr-web:0.1.0-build4 .
docker run -d --name focr-web --restart unless-stopped -p 8080:80 focr-web:0.1.0-build4
```

Cek: `curl -I http://localhost:8080/` harus mengembalikan `HTTP/1.1 200 OK`.

Container ini hanya melayani **HTTP port 80**. Pasang HTTPS di depannya: load balancer, ingress
Kubernetes, reverse proxy (nginx/Traefik/Caddy), atau Cloudflare. Arahkan domain ke container
tersebut.

Untuk Kubernetes, image ini bisa langsung dipakai sebagai Deployment + Service (port 80), dengan TLS
di Ingress. Health check: `GET /version.json` → 200.

---

## 4. Pilihan B: nginx langsung di server (tanpa Docker)

Contoh untuk Ubuntu/Debian.

```bash
# 1. Install nginx (lewati jika sudah ada)
sudo apt update && sudo apt install -y nginx

# 2. Ekstrak paket & salin isi public/ ke web root
tar -xzf FOCR-web-0.1.0-build4.tar.gz
sudo mkdir -p /var/www/focr
sudo rsync -a --delete FOCR-web-0.1.0-build4/public/ /var/www/focr/

# 3. Pasang konfigurasi
sudo cp FOCR-web-0.1.0-build4/nginx/focr.conf /etc/nginx/conf.d/focr.conf
```

Lalu **edit** `/etc/nginx/conf.d/focr.conf`:
- ganti `root  /usr/share/nginx/html;` menjadi `root  /var/www/focr;`
- ganti `server_name _;` menjadi domain Anda, mis. `server_name focr.perusahaan.co.id;`

Pastikan tidak bentrok dengan site default (`/etc/nginx/sites-enabled/default`). Hapus/nonaktifkan
site default jika tidak dipakai.

```bash
# 4. Cek konfigurasi & reload
sudo nginx -t
sudo systemctl reload nginx

# 5. Pasang HTTPS (contoh dengan Let's Encrypt / certbot)
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d focr.perusahaan.co.id
```

Jika sertifikat dari perusahaan (bukan Let's Encrypt), tambahkan `listen 443 ssl;`,
`ssl_certificate` dan `ssl_certificate_key` di blok `server` seperti biasa.

---

## 5. Pilihan C: web server / hosting lain

Prinsipnya sama: **unggah isi folder `public/`** ke web root, lalu terapkan aturan di bagian 2.

- **Apache:** pastikan `AddType application/wasm .wasm`. Untuk `eng.traineddata.gz`, matikan
  `mod_deflate` dan jangan set `Content-Encoding`. Tambahkan header `Cache-Control: no-cache`
  untuk `index.html`, `main.dart.js`, `sw.js`, `flutter_bootstrap.js` dan `version.json`.
- **S3 + CloudFront / GCS / Azure Blob:** unggah isi `public/`. Set metadata `Content-Type` `.wasm`
  = `application/wasm`. Untuk `eng.traineddata.gz` set `Content-Type: application/octet-stream`
  dan **jangan** isi `Content-Encoding`. Set `Cache-Control: no-cache` pada lima file di atas.
  Default root object = `index.html`.

---

## 6. Verifikasi setelah deploy (wajib)

Ganti `https://focr.perusahaan.co.id` dengan domain Anda.

```bash
D=https://focr.perusahaan.co.id

curl -sI $D/                                   | grep -iE "HTTP/|cache-control"
# → 200, cache-control: no-cache

curl -sI $D/canvaskit/canvaskit.wasm           | grep -iE "HTTP/|content-type"
# → 200, content-type: application/wasm

curl -sI $D/tesseract/lang/eng.traineddata.gz  | grep -iE "HTTP/|content-type|content-encoding"
# → 200, content-type: application/octet-stream, dan TIDAK ADA baris content-encoding

curl -s  $D/version.json
# → berisi "version":"0.1.0","build_number":"4"
```

Lalu tes di browser (Chrome di laptop dan di HP Android):
1. Buka domain → muncul halaman **FOCR** dengan tombol *Scan with camera*, *Upload screenshot / photo*,
   *Enter number manually*.
2. **Upload screenshot / photo** → pilih screenshot halaman konfirmasi BCA → nomor registrasi
   (`A03…`) terisi otomatis dalam beberapa detik.
   Upload pertama bisa lebih lama karena data OCR (±11 MB) diunduh sekali.
3. **Scan with camera** → browser meminta izin kamera → preview kamera muncul.
4. **Tes offline:** di Chrome buka DevTools (F12) → tab *Network* → pilih *Offline* → reload halaman.
   Aplikasi harus tetap terbuka dan upload tetap bisa membaca nomor.

---

## 7. Jika harus di sub-path (mis. `https://domain/focr/`)

Lebih disarankan memakai subdomain sendiri. Jika tetap harus di sub-path:

1. Edit `public/index.html`, ganti baris `<base href="/">` menjadi `<base href="/focr/">`
   (harus diawali **dan** diakhiri `/`).
2. Letakkan isi `public/` di lokasi yang disajikan pada `/focr/`.
3. Di konfigurasi nginx, sesuaikan prefix path. Contoh: `map` dan `location` menjadi `/focr/canvaskit/`,
   `/focr/tesseract/`, dst. Fallback SPA menjadi `try_files $uri $uri/ /focr/index.html;`.

Alternatifnya, minta tim developer membuild ulang dengan `BASE_HREF=/focr/ ./tool/build_web.sh`.

---

## 8. Update ke versi baru

1. Ekstrak paket versi baru.
2. Ganti **seluruh** isi web root dengan `public/` yang baru. Gunakan `rsync --delete` atau build
   image Docker baru. Jangan mencampur file versi lama dan baru.
3. Tidak perlu purge cache CDN untuk file `canvaskit/` dan `tesseract/`, kecuali dinyatakan di
   catatan rilis. File aplikasi utama sudah `no-cache`.
4. Pengguna yang sedang membuka aplikasi akan mendapat versi baru setelah **reload** (kadang perlu
   reload 2×, karena service worker memperbarui cache di latar belakang).

**Rollback:** sajikan kembali isi `public/` versi sebelumnya (atau jalankan image Docker versi
sebelumnya). Tidak ada database atau migrasi.

---

## 9. Hal yang perlu diketahui

- **Data tersimpan di browser masing-masing pengguna** (IndexedDB). Belum ada backend: nomor yang
  disimpan tidak terkirim ke server mana pun dan tidak tersinkron antar perangkat.
- Server **tidak menerima upload** apa pun. Gambar diproses dan disimpan di browser pengguna.
- **Content-Security-Policy (CSP):** jika organisasi Anda mewajibkan CSP, minimal izinkan:
  `script-src 'self' 'wasm-unsafe-eval' blob:; worker-src 'self' blob:; connect-src 'self'; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'`.
  CSP yang lebih ketat akan membuat OCR atau tampilan gagal.
- Jangan aktifkan optimasi CDN yang mengubah file JavaScript/WASM (mis. *minify* / *Rocket Loader*
  di Cloudflare). File sudah dioptimasi saat build.

---

## 10. Troubleshooting

| Gejala | Kemungkinan penyebab | Solusi |
|---|---|---|
| Layar putih/kosong | `.wasm` salah content-type, atau ada file yang 404 | DevTools → *Console* & *Network*, cari error merah. Cek bagian 2 poin 2. |
| Tombol *Scan with camera* tidak muncul / kamera ditolak | Situs dibuka lewat HTTP, atau izin kamera diblokir | Pakai HTTPS. Cek izin kamera di pengaturan situs browser. |
| Upload selalu "No valid registration number found" padahal gambar jelas | `eng.traineddata.gz` dikirim dengan `Content-Encoding: gzip` | Cek dengan `curl -sI` (bagian 6) dan hapus `Content-Encoding` untuk file itu. |
| Setelah deploy, pengguna masih melihat versi lama | Cache terlalu lama pada `index.html`/`main.dart.js`/`sw.js` | Pastikan `Cache-Control: no-cache` untuk file tersebut, lalu minta pengguna reload. |
| Error 404 untuk `/canvaskit/...` atau `/tesseract/...` saat di sub-path | `<base href>` belum disesuaikan | Lihat bagian 7. |

Jika masih bermasalah, kirim ke tim developer: URL, screenshot tab *Console* dan *Network* dari
DevTools, serta output perintah verifikasi di bagian 6.
