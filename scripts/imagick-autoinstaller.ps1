# =============================================================================
# Auto Installer: PHP Imagick Extension
# Install ke SEMUA versi PHP di Laragon & Laravel Herd (Windows)
# =============================================================================

param(
    [switch]$Force  # Pakai -Force untuk reinstall meski sudah ada
)

$ErrorActionPreference = "Stop"

# --- Fungsi Helper ---
function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "   [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "   [!]  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "   [X]  $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "   ... $msg" -ForegroundColor Gray }

function Pause-Exit($code = 1) {
    Write-Host "`nTekan Enter untuk keluar..." -ForegroundColor Gray
    Read-Host | Out-Null
    exit $code
}

# =============================================================================
# FUNGSI: Deteksi konfigurasi dari binary php.exe
# =============================================================================
function Get-PhpInfo($phpExe) {
    try {
        # Jalankan tanpa mendamper error agar kita tahu jika ada crash
        $ver = & $phpExe -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>&1
        if ($LASTEXITCODE -ne 0 -or $ver -match "Error" -or $ver -match "Unable to load") {
            return @{ Error = ($ver | Out-String).Trim(); Exe = $phpExe }
        }
        $ts   = & $phpExe -r "echo PHP_ZTS ? 'ts' : 'nts';" 2>$null
        $arch = & $phpExe -r "echo PHP_INT_SIZE === 8 ? 'x64' : 'x86';" 2>$null
        return @{ Version = $ver; TS = $ts; Arch = $arch; Exe = $phpExe; Dir = Split-Path $phpExe -Parent }
    } catch {
        return @{ Error = $_.Exception.Message; Exe = $phpExe }
    }
}

# =============================================================================
# FUNGSI: Cari URL download DLL dari PECL
# =============================================================================
$peclCache = @{}  # Cache agar tidak fetch PECL berulang kali

