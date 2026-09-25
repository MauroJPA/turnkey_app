# Teste de restauro (fazer todos os meses): descarrega e DECIFRA o backup mais
# recente da nuvem, descompacta numa pasta temporaria, arranca uma copia do
# PocketBase nessa pasta e confirma que responde. Nao toca na producao.
#
#   .\teste-restauro.ps1
#   .\teste-restauro.ps1 -Origem "D:\GookieBackups"     # testar a partir do USB

param(
  [string]$Remote = "gookie-crypt:",
  [string]$RcloneExe = "rclone",
  [string]$Origem = "",
  [string]$PbDir = (Split-Path -Parent $PSScriptRoot),
  [int]$Porta = 8199
)

$ErrorActionPreference = "Stop"
$inicio = Get-Date
$tmp = Join-Path $env:TEMP ("gookie-restauro-" + (Get-Date -Format "yyyyMMddHHmmss"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = $null

if ($Origem) {
  $zip = Get-ChildItem $Origem -Filter *.zip -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $zip) { throw "Sem .zip em $Origem" }
  Copy-Item $zip.FullName $tmp
  $zipPath = Join-Path $tmp $zip.Name
} else {
  Write-Host "A obter o ultimo backup de $Remote (decifra automaticamente)..."
  $lista = & $RcloneExe lsf ($Remote + "diario") --files-only | Sort-Object -Descending
  if ($LASTEXITCODE -ne 0 -or -not $lista) { throw "Nao consegui listar ${Remote}diario (chave/remoto errados?)." }
  $nome = @($lista)[0]
  & $RcloneExe copy ($Remote + "diario/" + $nome) $tmp
  if ($LASTEXITCODE -ne 0) { throw "Falhou o download." }
  $zipPath = Join-Path $tmp $nome
}
if (-not (Test-Path $zipPath)) { throw "Ficheiro descarregado nao encontrado." }
Write-Host ("Backup: {0} ({1:N1} MB)" -f (Split-Path $zipPath -Leaf), ((Get-Item $zipPath).Length / 1MB))

$dados = Join-Path $tmp "pb_data"
Expand-Archive -Path $zipPath -DestinationPath $dados -Force
if (-not (Test-Path (Join-Path $dados "data.db"))) { throw "O zip nao tem data.db - backup invalido." }
$ficheiros = @(Get-ChildItem (Join-Path $dados "storage") -Recurse -File -ErrorAction SilentlyContinue).Count
Write-Host "Descompactado. Ficheiros em storage: $ficheiros"

$bin = Join-Path $PbDir "bin\pocketbase.exe"
if (-not (Test-Path $bin)) { throw "PocketBase nao encontrado em $bin" }
$p = Start-Process -FilePath $bin -PassThru -WindowStyle Hidden -ArgumentList @(
  "serve", "--http=127.0.0.1:$Porta", "--dir=$dados",
  "--migrationsDir=$(Join-Path $PbDir 'migrations')", "--hooksDir=$(Join-Path $PbDir 'hooks')")
$ok = $false
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 1
  try { if ((Invoke-RestMethod "http://127.0.0.1:$Porta/api/health").code -eq 200) { $ok = $true; break } } catch {}
}
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

$dur = (Get-Date) - $inicio
if ($ok) {
  Write-Host ("RESTAURO OK em {0:N0} s. Regista a data e o tempo." -f $dur.TotalSeconds) -ForegroundColor Green
  exit 0
}
Write-Host "RESTAURO FALHOU: o PocketBase nao arrancou com o backup." -ForegroundColor Red
exit 1
