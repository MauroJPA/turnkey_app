# Arranca o PocketBase local do turnkey_app.
#   cd pb ; .\serve.ps1
# Admin UI: http://127.0.0.1:8090/_/   (superuser dev@turnkey.local / devdevdev12345)
#
# Chaves/segredos: cria um ficheiro pb\.env (fora do git) com linhas KEY=VALUE,
# por exemplo:
#   TURNKEY_AI_PROVIDER=gemini
#   GEMINI_API_KEY=AIza...
# Este script carrega-as para o ambiente antes de arrancar o PocketBase.
# Ver pb\.env.example.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# --- carregar pb\.env (KEY=VALUE por linha; # = comentario) -----------
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

# Conveniencia de dev: contas novas ficam logo verificadas
# (ver hooks\dev_autoverify.pb.js). Nunca usar em producao.
if (-not $env:TURNKEY_DEV) { $env:TURNKEY_DEV = "1" }

$aiProvider = $env:TURNKEY_AI_PROVIDER
if (-not $aiProvider) { $aiProvider = "gemini" }
if ($aiProvider -match "anthropic|claude") {
  $aiKey = $env:ANTHROPIC_API_KEY
} else {
  $aiKey = $env:GEMINI_API_KEY
  if (-not $aiKey) { $aiKey = $env:GOOGLE_API_KEY }
}
if ($aiKey) {
  Write-Host "IA de faturas: provider=$aiProvider, chave definida." -ForegroundColor Green
} else {
  Write-Host "IA de faturas: provider=$aiProvider, sem chave. /faturas/{id}/analisar devolve 503." -ForegroundColor Yellow
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
