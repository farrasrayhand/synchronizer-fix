# Script Fix Aplikasi Synchronizer - Final v4.7
# Usage: powershell -ExecutionPolicy Bypass -Command "irm http://script.minicenter.my.id/synchronizer-fix.ps1 | iex"

$ErrorActionPreference = "Stop"

# --- Pastikan Berjalan Sebagai Administrator ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Harap jalankan PowerShell sebagai Administrator!" -ForegroundColor Red
    exit
}

# Fungsi untuk memperbarui Environment Path secara instan
function Refresh-Env {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "--- Memulai Proses Perbaikan Aplikasi ---" -ForegroundColor Cyan

# --- Langkah 1: Persiapan Package Manager (Chocolatey & Git) ---
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    if (!(Test-Path "C:\ProgramData\chocolatey\bin\choco.exe")) {
        Write-Host "Menginstal Chocolatey..." -ForegroundColor Gray
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}
Refresh-Env

if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Menginstal Git..." -ForegroundColor Gray
    & choco install git -y
    Refresh-Env
}

# --- Langkah 2: Reset & Fix PHP (Deep Reset dari Template) ---
$basePath = "C:\synchronizer"
Write-Host "Me-reset Konfigurasi PHP..." -ForegroundColor Cyan

# Copy php.exe ke folder dataweb
if (Test-Path "$basePath\dataweb\php.exe") { Remove-Item "$basePath\dataweb\php.exe" -Force }
Copy-Item "$basePath\php\php.exe" -Destination "$basePath\dataweb\php.exe" -Force

$phpDir = "$basePath\php"
$phpIni = "$phpDir\php.ini"
$phpDev = "$phpDir\php.ini-development"

# Gunakan template development (74KB) untuk menggantikan php.ini yang rusak (5KB)
if (Test-Path $phpDev) {
    Write-Host "Mengkloning php.ini-development menjadi php.ini..." -ForegroundColor Gray
    Copy-Item $phpDev -Destination $phpIni -Force
}

if (Test-Path $phpIni) {
    Write-Host "Mengonfigurasi ulang php.ini..." -ForegroundColor Gray
    $content = Get-Content $phpIni
    
    # 1. Aktifkan ekstensi yang diperlukan
    $extensions = @("pdo_sqlite", "sqlite3", "curl", "mbstring", "openssl", "fileinfo", "gd", "zip")
    foreach ($ext in $extensions) {
        $content = $content -replace ";extension=$ext", "extension=$ext"
    }
    
    # 2. Perbaikan Jalur Ekstensi (PENTING)
    # Kita hapus semua baris extension_dir yang aktif/non-aktif dan ganti dengan jalur absolut yang baru
    $extPath = "$phpDir\ext"
    # Cari bagian [On windows:] dan paksa extension_dir mengarah ke path absolut
    $content = $content -replace ';extension_dir = "ext"', "extension_dir = `"$extPath`""
    $content = $content -replace 'extension_dir = "ext"', "extension_dir = `"$extPath`""
    
    # 3. Pastikan memory_limit cukup untuk composer
    $content = $content -replace 'memory_limit = 128M', 'memory_limit = 512M'

    $content | Set-Content $phpIni
    Write-Host "[OK] php.ini berhasil diperbarui (Zip & Absolute Path enabled)." -ForegroundColor Green
}

# --- Langkah 3: Composer & Laravel Update ---
if (Test-Path "$basePath\dataweb\vendor") { 
    Write-Host "Membersihkan vendor..." -ForegroundColor Gray
    Remove-Item "$basePath\dataweb\vendor" -Recurse -Force -ErrorAction SilentlyContinue 
}

Set-Location "$basePath\updater"
& git config --global --add safe.directory "$basePath/dataweb"
Write-Host "Menjalankan composer install..." -ForegroundColor Gray
cmd.exe /c "composer.bat"
Write-Host "Menjalankan updater (artisan migrate)..." -ForegroundColor Gray
cmd.exe /c "updater.bat"

# --- Langkah 4: Node.js & NPM (Legacy Peer Deps Fix) ---
Write-Host "Memeriksa Node.js v24.15.0..." -ForegroundColor Cyan
& choco install nodejs --version="24.15.0" -y --force --force-dependencies
Refresh-Env

# Buat script batch untuk NPM dengan auto-close
$npmScriptPath = "$basePath\run_npm.bat"
$npmContent = @"
@echo off
set "PATH=%PATH%;C:\ProgramData\chocolatey\bin;%ProgramFiles%\nodejs;%ProgramFiles%\Git\cmd"
cd /d "$basePath\dataweb"
echo Membersihkan cache dan install dependensi...
call npm cache clean --force
:: Menggunakan legacy-peer-deps untuk mengatasi error ERESOLVE
call npm install --legacy-peer-deps
echo Memulai proses build...
call npm run build
echo.
echo Selesai! Menutup jendela dalam 3 detik...
timeout /t 3
exit
"@
$npmContent | Out-File $npmScriptPath -Encoding ASCII
Start-Process "cmd.exe" "/c $npmScriptPath" -Wait

# --- Finalisasi ---
Write-Host "--- Semua proses perbaikan selesai dikerjakan ---" -ForegroundColor Green
Start-Process "http://localhost:7008"
