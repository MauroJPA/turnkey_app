# Arranca o PocketBase local do turnkey_app.
#   cd pb ; .\serve.ps1
# Admin UI: http://127.0.0.1:8090/_/   (superuser dev@turnkey.local / devdevdev12345)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$bin = ".\bin\pocketbase.exe"
if (-not (Test-Path $bin)) {
  Write-Host "PocketBase nao encontrado em pb\bin\pocketbase.exe." -ForegroundColor Yellow
  Write-Host "Descarrega o v0.35.0 de github.com/pocketbase/pocketbase/releases e poe o .exe nessa pasta."
  exit 1
}

& $bin serve `
  --dir .\pb_data `
  --migrationsDir .\migrations `
  --hooksDir .\hooks `
  --http 127.0.0.1:8090
