<#
Bootstrap for a Windows self-hosted GitHub Actions runner with Visual Studio Build Tools (MSBuild).

Usage examples:
  .\setup.ps1 -Url "https://github.com/bauer-group" -Token "<REG_TOKEN>"
  .\setup.ps1 -Url "https://github.com/bauer-group" -Token "<REG_TOKEN>" -InstallDotNet -DotNetVersions Microsoft.DotNet.SDK.8
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Url,
  [Parameter(Mandatory=$true)][string]$Token,
  [string]$InstallPath = "C:\BuildTools",
  [string]$RunnerRoot  = "C:\Actions-Runner",
  [string]$ServiceName = "Actions.Runner",
  [switch]$InstallDotNet,
  [string[]]$DotNetVersions = @("Microsoft.DotNet.SDK.9"),
  [string[]]$VsComponents = @(
    "Microsoft.VisualStudio.Workload.MSBuildTools",
    "Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools",
    "Microsoft.Net.Component.4.8.TargetingPack"
  )
)

function Assert-Admin {
  $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object System.Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([System.Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw "Please run this script in an elevated PowerShell (Run as Administrator)."
  }
}

function Invoke-Download {
  param([string]$Uri, [string]$OutFile, [int]$Retries=5, [int]$DelaySeconds=5)
  for ($i=1; $i -le $Retries; $i++) {
    try {
      Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec 600
      return
    } catch {
      if ($i -eq $Retries) { throw }
      Start-Sleep -Seconds $DelaySeconds
    }
  }
}

try {
  Assert-Admin
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $ProgressPreference = 'SilentlyContinue'

  Write-Host "==> Installing Visual Studio Build Tools 2022..." -ForegroundColor Cyan
  $VsExe = "$env:TEMP\vs_BuildTools.exe"
  Invoke-Download -Uri "https://aka.ms/vs/17/release/vs_BuildTools.exe" -OutFile $VsExe

  $vsArgs = @("--quiet","--wait","--norestart","--nocache","--installPath",$InstallPath)
  foreach ($c in $VsComponents) { $vsArgs += @("--add",$c) }
  $p = Start-Process -FilePath $VsExe -ArgumentList $vsArgs -PassThru -Wait -NoNewWindow
  if ($p.ExitCode -ne 0) { throw "VS Build Tools installer exit code $($p.ExitCode)" }

  if ($InstallDotNet) {
    Write-Host "==> Installing .NET SDK(s) via winget..." -ForegroundColor Cyan
    foreach ($pkg in $DotNetVersions) {
      Start-Process -FilePath "winget" -ArgumentList @(
        "install","-e","--id",$pkg,"--accept-source-agreements","--accept-package-agreements"
      ) -NoNewWindow -Wait
    }
  }

  New-Item -ItemType Directory -Force -Path $RunnerRoot | Out-Null
  Set-Location $RunnerRoot

  Write-Host "==> Downloading latest GitHub Actions runner (Windows x64)..." -ForegroundColor Cyan
  $runnerZip = Join-Path $RunnerRoot "actions-runner-win-x64.zip"
  Invoke-Download -Uri "https://github.com/actions/runner/releases/latest/download/actions-runner-win-x64.zip" -OutFile $runnerZip
  if (Test-Path "$RunnerRoot\bin") { Remove-Item -Recurse -Force "$RunnerRoot\bin" }
  Expand-Archive -Path $runnerZip -DestinationPath $RunnerRoot -Force

  Write-Host "==> Configuring self-hosted runner (ephemeral)..." -ForegroundColor Cyan
  $proc = Start-Process -FilePath ".\config.cmd" -ArgumentList @("--url",$Url,"--token",$Token,"--ephemeral") -NoNewWindow -PassThru -Wait
  if ($proc.ExitCode -ne 0) { throw "Runner config failed with exit code $($proc.ExitCode)" }

  Write-Host "==> Installing Windows service and starting..." -ForegroundColor Cyan
  .\svc install
  .\svc start

  Write-Host "==> Done. Runner registered as EPHEMERAL service. MSBuild at: $InstallPath\MSBuild\Current\Bin\MSBuild.exe" -ForegroundColor Green
} catch {
  Write-Error $_
  exit 1
}
