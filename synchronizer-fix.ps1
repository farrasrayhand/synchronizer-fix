# Script Fix Aplikasi Synchronizer - Final v3
# Usage: powershell -ExecutionPolicy Bypass -Command "irm http://script.minicenter.my.id/synchronizer-fix.ps1 | iex"

$ErrorActionPreference = "Stop"

# --- Admin Check ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Harap jalankan PowerShell sebagai Administrator!" -ForegroundColor Red
    exit
}

# --- Fungsi Refresh Path ---
function Refresh-Env {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "--- Memulai Proses Perbaikan Aplikasi ---" -ForegroundColor Cyan

# --- Langkah 1: Persiapan Package Manager (Chocolatey & Git) ---
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\ProgramData\chocolatey\bin\choco.exe") {
        Write-Host "Chocolatey ditemukan di folder sistem, menyambungkan path..." -ForegroundColor Gray
    } else {
        Write-Host "Menginstal Chocolatey..." -ForegroundColor Gray
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}
Refresh-Env

# Cek & Install Git
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Menginstal Git..." -ForegroundColor Gray
    & choco install git -y
    Refresh-Env
}

# --- Langkah 2: Validasi Folder ---
$basePath = "C:\synchronizer"
if (!(Test-Path $basePath)) {
    $basePath = Read-Host "Folder C:\synchronizer tidak ada. Masukkan lokasi manual"
}

# --- Langkah 3: Fix PHP & Composer ---
Write-Host "Memperbaiki PHP & Composer..." -ForegroundColor Cyan
if (Test-Path "$basePath\dataweb\php.exe") { Remove-Item "$basePath\dataweb\php.exe" -Force }
Copy-Item "$basePath\php\php.exe" -Destination "$basePath\dataweb\php.exe" -Force

if (Test-Path "$basePath\dataweb\vendor") { Remove-Item "$basePath\dataweb\vendor" -Recurse -Force -ErrorAction SilentlyContinue }

Set-Location "$basePath\updater"
# Jalankan git config agar aman
& git config --global --add safe.directory "$basePath/dataweb"
cmd.exe /c "composer.bat"
cmd.exe /c "updater.bat"

# --- Langkah 4: Node.js & NPM ---
Write-Host "Memeriksa Node.js..." -ForegroundColor Cyan
& choco install nodejs --version="24.15.0" -y --forcex86 --force-dependencies # force x86 jika perlu atau hapus flag ini
Refresh-Env

# Jalankan NPM Build
$npmScriptPath = "$basePath\run_npm.bat"
$npmContent = @"
@echo off
set "PATH=%PATH%;C:\ProgramData\chocolatey\bin;%ProgramFiles%\nodejs;%ProgramFiles%\Git\cmd"
cd /d "$basePath\dataweb"
echo Re-checking tools...
node -v
npm -v
echo Memulai install dan build...
call npm install
call npm run build
pause
"@
$npmContent | Out-File $npmScriptPath -Encoding ASCII
Start-Process "cmd.exe" "/c $npmScriptPath" -Wait

Write-Host "--- Semua perbaikan selesai ---" -ForegroundColor Green
Start-Process "http://localhost:7008"
