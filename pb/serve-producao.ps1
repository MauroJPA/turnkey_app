# Arranca o PocketBase em PRODUCAO (Mini PC): API + a app web (pasta web).
#   cd pb ; .\serve-producao.ps1
#   cd pb ; .\serve-producao.ps1 -Escuta 0.0.0.0:8090     # acessivel na rede local
#
# Por omissao escuta so em 127.0.0.1:8090 (atras de um tunel/proxy com HTTPS).
# Carrega pb\.env (KEY=VALUE por linha). Nunca liga o modo de desenvolvimento.
# Regista o que o servidor escreve em pb\logs\pocketbase-AAAAMM.log.

param([string]$Escuta = "127.0.0.1:8090")

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
  foreach ($line in Get-Content $envFile) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    $i = $t.IndexOf("=")
    if ($i -lt 1) { continue }
    $k = $t.Substring(0, $i).Trim().TrimStart([char]0xFEFF)
    $v = $t.Substring($i + 1).Trim().Trim('"')
    Set-Item -Path "Env:$k" -Value $v
  }
} else {
  Write-Host "AVISO: pb\.env nao existe (sem chaves de IA/Vendus/cifra)." -ForegroundColor Yellow
}

# Producao: contas novas NAO ficam verificadas sem email.
$env:TURNKEY_DEV = "0"

if (-not $env:TURNKEY_ENC_KEY -or $env:TURNKEY_ENC_KEY.Length -ne 32) {
  Write-Host "AVISO: TURNKEY_ENC_KEY em falta ou sem 32 caracteres: nao da para guardar tokens (Vendus). Gera com .\gerar-chave-cifra.ps1 -Gravar" -ForegroundColor Yellow
}

$bin = Join-Path $PSScriptRoot "bin\pocketbase.exe"
if (-not (Test-Path $bin)) { throw "Nao encontrei $bin" }
$web = Join-Path $PSScriptRoot "web"
if (-not (Test-Path (Join-Path $web "index.html"))) {
  Write-Host "AVISO: pb\web\index.html nao existe: so a API vai funcionar (sem a app web)." -ForegroundColor Yellow
}

$logs = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force $logs | Out-Null
$log = Join-Path $logs ("pocketbase-" + (Get-Date -Format "yyyyMM") + ".log")

Write-Host "PocketBase em http://$Escuta  (registo: $log)"
& $bin serve `
  --dir (Join-Path $PSScriptRoot "pb_data") `
  --migrationsDir (Join-Path $PSScriptRoot "migrations") `
  --hooksDir (Join-Path $PSScriptRoot "hooks") `
  --publicDir $web `
  --http $Escuta *>> $log
