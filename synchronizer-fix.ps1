# Script Fix Aplikasi Synchronizer - Final v4.9 (Dual-Config Aggressive Fix)
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

# --- Langkah 1: Persiapan Package Manager ---
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

# --- Langkah 2: Reset & Dual-Fix PHP Config (Aggressive Regex) ---
$basePath = "C:\synchronizer"
$phpDir = "$basePath\php"
$phpIni = "$phpDir\php.ini"
$phpDev = "$phpDir\php.ini-development"
$extPath = "$phpDir\ext"

Write-Host "Me-reset dan Memperbaiki Konfigurasi PHP (Dual-File)..." -ForegroundColor Cyan

# Copy php.exe ke folder dataweb
if (Test-Path "$basePath\dataweb\php.exe") { Remove-Item "$basePath\dataweb\php.exe" -Force }
Copy-Item "$phpDir\php.exe" -Destination "$basePath\dataweb\php.exe" -Force

# Reset php.ini menggunakan template development jika belum ada
if (Test-Path $phpDev) {
    Copy-Item $phpDev -Destination $phpIni -Force
}

# Daftar file yang akan diproses (php.ini dan php.ini-development)
$targetConfigs = @($phpIni, $phpDev)

foreach ($configFile in $targetConfigs) {
    if (Test-Path $configFile) {
        Write-Host "Memproses: $(Split-Path $configFile -Leaf)..." -ForegroundColor Gray
        $content = Get-Content $configFile
        
        # Gunakan REGEX Agresif: Cari baris yang dimulai ';' (opsional), spasi (opsional), lalu 'extension=...'
        $content = $content -replace '^;?\s*extension=pdo_sqlite', 'extension=pdo_sqlite'
        $content = $content -replace '^;?\s*extension=sqlite3', 'extension=sqlite3'
        $content = $content -replace '^;?\s*extension=zip', 'extension=zip'
        $content = $content -replace '^;?\s*extension=curl', 'extension=curl'
        $content = $content -replace '^;?\s*extension=mbstring', 'extension=mbstring'
        $content = $content -replace '^;?\s*extension=openssl', 'extension=openssl'
        $content = $content -replace '^;?\s*extension=fileinfo', 'extension=fileinfo'
        $content = $content -replace '^;?\s*extension=gd', 'extension=gd'
        
        # Paksa extension_dir ke Path Absolut (Menghilangkan error 'driver not found')
        $content = $content -replace '^;?\s*extension_dir\s*=\s*"ext"', "extension_dir = `"$extPath`""
        
        # Naikkan Memory Limit agar tidak crash saat composer/migrate
        $content = $content -replace '^;?\s*memory_limit\s*=\s*.*', 'memory_limit = 512M'

        $content | Set-Content $configFile
    }
}
Write-Host "[OK] Kedua file konfigurasi PHP telah diperkuat." -ForegroundColor Green

# ✅ FIX BARU: Copy php.ini ke dataweb\ agar php.exe di sana bisa membacanya
Write-Host "Menyalin php.ini ke folder dataweb..." -ForegroundColor Cyan
Copy-Item $phpIni -Destination "$basePath\dataweb\php.ini" -Force
Write-Host "[OK] php.ini berhasil disalin ke dataweb\." -ForegroundColor Green

# Verifikasi php.ini terbaca oleh php.exe di dataweb
Write-Host "Verifikasi konfigurasi PHP di dataweb..." -ForegroundColor Cyan
$phpCheck = & "$basePath\dataweb\php.exe" -m 2>&1
if ($phpCheck -match "pdo_sqlite") {
    Write-Host "[OK] Ekstensi pdo_sqlite aktif dan terdeteksi." -ForegroundColor Green
} else {
    Write-Host "[WARN] pdo_sqlite belum terdeteksi, periksa php.ini secara manual." -ForegroundColor Yellow
}

# --- Langkah 3: Composer & Laravel Update ---
if (Test-Path "$basePath\dataweb\vendor") { 
    Write-Host "Membersihkan vendor lama..." -ForegroundColor Gray
    Remove-Item "$basePath\dataweb\vendor" -Recurse -Force -ErrorAction SilentlyContinue 
}

Set-Location "$basePath\updater"
& git config --global --add safe.directory "$basePath/dataweb"

Write-Host "Menjalankan composer install..." -ForegroundColor Gray
cmd.exe /c "composer.bat"

Write-Host "Menjalankan updater (artisan migrate)..." -ForegroundColor Gray
cmd.exe /c "updater.bat"

# --- Langkah 4: Node.js & NPM ---
Write-Host "Memastikan Node.js v24.15.0..." -ForegroundColor Cyan
& choco install nodejs --version="24.15.0" -y --force --force-dependencies
Refresh-Env

$npmScriptPath = "$basePath\run_npm.bat"
$npmContent = @"
@echo off
set "PATH=%PATH%;C:\ProgramData\chocolatey\bin;%ProgramFiles%\nodejs;%ProgramFiles%\Git\cmd"
cd /d "$basePath\dataweb"
echo Membersihkan cache dan install dependensi...
call npm cache clean --force
call npm install --legacy-peer-deps
echo Memulai proses build...
call npm run build
echo Selesai! Menutup jendela...
timeout /t 3
exit
"@
$npmContent | Out-File $npmScriptPath -Encoding ASCII
Start-Process "cmd.exe" "/c $npmScriptPath" -Wait

# --- Finalisasi ---
Write-Host "--- Semua proses perbaikan selesai dikerjakan ---" -ForegroundColor Green
Start-Process "http://localhost:7008"
