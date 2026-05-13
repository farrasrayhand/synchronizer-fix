# Script Fix Aplikasi Synchronizer - Final v4.1 (Auto Fix php.ini)
# Usage: powershell -ExecutionPolicy Bypass -Command "irm http://script.minicenter.my.id/synchronizer-fix.ps1 | iex"

$ErrorActionPreference = "Stop"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Harap jalankan PowerShell sebagai Administrator!" -ForegroundColor Red
    exit
}

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

# --- Langkah 2: Fix PHP & SQLite Driver ---
$basePath = "C:\synchronizer"
Write-Host "Memperbaiki PHP & Konfigurasi php.ini..." -ForegroundColor Cyan

# Pastikan php.exe terbaru sudah di copy
if (Test-Path "$basePath\dataweb\php.exe") { Remove-Item "$basePath\dataweb\php.exe" -Force }
Copy-Item "$basePath\php\php.exe" -Destination "$basePath\dataweb\php.exe" -Force

# Edit php.ini untuk mengaktifkan SQLite dan ekstensi penting lainnya
$phpIni = "$basePath\php\php.ini"
if (Test-Path $phpIni) {
    Write-Host "Mengaktifkan ekstensi di php.ini..." -ForegroundColor Gray
    $content = Get-Content $phpIni
    
    # Menghapus ';' untuk mengaktifkan extension
    $content = $content -replace ';extension=pdo_sqlite', 'extension=pdo_sqlite'
    $content = $content -replace ';extension=sqlite3', 'extension=sqlite3'
    $content = $content -replace ';extension=curl', 'extension=curl'
    $content = $content -replace ';extension=mbstring', 'extension=mbstring'
    $content = $content -replace ';extension=openssl', 'extension=openssl'
    
    $content | Set-Content $phpIni
    Write-Host "[OK] php.ini berhasil diperbarui." -ForegroundColor Green
} else {
    Write-Host "[!] File php.ini tidak ditemukan di $basePath\php\" -ForegroundColor Yellow
}

# --- Langkah 3: Composer & Update ---
if (Test-Path "$basePath\dataweb\vendor") { 
    Write-Host "Membersihkan folder vendor..." -ForegroundColor Gray
    Remove-Item "$basePath\dataweb\vendor" -Recurse -Force -ErrorAction SilentlyContinue 
}

Set-Location "$basePath\updater"
& git config --global --add safe.directory "$basePath/dataweb"
Write-Host "Menjalankan composer install..." -ForegroundColor Gray
cmd.exe /c "composer.bat"
Write-Host "Menjalankan updater/migration..." -ForegroundColor Gray
cmd.exe /c "updater.bat"

# --- Langkah 4: Fix Node.js (Correct Flags) ---
Write-Host "Memeriksa Node.js..." -ForegroundColor Cyan
# Menggunakan --force untuk mengatasi error pada log sebelumnya
& choco install nodejs --version="24.15.0" -y --force --force-dependencies
Refresh-Env

# Jalankan NPM Build
$npmScriptPath = "$basePath\run_npm.bat"
$npmContent = @"
@echo off
set "PATH=%PATH%;C:\ProgramData\chocolatey\bin;%ProgramFiles%\nodejs;%ProgramFiles%\Git\cmd"
cd /d "$basePath\dataweb"
echo Memulai npm install dan build...
call npm install
call npm run build
pause
"@
$npmContent | Out-File $npmScriptPath -Encoding ASCII
Start-Process "cmd.exe" "/c $npmScriptPath" -Wait

Write-Host "--- Semua perbaikan selesai ---" -ForegroundColor Green
Start-Process "http://localhost:7008"
