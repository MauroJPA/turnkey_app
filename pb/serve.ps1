# Arranca o PocketBase local do turnkey_app.
#   cd pb ; .\serve.ps1
# Admin UI: http://127.0.0.1:8090/_/   (superuser dev@turnkey.local / devdevdev12345)
#
# Chaves/segredos: cria um ficheiro pb\.env (fora do git) com linhas KEY=VALUE,
# por exemplo:
#   ANTHROPIC_API_KEY=sk-ant-...
#   TURNKEY_AI_MODEL=claude-sonnet-5
# Este script carrega-as para o ambiente antes de arrancar o PocketBase.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# --- carregar pb\.env (KEY=VALUE por linha; # = comentário) -----------
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
  foreach ($line in Get-Content $envFile) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    $i = $t.IndexOf("=")
    if ($i -lt 1) { continue }
    $k = $t.Substring(0, $i).Trim()
    $v = $t.Substring($i + 1).Trim().Trim('"')
    Set-Item -Path "Env:$k" -Value $v
  }
}
if ($env:ANTHROPIC_API_KEY) {
  Write-Host "ANTHROPIC_API_KEY: definida (analise de faturas por IA ativa)." -ForegroundColor Green
} else {
  Write-Host "ANTHROPIC_API_KEY: nao definida — /faturas/{id}/analisar devolve 503." -ForegroundColor Yellow
}

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
