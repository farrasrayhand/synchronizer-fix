# Script Fix Aplikasi Synchronizer - Final Version
# Usage: powershell -ExecutionPolicy Bypass -Command "irm http://script.minicenter.my.id/synchronizer-fix.ps1 | iex"

$ErrorActionPreference = "Stop"

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

# --- Langkah 2: Fix PHP Corrupt ---
Write-Host "Memperbaiki PHP..." -ForegroundColor Cyan
if (Test-Path "$basePath\dataweb\php.exe") { Remove-Item "$basePath\dataweb\php.exe" -Force }
if (Test-Path "$basePath\php\php.exe") {
    Copy-Item "$basePath\php\php.exe" -Destination "$basePath\dataweb\php.exe" -Force
}

# --- Langkah 3: Fix Composer Error ---
Write-Host "Memperbaiki Composer & Vendor..." -ForegroundColor Cyan
if (Test-Path "$basePath\dataweb\vendor") {
    Remove-Item "$basePath\dataweb\vendor" -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path "$basePath\updater") {
    Set-Location "$basePath\updater"
    # Menggunakan cmd /c agar jika satu gagal tidak menghentikan seluruh script PowerShell
    cmd.exe /c "composer.bat"
    cmd.exe /c "updater.bat"
    Write-Host "[OK] Langkah 3 selesai." -ForegroundColor Green
}

# --- Langkah 4: Fix Web Blank & NPM Error ---
Write-Host "Memeriksa Node.js & NPM..." -ForegroundColor Cyan

if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

choco install nodejs --version="24.15.0" -y --force-dependencies

# FORCE REFRESH PATH agar NPM terbaca langsung
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Jalankan NPM dengan script yang memuat ulang path
Write-Host "Menjalankan NPM Install & Build..." -ForegroundColor Cyan
$npmScriptPath = "$basePath\run_npm.bat"
$npmContent = @"
@echo off
:: Memuat ulang path di dalam CMD agar node/npm terdeteksi
set "PATH=%PATH%;%ProgramFiles%\nodejs"
cd /d "$basePath\dataweb"
echo Mengecek versi Node:
node -v
echo Memulai npm install...
call npm install
echo Memulai npm run build...
call npm run build
echo.
echo Proses Build Selesai!
pause
"@
$npmContent | Out-File $npmScriptPath -Encoding ASCII
Start-Process "cmd.exe" "/c $npmScriptPath" -Wait

# --- Finalisasi ---
Write-Host "--- Semua perbaikan selesai ---" -ForegroundColor Green
Start-Process "http://localhost:7008"
