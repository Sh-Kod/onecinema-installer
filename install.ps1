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

$GITHUB_USER = "Sh-Kod"
$GITHUB_REPO = "onecinema-automation"
$SETUP_EXE   = "AutomationCinema_Setup.exe"
$MAIN_EXE    = "OneCinema.exe"
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
    $apiUrl  = "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    $tag     = $release.tag_name

    $assetSetup = $release.assets | Where-Object { $_.name -eq $SETUP_EXE } | Select-Object -First 1
    $assetMain  = $release.assets | Where-Object { $_.name -eq $MAIN_EXE  } | Select-Object -First 1

    $setupUrl = if ($assetSetup) { $assetSetup.browser_download_url } else {
        "https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/latest/download/$SETUP_EXE"
    }
    $mainUrl = if ($assetMain) { $assetMain.browser_download_url } else {
        "https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/latest/download/$MAIN_EXE"
    }
    OK "Version gefunden: $tag"
} catch {
    WARN "GitHub API nicht erreichbar - verwende Standard-URLs..."
    $setupUrl = "https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/latest/download/$SETUP_EXE"
    $mainUrl  = "https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/latest/download/$MAIN_EXE"
}

# ── Schritt 3: Temp-Ordner vorbereiten ────────────────────────────────────────
if (Test-Path $TEMP_DIR) { Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $TEMP_DIR | Out-Null

$setupPfad = Join-Path $TEMP_DIR $SETUP_EXE
$mainPfad  = Join-Path $TEMP_DIR $MAIN_EXE

# ── Schritt 4: Setup-EXE herunterladen ───────────────────────────────────────
INFO "Lade Setup-Assistent herunter..."
try {
    Invoke-WebRequest -Uri $setupUrl -OutFile $setupPfad -UseBasicParsing
} catch {
    FEHLER "Download fehlgeschlagen: $($_.Exception.Message)`n`nBitte manuell herunterladen:`nhttps://github.com/$GITHUB_USER/$GITHUB_REPO/releases"
}

if (-not (Test-Path $setupPfad) -or (Get-Item $setupPfad).Length -lt 1MB) {
    FEHLER "Setup-Datei konnte nicht heruntergeladen werden oder ist zu klein."
}
$sz = [math]::Round((Get-Item $setupPfad).Length / 1MB, 1)
OK "Setup-Assistent: $sz MB"

# ── Schritt 5: Hauptprogramm herunterladen ────────────────────────────────────
INFO "Lade Hauptprogramm herunter..."
try {
    Invoke-WebRequest -Uri $mainUrl -OutFile $mainPfad -UseBasicParsing
} catch {
    WARN "Hauptprogramm-Download fehlgeschlagen: $($_.Exception.Message)"
    WARN "Setup wird trotzdem gestartet - Hauptprogramm kann spaeter nachgeladen werden."
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
