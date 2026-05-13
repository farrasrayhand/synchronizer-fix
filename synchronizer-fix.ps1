# Script Fix Aplikasi Synchronizer - Final v5.2 (Merged)
# Usage: powershell -ExecutionPolicy Bypass -Command "irm http://script.minicenter.my.id/synchronizer-fix.ps1 | iex"

$ErrorActionPreference = "Stop"

# --- Pastikan Berjalan Sebagai Administrator ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Harap jalankan PowerShell sebagai Administrator!" -ForegroundColor Red
    exit
}
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

Write-Host "--- Memulai Proses Perbaikan Aplikasi ---" -ForegroundColor Cyan

# --- Langkah Awal: Cek Port 7008 ---
$portActive = Get-NetTCPConnection -LocalPort 7008 -ErrorAction SilentlyContinue
if ($portActive) {
    Write-Host "[OK] Port 7008 (Apache) aktif." -ForegroundColor Green
} else {
    Write-Host "[!] Port 7008 tidak aktif. Pastikan webserver menyala." -ForegroundColor Yellow
}

# --- Langkah 1: Validasi Folder ---
$basePath = "C:\synchronizer"
if (!(Test-Path $basePath)) {
    $pilihan = Read-Host "Folder $basePath tidak ditemukan. Gunakan lokasi manual? (Y/N)"
    if ($pilihan -eq "Y" -or $pilihan -eq "y") {
        $basePath = Read-Host "Masukkan path lokasi folder"
    } else {
        Start-Process "https://drive.google.com/file/d/1jeMvOjcylFcYJBHux57Fz8S4lhZf849Y/view"
        exit
    }
}

$phpDir   = "$basePath\php"
$phpIni   = "$phpDir\php.ini"

# --- Langkah 2: Hentikan Semua Proses yang Mengunci File ---
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

# --- Langkah 3: Konfigurasi Git Global (non-interaktif) ---
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "Mengkonfigurasi Git..." -ForegroundColor Cyan
    & git config --global core.autocrlf false
    & git config --global advice.detachedHead false
    & git config --global core.fileMode false
    & git config --global --add safe.directory "$basePath/dataweb"
}
$env:GIT_TERMINAL_PROMPT = "0"
$env:GIT_ASK_YESNO = "false"

# --- Langkah 4: Fix PHP Corrupt ---
# Copy php.exe & php.ini SEBELUM updater agar Git pull tidak terkunci
Write-Host "Memperbaiki PHP..." -ForegroundColor Cyan
if (Test-Path "$basePath\dataweb\php.exe") {
    Remove-Item "$basePath\dataweb\php.exe" -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$phpDir\php.exe") {
    Copy-Item "$phpDir\php.exe" -Destination "$basePath\dataweb\php.exe" -Force
    Write-Host "[OK] php.exe disalin ke dataweb\." -ForegroundColor Green
} else {
    Write-Host "[WARN] php.exe tidak ditemukan di $phpDir" -ForegroundColor Yellow
}
if (Test-Path $phpIni) {
    Copy-Item $phpIni -Destination "$basePath\dataweb\php.ini" -Force
    Write-Host "[OK] php.ini disalin ke dataweb\." -ForegroundColor Green
} else {
    Write-Host "[WARN] php.ini tidak ditemukan di $phpDir" -ForegroundColor Yellow
}

# Verifikasi ekstensi sqlite aktif
$sqliteCheck = & "$basePath\dataweb\php.exe" -m 2>&1
if ($sqliteCheck -match "pdo_sqlite") {
    Write-Host "[OK] Ekstensi pdo_sqlite aktif dan terdeteksi." -ForegroundColor Green
} else {
    Write-Host "[WARN] pdo_sqlite belum terdeteksi, periksa php.ini secara manual." -ForegroundColor Yellow
}

# --- Langkah 5: Fix Composer Error ---
Write-Host "Memperbaiki Composer & Vendor..." -ForegroundColor Cyan
if (Test-Path "$basePath\dataweb\vendor") {
    Remove-Item "$basePath\dataweb\vendor" -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$basePath\updater") {
    Set-Location "$basePath\updater"
    cmd.exe /c "composer.bat"
    cmd.exe /c "updater.bat"
    Write-Host "[OK] Langkah 5 selesai." -ForegroundColor Green
}

# --- Langkah 6: Re-copy php.ini setelah Git pull ---
# (Jaga-jaga kalau Git pull menimpa php.ini di dataweb\)
if (Test-Path $phpIni) {
    Copy-Item $phpIni -Destination "$basePath\dataweb\php.ini" -Force
    Write-Host "[OK] php.ini di-refresh setelah Git pull." -ForegroundColor Green
}

# --- Langkah 7: Fix Web Blank & NPM Error ---
Write-Host "Memeriksa Node.js & NPM..." -ForegroundColor Cyan
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}
choco install nodejs --version="24.15.0" -y --force-dependencies

# Force refresh PATH agar NPM terbaca langsung
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "Menjalankan NPM Install & Build..." -ForegroundColor Cyan
$npmScriptPath = "$basePath\run_npm.bat"
$npmContent = @"
@echo off
set "PATH=%PATH%;%ProgramFiles%\nodejs;C:\ProgramData\chocolatey\bin;%ProgramFiles%\Git\cmd"
cd /d "$basePath\dataweb"
echo Mengecek versi Node:
node -v
echo Membersihkan cache...
call npm cache clean --force
echo Memulai npm install...
call npm install --legacy-peer-deps
echo Memulai npm run build...
call npm run build
echo.
echo Proses Build Selesai!
timeout /t 3
exit
"@
$npmContent | Out-File $npmScriptPath -Encoding ASCII
Start-Process "cmd.exe" "/c $npmScriptPath" -Wait

# --- Finalisasi ---
Write-Host "--- Semua perbaikan selesai ---" -ForegroundColor Green
Start-Process "http://localhost:7008"
