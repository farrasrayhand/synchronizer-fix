# Script Fix Aplikasi Synchronizer - Final v4.4 (Deep Reset PHP & NPM Fix)
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

# --- Langkah 2: Reset & Fix PHP (Menggunakan Template Development) ---
$basePath = "C:\synchronizer"
Write-Host "Me-reset Konfigurasi PHP agar tidak rusak..." -ForegroundColor Cyan

if (Test-Path "$basePath\dataweb\php.exe") { Remove-Item "$basePath\dataweb\php.exe" -Force }
Copy-Item "$basePath\php\php.exe" -Destination "$basePath\dataweb\php.exe" -Force

$phpDir = "$basePath\php"
$phpIni = "$phpDir\php.ini"
$phpDev = "$phpDir\php.ini-development"

# Gunakan template development karena isinya jauh lebih lengkap (74KB vs 5KB)
if (Test-Path $phpDev) {
    Write-Host "Mengkloning php.ini-development menjadi php.ini..." -ForegroundColor Gray
    Copy-Item $phpDev -Destination $phpIni -Force
}

if (Test-Path $phpIni) {
    $content = Get-Content $phpIni
    
    # Aktifkan ekstensi wajib
    $content = $content -replace ';extension=pdo_sqlite', 'extension=pdo_sqlite'
    $content = $content -replace ';extension=sqlite3', 'extension=sqlite3'
    $content = $content -replace ';extension=curl', 'extension=curl'
    $content = $content -replace ';extension=mbstring', 'extension=mbstring'
    $content = $content -replace ';extension=openssl', 'extension=openssl'
    $content = $content -replace ';extension=fileinfo', 'extension=fileinfo'
    $content = $content -replace ';extension=gd', 'extension=gd'
    
    # Set extension_dir secara absolut agar driver .dll terbaca dengan pasti
    $extPath = "$phpDir\ext"
    $content = $content -replace ';extension_dir = "ext"', "extension_dir = `"$extPath`""
    $content = $content -replace 'extension_dir = "ext"', "extension_dir = `"$extPath`""

    $content | Set-Content $phpIni
    Write-Host "[OK] php.ini berhasil diperbarui dari template." -ForegroundColor Green
}

# --- Langkah 3: Composer & Laravel Update ---
if (Test-Path "$basePath\dataweb\vendor") { 
    Remove-Item "$basePath\dataweb\vendor" -Recurse -Force -ErrorAction SilentlyContinue 
}

Set-Location "$basePath\updater"
& git config --global --add safe.directory "$basePath/dataweb"
Write-Host "Menjalankan composer install..." -ForegroundColor Gray
cmd.exe /c "composer.bat"
Write-Host "Menjalankan updater (artisan migrate)..." -ForegroundColor Gray
cmd.exe /c "updater.bat"

# --- Langkah 4: Fix Node.js & NPM (Legacy Peer Deps) ---
Write-Host "Memastikan Node.js terinstal..." -ForegroundColor Cyan
& choco install nodejs --version="24.15.0" -y --force --force-dependencies
Refresh-Env

$npmScriptPath = "$basePath\run_npm.bat"
$npmContent = @"
@echo off
set "PATH=%PATH%;C:\ProgramData\chocolatey\bin;%ProgramFiles%\nodejs;%ProgramFiles%\Git\cmd"
cd /d "$basePath\dataweb"
echo Membersihkan cache dan install dependensi...
call npm cache clean --force
:: Menggunakan legacy-peer-deps untuk mengatasi ERESOLVE
call npm install --legacy-peer-deps
echo Memulai proses build...
call npm run build
pause
"@
$npmContent | Out-File $npmScriptPath -Encoding ASCII
Start-Process "cmd.exe" "/c $npmScriptPath" -Wait

Write-Host "--- Perbaikan Selesai ---" -ForegroundColor Green
Start-Process "http://localhost:7008"
