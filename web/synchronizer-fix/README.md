# eRapor SMK Synchronizer Fix Install

Skrip untuk fix error saat instalasi eRapor SMK Synchronizer.

## Deskripsi

Proyek ini bertujuan untuk mempermudah pengguna dalam memperbaiki masalah sinkronisasi (Fix Install) pada eRapor SMK Synchronizer melalui skrip PowerShell.

## Isi Proyek

- `scripts/synchronizer-fix.ps1`: Skrip PowerShell utama.
- `index.html`: Tutorial interaktif langkah-demi-langkah.

## Cara Penggunaan

### Metode Cepat (PowerShell)

**Standard Fix**
Gunakan ini untuk menjalankan perbaikan standar:
```powershell
powershell -ExecutionPolicy Bypass -Command "irm http://script.minicenter.my.id/scripts/synchronizer-fix.ps1 | iex"
```

### Metode Tutorial (Web)

1. Akses [script.minicenter.my.id/web/synchronizer-fix/](http://script.minicenter.my.id/web/synchronizer-fix/)
2. Ikuti panduan visual yang disediakan di halaman tersebut.
3. Gunakan tombol **Salin** untuk mengambil perintah dan tempelkan ke PowerShell.

## Prasyarat

- Hak akses Administrator.
- Koneksi internet aktif.

---
*Developed by farrasrayhand*
