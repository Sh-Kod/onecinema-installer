# ============================================================
#  OneCinema Trailer-Automation – One-Command Installer v2.2
#  ============================================================
#  Einmalig ausführen mit:
#  irm https://raw.githubusercontent.com/Sh-Kod/onecinema-installer/main/install.ps1 | iex
#
#  Was dieser Installer macht:
#  1. Prüft Internetverbindung
#  2. Lädt AutomationCinema_Setup.exe + OneCinema.exe von GitHub Releases
#  3. Startet den Setup-Assistenten (kein Python nötig!)
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

$GITHUB_USER         = "Sh-Kod"
$GITHUB_REPO         = "onecinema-automation"   # privates Repo (Quellcode)
$GITHUB_RELEASE_REPO = "onecinema-installer"    # oeffentliches Repo (EXE-Downloads)
$SETUP_EXE           = "AutomationCinema_Setup.exe"
$MAIN_EXE            = "OneCinema.exe"
$TEMP_DIR    = Join-Path $env:TEMP "OneCinema_Install"

# ── Ausgabe-Hilfsfunktionen ───────────────────────────────────────────────────
function OK($t)     { Write-Host "  OK  $t" -ForegroundColor Green }
function INFO($t)   { Write-Host "  ... $t" -ForegroundColor Cyan }
function WARN($t)   { Write-Host "  !   $t" -ForegroundColor Yellow }
function FEHLER($t) { Write-Host "  ERR $t" -ForegroundColor Red; Read-Host "Druecken Sie Enter zum Beenden"; exit 1 }

# ── Banner ────────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "   OneCinema Trailer-Automation" -ForegroundColor Yellow
Write-Host "   Installer v2.2" -ForegroundColor Gray
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Kein Python benoetigt - alles wird automatisch eingerichtet." -ForegroundColor Gray
Write-Host ""

# ── Schritt 1: Internet prüfen ────────────────────────────────────────────────
INFO "Pruefe Internetverbindung..."
try {
    $null = Invoke-WebRequest "https://github.com" -UseBasicParsing -TimeoutSec 8
    OK "Internetverbindung vorhanden"
} catch {
    FEHLER "Keine Internetverbindung! Bitte Internet pruefen und nochmal starten."
}

# ── Schritt 2: Neueste Release-Version + Download-URLs ermitteln ──────────────
INFO "Suche neueste Version..."
$setupUrl = ""
$mainUrl  = ""
$tag      = "unbekannt"

try {
    $apiUrl  = "https://api.github.com/repos/$GITHUB_USER/$GITHUB_RELEASE_REPO/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    $tag     = $release.tag_name

    $assetSetup = $release.assets | Where-Object { $_.name -eq $SETUP_EXE } | Select-Object -First 1
    $assetMain  = $release.assets | Where-Object { $_.name -eq $MAIN_EXE  } | Select-Object -First 1

    $setupUrl = if ($assetSetup) { $assetSetup.browser_download_url } else {
        "https://github.com/$GITHUB_USER/$GITHUB_RELEASE_REPO/releases/latest/download/$SETUP_EXE"
    }
    $mainUrl = if ($assetMain) { $assetMain.browser_download_url } else {
        "https://github.com/$GITHUB_USER/$GITHUB_RELEASE_REPO/releases/latest/download/$MAIN_EXE"
    }
    OK "Version gefunden: $tag"
} catch {
    WARN "GitHub API nicht erreichbar - verwende Standard-URLs..."
    $setupUrl = "https://github.com/$GITHUB_USER/$GITHUB_RELEASE_REPO/releases/latest/download/$SETUP_EXE"
    $mainUrl  = "https://github.com/$GITHUB_USER/$GITHUB_RELEASE_REPO/releases/latest/download/$MAIN_EXE"
}

