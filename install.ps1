# ============================================================
#  OneCinema Automation - One-Command Installer
#  ============================================================
#  Ausführen mit:
#  irm https://raw.githubusercontent.com/Sh-Kod/onecinema-installer/main/install.ps1 | iex
# ============================================================

$ErrorActionPreference = "Stop"

# ── Design-Funktionen ────────────────────────────────────────
function Titel {
    Clear-Host
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor DarkGray
    Write-Host "   🎬  OneCinema Automation - Installer" -ForegroundColor Yellow
    Write-Host "   Automatische Einrichtung - Bitte warten..." -ForegroundColor Gray
    Write-Host "  ================================================" -ForegroundColor DarkGray
    Write-Host ""
}
function OK($t)     { Write-Host "  ✅ $t" -ForegroundColor Green }
function INFO($t)   { Write-Host "  ⏳ $t" -ForegroundColor Cyan }
function WARN($t)   { Write-Host "  ⚠️  $t" -ForegroundColor Yellow }
function FEHLER($t) { Write-Host "  ❌ $t" -ForegroundColor Red }
function SCHRITT($n, $t) {
    Write-Host ""
    Write-Host "  ── Schritt $n`: $t " -ForegroundColor Cyan
}

# ── Server-Konfiguration ─────────────────────────────────────
$SUPABASE_URL = "https://ouqbuxjhriuccxpkfnng.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im91cWJ1eGpocml1Y2N4cGtmbm5nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzMjcyMzIsImV4cCI6MjA4ODkwMzIzMn0.HJlStPaF6S760teOezpS_aG9bEQUM6gmDWxtFXwFmHs"
$GITHUB_USER  = "Sh-Kod"
$GITHUB_REPO  = "onecinema-automation"

# ════════════════════════════════════════════════════════════
Titel

Write-Host "  Dieser Installer richtet alles vollautomatisch ein." -ForegroundColor Gray
Write-Host "  Dauer: ca. 5-10 Minuten (je nach Internet)." -ForegroundColor Gray
Write-Host ""

# ── Schritt 1: Internet prüfen ───────────────────────────────
SCHRITT 1 "Internetverbindung prüfen"
try {
    $null = Invoke-WebRequest "https://www.google.com" -UseBasicParsing -TimeoutSec 5
    OK "Internetverbindung vorhanden"
} catch {
    FEHLER "Keine Internetverbindung! Bitte prüfen und nochmal starten."
    Read-Host "`n  Enter drücken zum Beenden"
    exit 1
}

# ── Schritt 2: Python prüfen / installieren ──────────────────
SCHRITT 2 "Python prüfen"

function Finde-Python {
    foreach ($cmd in @("python", "python3", "py")) {
        try {
            $v = & $cmd --version 2>&1
            if ($v -match "Python 3\.") { return $cmd }
        } catch {}
    }
    foreach ($p in @(
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
        "C:\Python312\python.exe", "C:\Python311\python.exe"
    )) { if (Test-Path $p) { return $p } }
    return ""
}

$python = Finde-Python

