# eRapor SMK Synchronizer

Skrip untuk fix error saat instalasi eRapor SMK Synchronizer.

## Deskripsi

Proyek ini bertujuan untuk mempermudah pengguna dalam memperbaiki masalah sinkronisasi pada sistem Windows melalui skrip PowerShell yang dijalankan secara remote. Khusus untuk menangani error pada eRapor SMK Synchronizer.

## Isi Proyek

- `scripts/synchronizer-fix.ps1`: Skrip PowerShell utama yang berisi logika perbaikan.
- `index.html`: Tutorial interaktif langkah-demi-langkah untuk menjalankan skrip.

## Cara Penggunaan

### Metode Cepat (PowerShell)

Buka PowerShell sebagai Administrator dan jalankan perintah berikut:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm http://script.minicenter.my.id/synchronizer-fix.ps1 | iex"
```

### Metode Tutorial (HTML)

1. Buka file `index.html` di browser pilihan Anda (Chrome, Edge, Firefox, dll).
2. Ikuti panduan visual yang disediakan di halaman tersebut.
3. Gunakan tombol **Salin** untuk mengambil perintah dan tempelkan ke PowerShell.

## Prasyarat

- Windows 10 atau 11.
- Hak akses Administrator.
- Koneksi internet aktif (untuk mengunduh skrip dari remote source).

---
*Bagian dari koleksi skrip farrasrayhand.*
