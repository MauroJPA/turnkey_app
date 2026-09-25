# Gera a chave-mestra que cifra os tokens guardados na base de dados
# (TURNKEY_ENC_KEY: 32 caracteres, ~192 bits de aleatoriedade).
#
#   cd pb ; .\gerar-chave-cifra.ps1            # so mostra uma chave nova
#   cd pb ; .\gerar-chave-cifra.ps1 -Gravar    # acrescenta-a a pb\.env (se ainda nao existir)
#
# IMPORTANTE
#  - Guarda uma copia da chave num gestor de palavras-passe, FORA do PC e FORA
#    dos backups da base de dados. Sem ela, os tokens cifrados nao se recuperam
#    (tens de os voltar a introduzir na app).
#  - Nunca mudes a chave depois de haver tokens guardados (ficam ilegiveis).
#  - pb\.env esta fora do git; nao o copies para o repositorio nem para a nuvem
#    sem cifra.

param([switch]$Gravar)

$ErrorActionPreference = "Stop"
$alfabeto = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"  # 64 simbolos
$bytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$chave = -join ($bytes | ForEach-Object { $alfabeto[$_ -band 63] })

if (-not $Gravar) {
  Write-Host "TURNKEY_ENC_KEY=$chave"
  Write-Host "(Para gravar em pb\.env: .\gerar-chave-cifra.ps1 -Gravar)"
  exit 0
}

$ficheiroEnv = Join-Path $PSScriptRoot ".env"
if ((Test-Path $ficheiroEnv) -and (Select-String -Path $ficheiroEnv -Pattern '^\s*TURNKEY_ENC_KEY\s*=' -Quiet)) {
  Write-Host "pb\.env ja tem TURNKEY_ENC_KEY. Nao foi alterado (mudar a chave tornaria ilegiveis os tokens guardados)."
  exit 0
}
Add-Content -Path $ficheiroEnv -Value "`nTURNKEY_ENC_KEY=$chave" -Encoding UTF8
Write-Host "Chave gravada em pb\.env (nao e mostrada aqui de proposito)."
Write-Host "Abre pb\.env, copia a linha TURNKEY_ENC_KEY para o gestor de palavras-passe e reinicia o PocketBase (.\serve.ps1)."
