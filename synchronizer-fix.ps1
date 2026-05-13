# Script Fix Aplikasi Synchronizer - Final v5.6
# Usage: powershell -ExecutionPolicy Bypass -Command "irm http://script.minicenter.my.id/synchronizer-fix.ps1 | iex"

$ErrorActionPreference = "Stop"

# --- Pastikan Berjalan Sebagai Administrator ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Harap jalankan PowerShell sebagai Administrator!" -ForegroundColor Red
    exit
}
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Fungsi untuk memperbarui Environment Path secara instan
function Refresh-Env {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "--- Memulai Proses Perbaikan Aplikasi ---" -ForegroundColor Cyan

# --- Langkah Awal: Cek Port 7008 ---
$portActive = Get-NetTCPConnection -LocalPort 7008 -ErrorAction SilentlyContinue
$basePath = "C:\synchronizer"
$folderAda = Test-Path $basePath

if ($portActive) {
    Write-Host "[OK] Port 7008 (Apache) aktif." -ForegroundColor Green
} else {
    Write-Host "[!] Port 7008 tidak aktif." -ForegroundColor Yellow
}

# --- Langkah 1: Validasi Folder ---
if (!$folderAda) {
    Write-Host ""
    Write-Host "[!] Folder $basePath tidak ditemukan." -ForegroundColor Yellow
    Write-Host ""
    $sudahInstall = Read-Host "Apakah aplikasi Synchronizer sudah terinstall di komputer ini? (Y/N)"

    if ($sudahInstall -eq "Y" -or $sudahInstall -eq "y") {
        $basePath = Read-Host "Masukkan path lokasi folder instalasi Synchronizer"
        if (!(Test-Path $basePath)) {
            Write-Host "ERROR: Folder '$basePath' tidak ditemukan. Script dihentikan." -ForegroundColor Red
            exit
        }
        Write-Host "[OK] Menggunakan folder: $basePath" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  Silakan install Synchronizer terlebih dahulu." -ForegroundColor White
        Write-Host "  Download installer di link berikut:" -ForegroundColor White
        Write-Host "  https://drive.google.com/file/d/1jeMvOjcylFcYJBHux57Fz8S4lhZf849Y/view" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Setelah instalasi selesai, jalankan kembali script ini untuk melakukan perbaikan." -ForegroundColor Yellow
        Write-Host ""
        Start-Process "https://drive.google.com/file/d/1jeMvOjcylFcYJBHux57Fz8S4lhZf849Y/view"
        exit
    }
}

$phpDir = "$basePath\php"
$phpIni = "$phpDir\php.ini"
$phpExeDest = "$basePath\dataweb\php.exe"
$phpIniDest = "$basePath\dataweb\php.ini"

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

# --- Langkah 3: Persiapan Package Manager ---
Write-Host "Memeriksa Chocolatey..." -ForegroundColor Cyan
if (!(Test-Path "C:\ProgramData\chocolatey\bin\choco.exe")) {
    Write-Host "Menginstal Chocolatey..." -ForegroundColor Gray
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}
$env:Path = "C:\ProgramData\chocolatey\bin;" + $env:Path
Refresh-Env
Write-Host "[OK] Chocolatey siap." -ForegroundColor Green

# Install Git jika belum ada
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Menginstal Git..." -ForegroundColor Gray
    & "C:\ProgramData\chocolatey\bin\choco.exe" install git -y
    Refresh-Env
}

# --- Langkah 4: Konfigurasi Git Global (non-interaktif) ---
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "Mengkonfigurasi Git..." -ForegroundColor Cyan
    & git config --global core.autocrlf false
    & git config --global advice.detachedHead false
    & git config --global core.fileMode false
    & git config --global --add safe.directory "$basePath/dataweb"
}
$env:GIT_TERMINAL_PROMPT = "0"
$env:GIT_ASK_YESNO = "false"

