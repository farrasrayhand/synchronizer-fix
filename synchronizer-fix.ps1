# Script Fix Aplikasi Synchronizer
# Usage: powershell -ExecutionPolicy Bypass -Command "irm http://script.minicenter.my.id/synchronizer-fix.ps1 | iex"

$ErrorActionPreference = "Stop"

# --- Pastikan Berjalan Sebagai Administrator ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Harap jalankan PowerShell sebagai Administrator!" -ForegroundColor Red
    exit
}

# 1. Bypass Execution Policy untuk session ini
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

Write-Host "--- Memulai Proses Perbaikan Aplikasi ---" -ForegroundColor Cyan

# --- Langkah 1: Validasi Folder & File ---
$basePath = "C:\synchronizer"

if (!(Test-Path $basePath)) {
    $pilihan = Read-Host "Folder $basePath tidak ditemukan. Apakah aplikasi sudah terinstal? (Y/N)"
    if ($pilihan -eq "Y" -or $pilihan -eq "y") {
        $basePath = Read-Host "Masukkan path lokasi folder instalasi aplikasi (Contoh: D:\Aplikasi)"
    } else {
        Write-Host "Membuka browser untuk download..." -ForegroundColor Yellow
        Start-Process "https://drive.google.com/file/d/1jeMvOjcylFcYJBHux57Fz8S4lhZf849Y/view"
        exit
    }
}

# Validasi isi folder dan file wajib
$requiredFolders = @("dataweb", "php", "updater", "webserver")
$requiredFiles = @("Readme.txt", "Uninstall.txt")

foreach ($f in $requiredFolders) {
    if (!(Test-Path "$basePath\$f")) { 
        Write-Host "Folder $f tidak ditemukan! Komponen tidak lengkap." -ForegroundColor Red
        Start-Process "https://drive.google.com/file/d/1jeMvOjcylFcYJBHux57Fz8S4lhZf849Y/view"
        exit
    }
}

foreach ($file in $requiredFiles) {
    if (!(Test-Path "$basePath\$file")) {
        Write-Host "File $file tidak ditemukan! Komponen tidak lengkap." -ForegroundColor Red
        Start-Process "https://drive.google.com/file/d/1jeMvOjcylFcYJBHux57Fz8S4lhZf849Y/view"
        exit
    }
}

Write-Host "[OK] Folder dan file tervalidasi." -ForegroundColor Green

# --- Langkah 2: Fix PHP Corrupt ---
Write-Host "Memperbaiki PHP Corrupt..." -ForegroundColor Cyan
if (Test-Path "$basePath\dataweb\php.exe") {
    Remove-Item "$basePath\dataweb\php.exe" -Force
}
if (Test-Path "$basePath\php\php.exe") {
    Copy-Item "$basePath\php\php.exe" -Destination "$basePath\dataweb\php.exe" -Force
    Write-Host "[OK] PHP file berhasil diganti." -ForegroundColor Green
} else {
    Write-Host "[Error] Sumber php.exe di folder php tidak ditemukan!" -ForegroundColor Red
}

# --- Langkah 3: Fix Composer Error ---
Write-Host "Memperbaiki Composer dan menjalankan Updater..." -ForegroundColor Cyan
if (Test-Path "$basePath\dataweb\vendor") {
    Write-Host "Menghapus folder vendor lama..." -ForegroundColor Gray
    Remove-Item "$basePath\dataweb\vendor" -Recurse -Force -ErrorAction SilentlyContinue
}

# Menjalankan bat files
if (Test-Path "$basePath\updater") {
    Set-Location "$basePath\updater"
    Write-Host "Menjalankan composer.bat..."
    Start-Process "cmd.exe" "/c composer.bat" -Wait
    Write-Host "Menjalankan updater.bat..."
    Start-Process "cmd.exe" "/c updater.bat" -Wait
    Write-Host "[OK] Composer & Updater selesai." -ForegroundColor Green
}

# --- Langkah 4: Fix Web Blank (Node.js & NPM) ---
Write-Host "Memeriksa Chocolatey dan Node.js..." -ForegroundColor Cyan

# Install Chocolatey jika belum ada
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Menginstal Chocolatey..." -ForegroundColor Gray
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Install Node.js versi spesifik
Write-Host "Menginstal Node.js v24.15.0..." -ForegroundColor Gray
choco install nodejs --version="24.15.0" -y --force-dependencies

# Refresh Environment Path agar Node & NPM terbaca di session ini
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Jalankan NPM install dan build di jendela baru (Command Prompt)
Write-Host "Menjalankan NPM Install & Build di jendela baru..." -ForegroundColor Cyan
$npmScriptPath = "$basePath\run_npm.bat"
$npmContent = @"
@echo off
cd /d "$basePath\dataweb"
echo Memulai npm install...
call npm install
echo Memulai npm run build...
call npm run build
echo Proses selesai!
pause
"@
$npmContent | Out-File $npmScriptPath -Encoding ASCII
Start-Process "cmd.exe" "/c $npmScriptPath"

Write-Host "--- Semua proses perbaikan selesai dikerjakan ---" -ForegroundColor Green
