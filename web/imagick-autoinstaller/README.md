# PHP Imagick Auto Installer

Skrip otomatis untuk install ekstensi PHP Imagick di Laragon dan Laravel Herd (Windows).

## Deskripsi

Skrip ini secara otomatis mendeteksi semua versi PHP yang terpasang di Laragon dan Laravel Herd, mendownload DLL Imagick yang sesuai dari PECL, menginstalnya ke direktori ekstensi PHP, dan mengaktifkannya di `php.ini`.

## Isi Proyek

- `scripts/imagick-autoinstaller.ps1`: Skrip PowerShell utama.
- `index.html`: Tutorial interaktif langkah-demi-langkah.

## Cara Penggunaan

### Metode Cepat (PowerShell)

**1. Instalasi Standar**
Gunakan ini untuk instalasi baru atau menambah ekstensi:
```powershell
powershell -ExecutionPolicy Bypass -Command "irm http://script.minicenter.my.id/scripts/imagick-autoinstaller.ps1 | iex"
```

**2. Force Reinstall / Repair**
Gunakan ini jika Imagick sudah terpasang tapi error (misal: *Startup Error*), atau ingin mengulang instalasi di semua versi:
```powershell
powershell -ExecutionPolicy Bypass -Command "$s=irm http://script.minicenter.my.id/scripts/imagick-autoinstaller.ps1; &([scriptblock]::Create($s)) -Force"
```

### Metode Tutorial (Web)

1. Akses [script.minicenter.my.id/web/imagick-autoinstaller/](http://script.minicenter.my.id/web/imagick-autoinstaller/)
2. Ikuti panduan visual yang disediakan di halaman tersebut.
3. Gunakan tombol **Salin** untuk mengambil perintah dan tempelkan ke PowerShell.

## Fitur

- Deteksi otomatis Laragon dan Laravel Herd.
- Pencarian otomatis DLL versi TS (Thread Safe) atau NTS (Non-Thread Safe) serta arsitektur x64/x86.
- Aktivasi otomatis di `php.ini`.
- Support instalasi ke semua versi PHP sekaligus.

## Prasyarat

- Hak akses Administrator.
- Koneksi internet aktif.

---
*Developed by farrasrayhand*