# --- Langkah 5: Fix PHP Corrupt ---
# Hapus php.exe di dataweb SEBELUM Git pull agar tidak terkunci
Write-Host "Memperbaiki PHP..." -ForegroundColor Cyan
if (Test-Path $phpExeDest) {
    Remove-Item $phpExeDest -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] php.exe lama dihapus dari dataweb\." -ForegroundColor Green
}
if (Test-Path "$phpDir\php.exe") {
    Copy-Item "$phpDir\php.exe" -Destination $phpExeDest -Force
    Write-Host "[OK] php.exe disalin ke dataweb\." -ForegroundColor Green
} else {
    Write-Host "[WARN] php.exe tidak ditemukan di $phpDir" -ForegroundColor Yellow
}
if (Test-Path $phpIni) {
    Copy-Item $phpIni -Destination $phpIniDest -Force
    Write-Host "[OK] php.ini disalin ke dataweb\." -ForegroundColor Green
} else {
    Write-Host "[WARN] php.ini tidak ditemukan di $phpDir" -ForegroundColor Yellow
}

# Verifikasi ekstensi sqlite & openssl aktif
$phpModules = & $phpExeDest -m 2>&1
if ($phpModules -match "pdo_sqlite") {
    Write-Host "[OK] Ekstensi pdo_sqlite aktif." -ForegroundColor Green
} else {
    Write-Host "[WARN] pdo_sqlite belum terdeteksi." -ForegroundColor Yellow
}
if ($phpModules -match "openssl") {
    Write-Host "[OK] Ekstensi openssl aktif." -ForegroundColor Green
} else {
    Write-Host "[WARN] openssl belum terdeteksi." -ForegroundColor Yellow
}

# --- Langkah 6: Fix Composer & Laravel Update ---
Write-Host "Memperbaiki Composer & Vendor..." -ForegroundColor Cyan
if (Test-Path "$basePath\dataweb\vendor") {
    Remove-Item "$basePath\dataweb\vendor" -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$basePath\updater") {
    Set-Location "$basePath\updater"
    cmd.exe /c "composer.bat"
    cmd.exe /c "updater.bat"
    Write-Host "[OK] Langkah 6 selesai." -ForegroundColor Green
}

# --- Langkah 7: Re-copy php.exe & php.ini setelah Git pull ---
# (Git pull di dalam updater.bat bisa menghapus php.exe, copy ulang setelah selesai)
Write-Host "Re-sinkronisasi PHP setelah Git pull..." -ForegroundColor Cyan
if (Test-Path "$phpDir\php.exe") {
    Copy-Item "$phpDir\php.exe" -Destination $phpExeDest -Force
    Write-Host "[OK] php.exe di-refresh setelah Git pull." -ForegroundColor Green
}
if (Test-Path $phpIni) {
    Copy-Item $phpIni -Destination $phpIniDest -Force
    Write-Host "[OK] php.ini di-refresh setelah Git pull." -ForegroundColor Green
}

# --- Langkah 8: Fix Web Blank & NPM Error ---
Write-Host "Memeriksa Node.js & NPM..." -ForegroundColor Cyan
# Fix: --force-dependencies harus disertai --force
& "C:\ProgramData\chocolatey\bin\choco.exe" install nodejs --version="24.15.0" -y --force --force-dependencies

# Paksa path nodejs aktif di sesi ini tanpa harus jalankan ulang
$env:Path = "$env:ProgramFiles\nodejs;" + [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "Menjalankan NPM Install & Build..." -ForegroundColor Cyan
$npmScriptPath = "$basePath\run_npm.bat"
$npmContent = @"
@echo off
set "PATH=%PATH%;%ProgramFiles%\nodejs;C:\ProgramData\chocolatey\bin;%ProgramFiles%\Git\cmd"
cd /d "$basePath\dataweb"
echo Mengecek versi Node:
node -v
if errorlevel 1 (
    echo ERROR: Node.js tidak terdeteksi! Pastikan Node.js sudah terinstall.
    pause
    exit /b 1
)
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