function Get-ImagickDllUrl($version, $ts, $arch) {
    $cacheKey = "$version-$ts-$arch"
    if ($peclCache.ContainsKey($cacheKey)) { return $peclCache[$cacheKey] }

    $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    try {
        # 1. Dapatkan halaman utama PECL
        Write-Info "Menghubungi pecl.php.net..."
        $peclPage = Invoke-WebRequest -Uri "https://pecl.php.net/package/imagick" -UseBasicParsing -UserAgent $userAgent
        
        # 2. Cari link "DLL" untuk versi stable terbaru. 
        # Kita cari 'stable' lalu ambil link DLL pertama yang muncul setelahnya.
        $regexStable = 'stable.*?href="(/package/imagick/[\d\.]+/windows)"'
        $matchStable = [regex]::Match($peclPage.Content, $regexStable, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        if (-not $matchStable.Success) {
            # Fallback: ambil link DLL apa saja jika tidak ketemu kata 'stable'
            Write-Warn "Versi 'stable' tidak terdeteksi eksplisit, mencoba link DLL pertama..."
            $matchStable = [regex]::Match($peclPage.Content, 'href="(/package/imagick/[\d\.]+/windows)"')
        }

        if (-not $matchStable.Success) { 
            Write-Fail "Gagal menemukan link halaman DLL di PECL."
            return $null 
        }
        
        $dllPagePath = $matchStable.Groups[1].Value
        $dllPageUrl = "https://pecl.php.net" + $dllPagePath
        Write-Info "Ditemukan halaman DLL: $dllPageUrl"
        
        # 3. Dapatkan halaman subpage DLL
        $dllPage = Invoke-WebRequest -Uri $dllPageUrl -UseBasicParsing -UserAgent $userAgent
        $content = $dllPage.Content
        
        # 4. Cari link zip di halaman tersebut
        # Kita cari pola yang mengandung php_imagick dan .zip dalam atribut href
        $regexZip = 'href="?([^">]+?php_imagick[^">]+?\.zip)"?'
        $matchesZip = [regex]::Matches($content, $regexZip, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        Write-Info "Ditemukan $($matchesZip.Count) link zip di halaman DLL."
        
        $foundUrl = $null
        foreach ($m in $matchesZip) {
            $link = $m.Groups[1].Value
            # Jika link relatif, tambahkan prefix (tapi biasanya di PECL ini link absolut ke windows.php.net)
            if ($link -like "/*") { $link = "https://pecl.php.net" + $link }
            elseif ($link -notlike "http*") { $link = "https://windows.php.net/downloads/pecl/releases/imagick/" + $link }

            if ($link -match "-$version-" -and $link -match "-$ts-" -and $link -match "-$arch\.zip") {
                $foundUrl = $link
                break
            }
        }

        if (-not $foundUrl -and $matchesZip.Count -eq 0) {
            # Debug: cetak sedikit isi konten jika tidak ketemu apa-apa
            $sample = if ($content.Length -gt 200) { $content.Substring(0, 200) } else { $content }
            Write-Warn "Konten halaman (awal): $sample"
        }

        $peclCache[$cacheKey] = $foundUrl
        return $foundUrl
    } catch {
        Write-Fail "Error saat mencari DLL: $($_.Exception.Message)"
        return $null
    }
}

# =============================================================================
# FUNGSI: Install imagick ke satu direktori PHP
# =============================================================================
function Install-ImagickTo($phpInfo, $label) {
    $phpDir  = $phpInfo.Dir
    $phpExe  = $phpInfo.Exe
    $version = $phpInfo.Version
    $ts      = $phpInfo.TS
    $arch    = $phpInfo.Arch
    $extDir  = Join-Path $phpDir "ext"
    $phpIni  = Join-Path $phpDir "php.ini"

    Write-Host ""
    Write-Host "  [$label] PHP $version $($ts.ToUpper()) $arch" -ForegroundColor Magenta
    Write-Host "  Direktori: $phpDir" -ForegroundColor Gray

    # Cek apakah sudah aktif
    $loaded = & $phpExe -r "echo extension_loaded('imagick') ? 'yes' : 'no';" 2>$null
    if ($loaded -eq "yes" -and -not $Force) {
        Write-OK "Imagick sudah aktif, dilewati. (Gunakan -Force untuk reinstall)"
        return $true
    }

    # Cari URL
    Write-Info "Mencari DLL untuk PHP $version $($ts.ToUpper()) $arch..."
    $url = Get-ImagickDllUrl $version $ts $arch
    if (-not $url) {
        Write-Fail "DLL tidak ditemukan untuk PHP $version $($ts.ToUpper()) $arch. Dilewati."
        return $false
    }
    Write-Info "URL: $url"

    # Download
    $tempDir    = Join-Path $env:TEMP "imagick_$(Get-Random)"
    $zipPath    = Join-Path $tempDir "imagick.zip"
    $extractDir = Join-Path $tempDir "extracted"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    } catch {
        Write-Fail "Gagal mendownload: $_"
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }

    # Ekstrak
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    # Pastikan folder ext ada
    if (-not (Test-Path $extDir)) { New-Item -ItemType Directory -Path $extDir | Out-Null }

    # Salin php_imagick.dll ke ext/
    $dllFile = Get-ChildItem -Path $extractDir -Filter "php_imagick.dll" -Recurse | Select-Object -First 1
    if (-not $dllFile) {
        Write-Fail "php_imagick.dll tidak ditemukan dalam arsip!"
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
    Copy-Item -Path $dllFile.FullName -Destination (Join-Path $extDir "php_imagick.dll") -Force
    Write-OK "php_imagick.dll -> ext/"

    # Salin file & folder lain ke direktori utama PHP
    $otherFiles = Get-ChildItem -Path $extractDir | Where-Object { -not $_.PSIsContainer -and $_.Name -ne "php_imagick.dll" }
    $otherDirs  = Get-ChildItem -Path $extractDir | Where-Object { $_.PSIsContainer }
    foreach ($f in $otherFiles) {
        Copy-Item -Path $f.FullName -Destination (Join-Path $phpDir $f.Name) -Force
    }
    foreach ($d in $otherDirs) {
        Copy-Item -Path $d.FullName -Destination (Join-Path $phpDir $d.Name) -Recurse -Force
    }
    Write-OK "File ImageMagick lainnya -> $phpDir"

    # Update php.ini
    if (-not (Test-Path $phpIni)) {
        $phpIniDist = Join-Path $phpDir "php.ini-development"
        if (Test-Path $phpIniDist) {
            Copy-Item $phpIniDist $phpIni
            Write-Warn "php.ini dibuat dari php.ini-development"
        } else {
            Write-Fail "php.ini tidak ditemukan, skip aktivasi."
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }
    }

    $iniContent = Get-Content $phpIni -Raw
    if ($iniContent -match "(?m)^;?\s*extension\s*=\s*imagick") {
        $iniContent = $iniContent -replace "(?m)^;\s*(extension\s*=\s*imagick)", '$1'
        Set-Content -Path $phpIni -Value $iniContent -NoNewline
        Write-OK "extension=imagick diaktifkan di php.ini"
    } else {
        Add-Content -Path $phpIni -Value "`nextension=imagick"
        Write-OK "extension=imagick ditambahkan ke php.ini"
    }

    # Bersihkan temp
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    return $true
}

# =============================================================================
# LANGKAH 1: Scan semua versi PHP di Laragon
# =============================================================================
Write-Step "Mencari semua versi PHP di Laragon..."

$laragonPhpList = @()
$laragonBase    = "C:\laragon\bin\php"

if (Test-Path $laragonBase) {
    $phpFolders = Get-ChildItem -Path $laragonBase -Directory | Where-Object { $_.Name -match "^php-" }
    foreach ($folder in $phpFolders) {
        $exe = Join-Path $folder.FullName "php.exe"
        if (Test-Path $exe) {
            $info = Get-PhpInfo $exe
            if ($info.Version) {
                $laragonPhpList += $info
                Write-OK "Ditemukan: $($folder.Name) (PHP $($info.Version) $($info.TS.ToUpper()) $($info.Arch))"
            } elseif ($info.Error) {
                Write-Warn "Folder $($folder.Name) dilewati karena PHP Error: $($info.Error -replace '\r|\n', ' ' | Select-Object -First 1)"
            }
        }
    }
    if ($laragonPhpList.Count -eq 0) { Write-Warn "Tidak ada versi PHP ditemukan di Laragon." }
} else {
    Write-Warn "Laragon tidak ditemukan di C:\laragon"
}

# =============================================================================
# LANGKAH 2: Scan semua versi PHP di Laravel Herd
# =============================================================================
Write-Step "Mencari semua versi PHP di Laravel Herd..."

$herdPhpList = @()
$herdBase    = Join-Path $env:USERPROFILE ".config\herd\bin"

if (Test-Path $herdBase) {
    $phpFolders = Get-ChildItem -Path $herdBase -Directory | Where-Object { $_.Name -match "^php\d" }
    foreach ($folder in $phpFolders) {
        $exe = Join-Path $folder.FullName "php.exe"
        if (Test-Path $exe) {
            $info = Get-PhpInfo $exe
            if ($info.Version) {
                $herdPhpList += $info
                Write-OK "Ditemukan: $($folder.Name) (PHP $($info.Version) $($info.TS.ToUpper()) $($info.Arch))"
            } elseif ($info.Error) {
                Write-Warn "Folder $($folder.Name) dilewati karena PHP Error: $($info.Error -replace '\r|\n', ' ' | Select-Object -First 1)"
            }
        }
    }
    if ($herdPhpList.Count -eq 0) { Write-Warn "Tidak ada versi PHP ditemukan di Herd." }
} else {
    Write-Warn "Laravel Herd tidak ditemukan di $herdBase"
}

# =============================================================================
# LANGKAH 3: Validasi ada yang ditemukan
# =============================================================================
$totalFound = $laragonPhpList.Count + $herdPhpList.Count
if ($totalFound -eq 0) {
    Write-Fail "Tidak ada instalasi PHP yang ditemukan. Pastikan Laragon atau Herd sudah terinstall."
    Pause-Exit
}

Write-Host ""
Write-Host "  Total ditemukan: $totalFound versi PHP" -ForegroundColor White
Write-Host "    - Laragon : $($laragonPhpList.Count) versi" -ForegroundColor Gray
Write-Host "    - Herd    : $($herdPhpList.Count) versi" -ForegroundColor Gray

# =============================================================================
# LANGKAH 4: Install ke semua versi
# =============================================================================
Write-Step "Memulai instalasi imagick ke semua versi PHP..."

$results = @()

foreach ($info in $laragonPhpList) {
    $ok = Install-ImagickTo $info "Laragon"
    $results += @{ Label = "Laragon PHP $($info.Version) $($info.TS.ToUpper()) $($info.Arch)"; OK = $ok }
}

foreach ($info in $herdPhpList) {
    $ok = Install-ImagickTo $info "Herd"
    $results += @{ Label = "Herd    PHP $($info.Version) $($info.TS.ToUpper()) $($info.Arch)"; OK = $ok }
}

# =============================================================================
# LANGKAH 5: Ringkasan hasil
# =============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  RINGKASAN INSTALASI" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

$successCount = 0
foreach ($r in $results) {
    if ($r.OK) {
        Write-Host "  [OK] $($r.Label)" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "  [X]  $($r.Label)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  Berhasil: $successCount / $($results.Count) versi PHP" -ForegroundColor White
Write-Host ""
Write-Host "  PENTING - Lakukan restart:" -ForegroundColor Yellow
if ($laragonPhpList.Count -gt 0) {
    Write-Host "  Laragon : Klik STOP lalu START kembali." -ForegroundColor White
}
if ($herdPhpList.Count -gt 0) {
    Write-Host "  Herd    : Klik kanan ikon di System Tray -> Quit, lalu buka kembali." -ForegroundColor White
}
Write-Host ""
Write-Host "  Verifikasi setelah restart:" -ForegroundColor White
Write-Host "  php -m | findstr imagick" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Magenta

Pause-Exit 0
