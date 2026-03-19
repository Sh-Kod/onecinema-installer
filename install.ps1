# OneCinema Trailer-Automation - Installer
# Aufruf: irm https://raw.githubusercontent.com/Sh-Kod/onecinema-installer/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function OK   { param($t) Write-Host "  OK  $t" -ForegroundColor Green }
function INFO { param($t) Write-Host "  ... $t" -ForegroundColor Cyan }
function WARN { param($t) Write-Host " WARN $t" -ForegroundColor Yellow }
function ERR  { param($t) Write-Host "  ERR $t" -ForegroundColor Red }

Write-Host ""
Write-Host "  ================================================" -ForegroundColor White
Write-Host "   OneCinema Trailer-Automation" -ForegroundColor Yellow
Write-Host "   Installer v3.0" -ForegroundColor Yellow
Write-Host "  ================================================" -ForegroundColor White
Write-Host ""

# --- TLS aktivieren ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls

# --- Internetverbindung prüfen ---
INFO "Prüfe Internetverbindung..."
try {
    $null = Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 10
    OK "Internetverbindung vorhanden"
} catch {
    ERR "Keine Internetverbindung. Bitte Verbindung prüfen und erneut versuchen."
    Read-Host "Enter zum Beenden"
    exit 1
}

# --- Neueste Version ermitteln ---
INFO "Suche neueste Version..."
$downloadUrl = $null
$version = "unbekannt"

try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/Sh-Kod/onecinema-installer/releases/latest" -TimeoutSec 15
    $version = $release.tag_name
    $asset = $release.assets | Where-Object { $_.name -eq "OneCinema.exe" } | Select-Object -First 1
    if ($asset) {
        $downloadUrl = $asset.browser_download_url
        OK "Version gefunden: $version"
    } else {
        WARN "Asset nicht in Release gefunden, verwende direkten Link"
        $downloadUrl = "https://github.com/Sh-Kod/onecinema-installer/releases/latest/download/OneCinema.exe"
    }
} catch {
    WARN "GitHub API nicht erreichbar, verwende direkten Download-Link"
    $downloadUrl = "https://github.com/Sh-Kod/onecinema-installer/releases/latest/download/OneCinema.exe"
}

# --- Zielverzeichnis ---
$installDir = "$env:LOCALAPPDATA\OneCinema"
INFO "Installationsverzeichnis: $installDir"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}
$zielPfad = Join-Path $installDir "OneCinema.exe"

# --- Download ---
INFO "Lade OneCinema.exe herunter... (bitte warten, ca. 20-60 Sek.)"

function Download-Datei {
    param($url, $ziel)

    # Methode 1: curl.exe
    try {
        $curlCmd = Get-Command curl.exe -ErrorAction SilentlyContinue
        if ($curlCmd) {
            & curl.exe -L -o $ziel $url --silent --show-error --max-time 120
            if ((Test-Path $ziel) -and (Get-Item $ziel).Length -gt 100KB) { return $true }
        }
    } catch {}

    # Methode 2: WebClient
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($url, $ziel)
        if ((Test-Path $ziel) -and (Get-Item $ziel).Length -gt 100KB) { return $true }
    } catch {}

    # Methode 3: Invoke-WebRequest
    try {
        Invoke-WebRequest -Uri $url -OutFile $ziel -UseBasicParsing -TimeoutSec 120
        if ((Test-Path $ziel) -and (Get-Item $ziel).Length -gt 100KB) { return $true }
    } catch {}

    # Methode 4: BitsTransfer
    try {
        Import-Module BitsTransfer -ErrorAction Stop
        Start-BitsTransfer -Source $url -Destination $ziel
        if ((Test-Path $ziel) -and (Get-Item $ziel).Length -gt 100KB) { return $true }
    } catch {}

    return $false
}

$erfolg = Download-Datei -url $downloadUrl -ziel $zielPfad

if (-not $erfolg) {
    ERR "Download fehlgeschlagen."
    ERR "Bitte manuell herunterladen:"
    Write-Host "  https://github.com/Sh-Kod/onecinema-installer/releases/latest" -ForegroundColor White
    Read-Host "Enter zum Beenden"
    exit 1
}

$groesse = [math]::Round((Get-Item $zielPfad).Length / 1MB, 1)
OK "OneCinema.exe heruntergeladen ($groesse MB)"

# --- Desktop-Verknüpfung ---
INFO "Erstelle Desktop-Verknüpfung..."
try {
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut("$env:USERPROFILE\Desktop\OneCinema.lnk")
    $lnk.TargetPath = $zielPfad
    $lnk.WorkingDirectory = $installDir
    $lnk.Description = "OneCinema Trailer-Automation"
    $lnk.Save()
    OK "Desktop-Verknüpfung erstellt"
} catch {
    WARN "Verknüpfung konnte nicht erstellt werden (nicht kritisch)"
}

# --- Startmenü-Verknüpfung ---
try {
    $startMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\OneCinema.lnk"
    $wsh2 = New-Object -ComObject WScript.Shell
    $lnk2 = $wsh2.CreateShortcut($startMenu)
    $lnk2.TargetPath = $zielPfad
    $lnk2.WorkingDirectory = $installDir
    $lnk2.Description = "OneCinema Trailer-Automation"
    $lnk2.Save()
    OK "Startmenü-Verknüpfung erstellt"
} catch {}

# --- Fertig ---
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Green
Write-Host "   Installation abgeschlossen!" -ForegroundColor Green
Write-Host "   Version: $version" -ForegroundColor Green
Write-Host "  ================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  OneCinema wurde installiert unter:" -ForegroundColor White
Write-Host "  $zielPfad" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Starten: Desktop-Verknüpfung 'OneCinema' doppelklicken" -ForegroundColor White
Write-Host "  Oder direkt: $zielPfad" -ForegroundColor Cyan
Write-Host ""

# --- Programm starten ---
$antwort = Read-Host "  Jetzt starten? (J/N)"
if ($antwort -match '^[JjYy]') {
    INFO "Starte OneCinema..."
    Start-Process -FilePath $zielPfad -WorkingDirectory $installDir
}

Write-Host ""
