# 🚀 ZiVPN UDP Tunnel
### *Autoscript by PeyxDev*

> **Solusi tunneling UDP premium** dengan manajemen modern, aman, dan otomatis. Kelola server VPN Anda melalui **API powerful** atau **Bot Telegram** yang cerdas dengan sistem pembayaran **QRIS Dinamis**.

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Node](https://img.shields.io/badge/Node.js-20.x-darkgreen)

---

## ✨ Fitur Unggulan

| Fitur | Keterangan |
| :--- | :--- |
| **Instalasi Modern** | Tampilan *installer* yang bersih, elegan, dan informatif dengan animasi loading. |
| **Manajemen Headless** | Kelola user sepenuhnya via **API** atau **Bot Telegram**, tanpa perlu ribet di CLI. |
| **Bot Telegram Canggih** | Semua fungsi (Tambah, Hapus, Perpanjang, Lihat User) bisa dilakukan dari Telegram. |
| **QRIS Dinamis** | Pembayaran otomatis dengan QRIS dinamis, nominal sesuai durasi yang dipilih. |
| **Upload Bukti Langsung** | Setelah bayar, upload bukti dan akun LANGSUNG dibuat tanpa menunggu admin. |
| **Keamanan Dinamis** | **API Key** dan **Sertifikat SSL** di-generate secara otomatis saat instalasi. |
| **Kinerja Tinggi** | Menggunakan *core* UDP ZiVPN yang dioptimalkan untuk lingkungan Linux AMD64. |
| **API Terintegrasi** | REST API siap pakai untuk integrasi dengan panel atau aplikasi Anda. |

---

## 💳 Sistem Pembayaran QRIS Dinamis

Bot menggunakan **QRIS Dinamis** yang terintegrasi dengan API eksternal untuk generate QR Code secara real-time.

### 🔄 Alur Pembayaran:
1. User memilih durasi berlangganan
2. Bot menghitung total harga (`Durasi x Harga Harian`)
3. Bot memanggil API QRIS Dinamis untuk generate QR Code
4. QR Code dikirim ke user dengan nominal yang sudah ditentukan
5. User melakukan pembayaran via QRIS
6. User mengupload bukti pembayaran
7. **Akun LANGSUNG dibuat secara otomatis** (tanpa konfirmasi admin)

### 📌 Konfigurasi QRIS di `bot-config.json`:
```json
{
    "qris": {
        "static_string": "00020101021126610014COM.GO-JEK.WWW...",
        "api_url": "https://api-mininxd.vercel.app/qris",
        "icon_url": "https://pxstore.web.id/assets/images/icon.ico",
        "qr_size": 400,
        "icon_size": 80
    }
}
```
📥 Instalasi
Jalankan perintah satu baris ini di terminal VPS Anda sebagai user root:

bash
wget -q https://raw.githubusercontent.com/PeyxDev/ZiVPN/main/install.sh && chmod +x install.sh && ./install.sh
⚙️ Langkah Konfigurasi Instalasi
Anda akan diminta memasukkan informasi berikut:

Domain: Wajib diisi! Digunakan untuk generate sertifikat SSL (contoh: vpn.domain.com).

Bot Token: Token dari @BotFather.

Admin ID: ID Telegram Anda (cek di @userinfobot).

Harga Harian: Harga per hari dalam Rupiah (IDR).

Batas IP Default: Batas maksimal perangkat yang terhubung per akun.

QRIS Configuration (Opsional):

QRIS String: Tekan Enter untuk menggunakan default

API URL: Tekan Enter untuk menggunakan default

Icon URL: Tekan Enter untuk menggunakan default (atau kosongkan jika tidak ingin icon)

🤖 Panduan Bot Telegram
📌 Menu Utama Bot:
🛒 BELI AKUN PREMIUM - Membeli akun via QRIS Dinamis

🎫 TRIAL 30 MENIT - Mencoba akun gratis 30 menit

📊 SYSTEM INFO - Informasi server dan sistem

📞 HUBUNGI ADMIN - Kontak admin via Telegram

💎 Flow Pembelian Akun Premium:
Klik 🛒 BELI AKUN PREMIUM

Masukkan Password/Username (3-20 karakter)

Masukkan Durasi (1-365 hari)

Bot mengirimkan QRIS Dinamis dengan nominal sesuai durasi

User scan QRIS dan melakukan pembayaran

User mengupload foto bukti pembayaran

Akun LANGSUNG AKTIF - Password dan detail dikirim ke user

🎫 Trial 30 Menit:
Gratis, tanpa pembayaran

IP Limit: 1 Device

Akun otomatis kadaluarsa setelah 30 menit

👑 Admin Commands:
Command	Fungsi
/users	Lihat semua user terdaftar
/stats	Lihat statistik user (Total, Aktif, Expired, Locked)
/create username days [iplimit]	Buat user manual
/delete username	Hapus user
🔌 Dokumentasi API
API server berjalan di port 8585.

Informasi Dasar:
Base URL: http://<IP-VPS>:8585

Header: X-API-Key: <API-KEY-ANDA>

Response Format: JSON

Endpoint API:
Method	Endpoint	Deskripsi
GET	/api/health	Cek kesehatan API
GET	/api/system/info	Informasi sistem server
GET	/api/users	Lihat semua user
GET	/api/users/stats	Statistik user
POST	/api/user/create	Buat user baru
POST	/api/user/delete	Hapus user
POST	/api/user/renew	Perpanjang user
POST	/api/user/trial	Buat trial 30 menit
POST	/api/user/lock	Kunci user
POST	/api/user/unlock	Buka kunci user
GET	/api/service/status	Status service
Contoh API Call:
bash
# Create user
curl -X POST http://localhost:8585/api/user/create \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"password":"user123","days":30,"ip_limit":2}'

# List users
curl -H "X-API-Key: YOUR_API_KEY" \
  http://localhost:8585/api/users

# System info
curl -H "X-API-Key: YOUR_API_KEY" \
  http://localhost:8585/api/system/info
🛠️ Manajemen Service
Perintah Dasar:
bash
# Start semua service
systemctl start zivpn zivpn-api-js zivpn-bot

# Stop semua service
systemctl stop zivpn zivpn-api-js zivpn-bot

# Restart semua service
systemctl restart zivpn zivpn-api-js zivpn-bot

# Cek status service
systemctl status zivpn zivpn-api-js zivpn-bot

# Lihat log
journalctl -u zivpn -f
journalctl -u zivpn-api-js -f
journalctl -u zivpn-bot -f
Lokasi File Penting:
File	Lokasi	Keterangan
Konfigurasi Utama	/etc/zivpn/config.json	Port, SSL, dll
Database User	/etc/zivpn/users.json	Data semua user
API Key	/etc/zivpn/apikey	Kunci untuk akses API
Domain	/etc/zivpn/domain	Domain server
Konfigurasi Bot	/etc/zivpn/bot-config.json	Token, harga, QRIS
Script API	/etc/zivpn/api/api.js	Source code API
Script Bot	/etc/zivpn/bot/bot-seller.js	Source code bot
🐛 Pemecahan Masalah
1. Bot Tidak Merespon
bash
# Cek status
systemctl status zivpn-bot

# Restart bot
systemctl restart zivpn-bot

# Cek log error
journalctl -u zivpn-bot -n 50
2. API Error 401 Unauthorized
bash
# Cek API Key
cat /etc/zivpn/apikey

# Test API
curl -H "X-API-Key: $(cat /etc/zivpn/apikey)" \
  http://localhost:8585/api/health
3. QRIS Tidak Muncul
bash
# Cek konfigurasi QRIS
cat /etc/zivpn/bot-config.json | grep -A 5 "qris"

# Test API QRIS
curl "https://api-mininxd.vercel.app/qris?qris=test&nominal=10000"
4. Service Gagal Start
bash
# Cek log detail
journalctl -u zivpn-api-js -n 50

# Cek port 8585
netstat -tlnp | grep 8585

# Jalankan manual untuk debug
cd /etc/zivpn/api && node api.js
🗑️ Uninstall
Untuk menghapus ZiVPN, API, Bot, dan semua konfigurasi:

bash
wget -q https://raw.githubusercontent.com/PeyxDev/ZiVPN/main/uninstall.sh && chmod +x uninstall.sh && ./uninstall.sh
📞 Dukungan
Telegram: @PeyxDev

GitHub: PeyxDev/ZiVPN

<div align="center"> <sub>Built with ❤️ by <b>PeyxDev</b></sub> </div> ```
This response is AI-generated, for reference only.