if ($python -eq "") {
    WARN "Python nicht gefunden - wird jetzt installiert (ca. 2 Min)..."
    $pyUrl  = "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe"
    $pyInst = "$env:TEMP\python-installer.exe"
    INFO "Lade Python 3.12 herunter..."
    Invoke-WebRequest $pyUrl -OutFile $pyInst -UseBasicParsing
    INFO "Installiere Python (bitte warten)..."
    $proc = Start-Process $pyInst `
        -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_pip=1 Include_tcltk=1" `
        -Wait -PassThru
    Remove-Item $pyInst -ErrorAction SilentlyContinue
    if ($proc.ExitCode -ne 0) {
        FEHLER "Python-Installation fehlgeschlagen."
        FEHLER "Bitte manuell installieren: https://python.org"
        Read-Host "`n  Enter drücken zum Beenden"
        exit 1
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                $env:Path
    Start-Sleep -Seconds 2
    $python = Finde-Python
    if ($python -eq "") {
        FEHLER "Python nicht gefunden nach Installation. Bitte PC neu starten und nochmal ausführen."
        Read-Host "`n  Enter drücken zum Beenden"
        exit 1
    }
    OK "Python 3.12 erfolgreich installiert!"
} else {
    $ver = & $python --version 2>&1
    OK "Python bereits vorhanden: $ver"
}

# ── Schritt 3: Deploy-Token aus Supabase ─────────────────────
SCHRITT 3 "Verbindung zum OneCinema Server"
INFO "Authentifizierung läuft..."

$deployToken = ""
try {
    $sbHeaders = @{
        "apikey"        = $SUPABASE_KEY
        "Authorization" = "Bearer $SUPABASE_KEY"
    }
    $result = Invoke-RestMethod `
        -Uri "$SUPABASE_URL/rest/v1/app_config?key=eq.github_deploy_token&select=value" `
        -Headers $sbHeaders -TimeoutSec 10
    if ($result -and $result[0].value) {
        $deployToken = $result[0].value.Trim()
    }
} catch {
    FEHLER "Verbindung zum OneCinema Server fehlgeschlagen: $_"
    Read-Host "`n  Enter drücken zum Beenden"
    exit 1
}

if ($deployToken -eq "") {
    FEHLER "Kein Installations-Token erhalten. Bitte Administrator kontaktieren."
    Read-Host "`n  Enter drücken zum Beenden"
    exit 1
}
OK "Server-Verbindung erfolgreich!"

# ── Schritt 4: Programm herunterladen ────────────────────────
SCHRITT 4 "Programm herunterladen"
INFO "Lade OneCinema Automation herunter..."

$apiUrl  = "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/zipball/main"
$zipPfad = "$env:TEMP\onecinema-automation.zip"
$extPfad = "$env:TEMP\onecinema-extract"

try {
    # Schritt A: GitHub API ohne Weiterleitung aufrufen → CDN-URL erhalten
    $req = [System.Net.HttpWebRequest]::Create($apiUrl)
    $req.Method = "GET"
    $req.Headers.Add("Authorization", "token $deployToken")
    $req.UserAgent = "OneCinemaInstaller/2.0"
    $req.Accept = "application/vnd.github+json"
    $req.AllowAutoRedirect = $false

    $cdnUrl = ""
    try {
        $resp = $req.GetResponse()
        $cdnUrl = $resp.Headers["Location"]
        $resp.Close()
    } catch [System.Net.WebException] {
        $cdnUrl = $_.Exception.Response.Headers["Location"]
        $_.Exception.Response.Close()
    }

    if (-not $cdnUrl) { throw "Keine CDN-URL von GitHub erhalten." }

    # Schritt B: ZIP direkt von CDN laden (vorübergehende URL, kein Token nötig)
    INFO "Lade Programmdateien..."
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($cdnUrl, $zipPfad)
    OK "Download abgeschlossen!"

} catch {
    FEHLER "Download fehlgeschlagen: $_"
    FEHLER "Bitte Internetverbindung prüfen und nochmal versuchen."
    Read-Host "`n  Enter drücken zum Beenden"
    exit 1
}

# ── Schritt 5: Entpacken ─────────────────────────────────────
SCHRITT 5 "Dateien entpacken"
INFO "Entpacke Programmdateien..."

if (Test-Path $extPfad) { Remove-Item $extPfad -Recurse -Force }
try {
    Expand-Archive -Path $zipPfad -DestinationPath $extPfad -Force
    Remove-Item $zipPfad -ErrorAction SilentlyContinue
    OK "Dateien bereit!"
} catch {
    FEHLER "Entpacken fehlgeschlagen: $_"
    Read-Host "`n  Enter drücken zum Beenden"
    exit 1
}

# ── Schritt 6: Python-Pakete installieren ────────────────────
SCHRITT 6 "Basis-Pakete installieren"
INFO "Installiere benötigte Pakete..."

$pakete = @("requests", "keyring", "openpyxl", "supabase", "python-telegram-bot", "playwright", "tkinterdnd2")
foreach ($paket in $pakete) {
    INFO "Installiere $paket..."
    $ErrorActionPreference = "Continue"
    & $python -m pip install $paket --quiet --upgrade *>&1 | Out-Null
    $ErrorActionPreference = "Stop"
}
OK "Alle Pakete installiert!"

# ── Schritt 6b: Chromium Browser installieren ────────────────
SCHRITT "6b" "Chromium Browser installieren"
INFO "Lade Chromium Browser herunter (ca. 150 MB, bitte warten)..."
$ErrorActionPreference = "Continue"
& $python -m playwright install chromium 2>&1 | ForEach-Object { INFO $_ }
$ErrorActionPreference = "Stop"
OK "Chromium Browser installiert!"

# ── Schritt 7: Setup-Wizard starten ──────────────────────────
SCHRITT 7 "Setup-Assistent starten"

# Ordner-Name dynamisch finden (zipball hat anderen Namen als archive)
$innerOrdner = Get-ChildItem $extPfad -Directory | Select-Object -First 1
if (-not $innerOrdner) {
    FEHLER "Entpackter Ordner nicht gefunden."
    Read-Host "`n  Enter drücken zum Beenden"
    exit 1
}
$wizardPfad = Join-Path $innerOrdner.FullName "src\setup_wizard.py"

if (-not (Test-Path $wizardPfad)) {
    FEHLER "Setup-Datei nicht gefunden: $wizardPfad"
    Read-Host "`n  Enter drücken zum Beenden"
    exit 1
}

Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "   🎬  Setup-Assistent wird gestartet!" -ForegroundColor Yellow
Write-Host "   Bitte im nächsten Fenster weitermachen." -ForegroundColor Gray
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ""

Start-Sleep -Seconds 2
& $python $wizardPfad