# ── Schritt 3: Temp-Ordner vorbereiten ────────────────────────────────────────
if (Test-Path $TEMP_DIR) { Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $TEMP_DIR | Out-Null

$setupPfad = Join-Path $TEMP_DIR $SETUP_EXE
$mainPfad  = Join-Path $TEMP_DIR $MAIN_EXE

# ── TLS alle Versionen aktivieren (behebt Verbindungsfehler auf aelteren Windows) ─
[Net.ServicePointManager]::SecurityProtocol = `
    [Net.SecurityProtocolType]::Tls12 -bor `
    [Net.SecurityProtocolType]::Tls11 -bor `
    [Net.SecurityProtocolType]::Tls

# ── Download-Hilfsfunktion (folgt Redirects, funktioniert mit GitHub CDN) ────
function Download-Datei($url, $ziel, $bezeichnung) {
    # Methode 1: curl.exe (in Windows 10/11 eingebaut, sehr zuverlaessig)
    $curlExe = "$env:SystemRoot\System32\curl.exe"
    if (Test-Path $curlExe) {
        try {
            & $curlExe -L --silent --show-error -o $ziel $url 2>&1 | Out-Null
            if ((Test-Path $ziel) -and (Get-Item $ziel).Length -gt 100KB) { return $true }
        } catch { }
    }

    # Methode 2: WebClient
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $wc.DownloadFile($url, $ziel)
        if ((Test-Path $ziel) -and (Get-Item $ziel).Length -gt 100KB) { return $true }
    } catch { }

    # Methode 3: Invoke-WebRequest
    try {
        Invoke-WebRequest -Uri $url -OutFile $ziel -UseBasicParsing -MaximumRedirection 10
        if ((Test-Path $ziel) -and (Get-Item $ziel).Length -gt 100KB) { return $true }
    } catch { }

    # Methode 4: certutil (auf allen Windows-Versionen verfuegbar)
    try {
        $null = & certutil.exe -urlcache -split -f $url $ziel 2>&1
        if ((Test-Path $ziel) -and (Get-Item $ziel).Length -gt 100KB) { return $true }
    } catch { }

    # Methode 5: BitsTransfer
    try {
        Import-Module BitsTransfer -ErrorAction SilentlyContinue
        Start-BitsTransfer -Source $url -Destination $ziel -ErrorAction Stop
        if ((Test-Path $ziel) -and (Get-Item $ziel).Length -gt 100KB) { return $true }
    } catch { }

    return $false
}

# ── Schritt 4: Setup-EXE herunterladen ───────────────────────────────────────
INFO "Lade Setup-Assistent herunter... (bitte warten, ca. 20-60 Sek.)"
$ok = Download-Datei $setupUrl $setupPfad "Setup-Assistent"
if (-not $ok) {
    FEHLER "Download fehlgeschlagen.`n`nBitte manuell herunterladen:`nhttps://github.com/$GITHUB_USER/$GITHUB_REPO/releases"
}
$sz = [math]::Round((Get-Item $setupPfad).Length / 1MB, 1)
OK "Setup-Assistent: $sz MB"

# ── Schritt 5: Hauptprogramm herunterladen ────────────────────────────────────
INFO "Lade Hauptprogramm herunter... (bitte warten, ca. 20-60 Sek.)"
$ok = Download-Datei $mainUrl $mainPfad "Hauptprogramm"
if (-not $ok) {
    WARN "Hauptprogramm-Download fehlgeschlagen - Setup wird trotzdem gestartet."
}

if (Test-Path $mainPfad) {
    $sz = [math]::Round((Get-Item $mainPfad).Length / 1MB, 1)
    OK "Hauptprogramm: $sz MB"
}

# ── Schritt 6: Setup starten ──────────────────────────────────────────────────
Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "   Setup-Assistent wird gestartet!" -ForegroundColor Yellow
Write-Host "   Bitte im Setup-Fenster weiter einrichten." -ForegroundColor Gray
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ""
Start-Sleep -Seconds 1

try {
    # Setup-Assistent mit Temp-Dir als Arbeitsverzeichnis starten
    # So findet er OneCinema.exe neben sich (im selben Temp-Ordner)
    $proc = Start-Process -FilePath $setupPfad -WorkingDirectory $TEMP_DIR -PassThru
    $proc.WaitForExit()
} catch {
    FEHLER "Setup konnte nicht gestartet werden: $($_.Exception.Message)"
}

# ── Aufräumen ─────────────────────────────────────────────────────────────────
try { Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue } catch {}

Write-Host ""
OK "Installation abgeschlossen!"
Write-Host ""
