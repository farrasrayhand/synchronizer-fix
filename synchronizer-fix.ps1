# Script Fix Aplikasi Synchronizer - Final v5.1
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

# --- Langkah 1: Hentikan Semua Proses yang Mengunci File ---
Write-Host "Menghentikan proses yang sedang berjalan..." -ForegroundColor Cyan
$processesToKill = @("php", "synchronizer", "node")
foreach ($proc in $processesToKill) {
    $running = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($running) {
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Proses $proc dihentikan." -ForegroundColor Green
    }
}
Start-Sleep -Seconds 3

# --- Langkah 2: Persiapan Package Manager ---
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

# --- Langkah 3: Konfigurasi Git Global (non-interaktif) ---
Write-Host "Mengkonfigurasi Git..." -ForegroundColor Cyan
& git config --global core.autocrlf false
& git config --global advice.detachedHead false
& git config --global core.fileMode false
$env:GIT_TERMINAL_PROMPT = "0"
$env:GIT_ASK_YESNO = "false"

# --- Langkah 4: Hapus php.exe di dataweb SEBELUM Git pull ---
# (Agar Git tidak gagal unlink saat update)
$basePath = "C:\synchronizer"
$phpDir = "$basePath\php"
$phpIni = "$phpDir\php.ini"

Write-Host "Menghapus php.exe lama di dataweb agar Git tidak terkunci..." -ForegroundColor Cyan
if (Test-Path "$basePath\dataweb\php.exe") {
    Remove-Item "$basePath\dataweb\php.exe" -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] php.exe lama dihapus." -ForegroundColor Green
}

# --- Langkah 5: Composer & Laravel Update (Git pull di dalam updater.bat) ---
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

# --- Langkah 6: Copy php.exe & php.ini SETELAH Git pull selesai ---
Write-Host "Menyinkronisasi php.exe dan php.ini ke folder dataweb..." -ForegroundColor Cyan
Copy-Item "$phpDir\php.exe" -Destination "$basePath\dataweb\php.exe" -Force
Copy-Item "$phpIni" -Destination "$basePath\dataweb\php.ini" -Force
Write-Host "[OK] php.exe dan php.ini berhasil disinkronisasi ke dataweb\." -ForegroundColor Green

# Verifikasi ekstensi sqlite aktif
$sqliteCheck = & "$basePath\dataweb\php.exe" -m 2>&1
if ($sqliteCheck -match "pdo_sqlite") {
    Write-Host "[OK] Ekstensi pdo_sqlite aktif dan terdeteksi." -ForegroundColor Green
} else {
    Write-Host "[WARN] pdo_sqlite belum terdeteksi, periksa php.ini secara manual." -ForegroundColor Yellow
}

# --- Langkah 7: Node.js & NPM ---
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
