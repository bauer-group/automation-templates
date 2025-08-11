# GitHub Actions Runner Stack (Org: **bauer-group**)

Produktionsreifes Setup für **ephemere** Self‑Hosted Runner auf Ubuntu 24.04 (ESXi‑VM) und optional Windows‑Runner. Standard‑Skalierung: **8 Runner** pro Host mit **2 vCPU & 8 GB RAM** pro Runner.

## Features
- **Ephemeral Runner** (`EPHEMERAL=1`): 1 Job pro Runner, danach automatische Deregistrierung → saubere Isolation.
- **Kein Workdir‑Bindmount**: Verhindert Kollisionen zwischen parallelen Jobs.
- **Docker‑outside‑of‑Docker**: `/var/run/docker.sock` gemountet (für Build/Compose‑Jobs).
- **Auto‑Updates**:
  - Runner‑Binaries aktualisieren sich **standardmäßig selbst** (kein Flag nötig). 
  - **Watchtower** aktualisiert das **Container‑Image** wöchentlich **samstags 03:30** (Cron mit Sekunden, `TZ` unterstützt) und führt Rolling‑Restarts aus.
- **Skalierung**: Standard **8 Runner**, anpassbar über `.env`.
- **Scope & Auth**: Org/Repo/Enterprise und PAT oder GitHub App (Least Privilege).

## Ordnerstruktur
```
github/runner/
├─ README.md
├─ docker-compose.yml
├─ .env.example
├─ scripts/
│  ├─ install.sh
│  ├─ manage.sh
│  └─ uninstall.sh
├─ systemd/
│  └─ gha-runners.service
└─ cloud-init/
   └─ user-data.yaml
```

## Schnellstart (Linux, Ubuntu 24.04)
```bash
sudo apt-get update && sudo apt-get install -y git
sudo mkdir -p /opt/gha && cd /opt/gha
git clone https://github.com/bauer-group/automation-templates.git
cd automation-templates/github/runner
sudo cp .env.example .env
# .env (RUNNER_SCOPE/ORG_NAME/Auth/RUNNER_COUNT) ausfüllen
sudo bash scripts/install.sh
```

## Cloud‑Init (für ESXi‑Templates empfohlen)
Nutze `cloud-init/user-data.yaml`. Beim ersten Boot werden Repo‑Inhalte nach `/opt/gha/runner` kopiert, `.env` befüllt und der Stack gestartet.

## Skalierung / Betrieb
- **Runner‑Anzahl**: In `.env` `RUNNER_COUNT` ändern → `sudo ./scripts/manage.sh` ausführen.
- **Status/Logs**:
  - `docker ps --filter name=runner`
  - GitHub → *Settings → Actions → Runners* (Org/Repo).
- **Updates**: Runner‑Binary auto; Basis‑Image wöchentlich durch Watchtower (Sa 03:30, lokale TZ).
  
---

## Windows‑Build‑Runner: VS Build Tools & MSBuild

### Warum Vorinstallation notwendig ist
Die Action `microsoft/setup-msbuild` **installiert MSBuild nicht**, sondern fügt lediglich eine vorhandene MSBuild‑Installation dem `PATH` hinzu. Für klassische Windows‑Builds (.NET Framework, WinForms, WPF) müssen die **Visual Studio Build Tools** (inkl. MSBuild) **vorab** installiert sein. Für moderne .NET‑SDK‑Builds auf Linux/Windows empfiehlt sich zur Laufzeit `actions/setup-dotnet`.

### Beispiel‑Bootstrap (PowerShell, Admin)
```powershell
# 1) Visual Studio Build Tools 2022 (silent)
Invoke-WebRequest "https://aka.ms/vs/17/release/vs_BuildTools.exe" -OutFile "C:\Temp\vs_buildtools.exe"
Start-Process "C:\Temp\vs_buildtools.exe" -ArgumentList @(
  "--quiet","--wait","--norestart","--nocache",
  "--installPath","C:\BuildTools",
  "--add","Microsoft.VisualStudio.Workload.MSBuildTools",
  "--add","Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools",
  "--add","Microsoft.Net.Component.4.8.TargetingPack"
) -NoNewWindow -Wait

# 2) Optional: .NET SDK 8 via winget
winget install --id Microsoft.DotNet.SDK.8 --accept-source-agreements --accept-package-agreements

# 3) Self‑Hosted Runner installieren (ephemeral) & Dienst starten
$RunnerRoot="C:\actions-runner"
New-Item -ItemType Directory -Force -Path $RunnerRoot | Out-Null
Invoke-WebRequest "https://github.com/actions/runner/releases/latest/download/actions-runner-win-x64.zip" -OutFile "$RunnerRoot\runner.zip"
Expand-Archive "$RunnerRoot\runner.zip" -DestinationPath $RunnerRoot -Force
cd $RunnerRoot
.\config.cmd --url https://github.com/bauer-group --token <REGISTRATION_TOKEN> --ephemeral
.\svc install
.\svc start
```

### Beispiel‑Workflow (.NET Framework Builds, Windows)
```yaml
jobs:
  build-windows:
    runs-on: [self-hosted, windows, x64]
    steps:
      - uses: actions/checkout@v4
      - name: Add MSBuild to PATH
        uses: microsoft/setup-msbuild@v1
      - name: Build Solution
        run: |
          "C:\BuildTools\MSBuild\Current\Bin\MSBuild.exe" MySolution.sln /p:Configuration=Release /m
```

---

## Runtime‑Tooling (Linux & Windows)
Für .NET‑SDK‑Builds ist **`actions/setup-dotnet`** die empfohlene Methode, um SDK‑Versionen **zur Laufzeit** zu laden/cachen. Beispiel:
```yaml
- uses: actions/setup-dotnet@v4
  with:
    dotnet-version: |
      8.0.x
      6.0.x
```

## Default‑Labels (automatisch vorhanden)
Self‑Hosted Runner erhalten automatisch die Labels `self-hosted`, OS (`linux`/`windows`) und Architektur (`x64`/etc.). Du musst sie nicht setzen; nutze sie direkt in `runs-on`. Bei Bedarf kannst du die Vergabe mit `--no-default-labels` verhindern und eigene Labels verwenden.

## Referenzen
- Runner‑Image & Variablen (EPHEMERAL, ACCESS_TOKEN, APP_ID/APP_PRIVATE_KEY, …): https://github.com/myoung34/docker-github-actions-runner/wiki/Usage  
- Image‑Args (Env‑Variablen): https://github.com/myoung34/docker-github-actions-runner  
- Watchtower (TZ, Cron mit Sekunden, Rolling Restart): https://containrrr.dev/watchtower/arguments/  
- setup‑dotnet (Runtime‑Install der .NET SDKs): https://github.com/actions/setup-dotnet  
- setup‑msbuild (fügt MSBuild zum PATH hinzu): https://github.com/microsoft/setup-msbuild  
- Default‑Labels & Runner‑Zuweisung: https://docs.github.com/actions/hosting-your-own-runners/using-labels-with-self-hosted-runners und https://docs.github.com/actions/using-jobs/choosing-the-runner-for-a-job
