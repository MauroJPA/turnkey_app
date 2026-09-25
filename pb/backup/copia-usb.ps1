# Copia semanal para um disco/pen USB (com BitLocker ligado): o backup mais
# recente do PocketBase + o pb\.env (segredos). Mantem as ultimas 12 copias.
#
#   .\copia-usb.ps1 -Unidade E:
#
# O USB deve ficar guardado FORA do Mini PC depois da copia.

param(
  [Parameter(Mandatory = $true)][string]$Unidade,
  [string]$PbDir = (Split-Path -Parent $PSScriptRoot),
  [int]$Manter = 12
)

$ErrorActionPreference = "Stop"
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir "copia-usb.log"
function Log($m, $n = "INFO") {
  $l = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $n, $m
  Add-Content -Path $logFile -Value $l; Write-Host $l
}

$raiz = $Unidade.TrimEnd("\") + "\"
if (-not (Test-Path $raiz)) { Log "Unidade $Unidade nao encontrada. Liga o USB e desbloqueia o BitLocker." "ERRO"; exit 1 }

$pastaBackups = Join-Path $PbDir "pb_data\backups"
$ultimo = Get-ChildItem $pastaBackups -Filter *.zip -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $ultimo) { Log "Nao ha backups em $pastaBackups." "ERRO"; exit 1 }

$destino = Join-Path $raiz "GookieBackups"
New-Item -ItemType Directory -Force -Path $destino | Out-Null

# espaco livre: pelo menos 3x o tamanho do ficheiro
$livre = (Get-PSDrive -Name $Unidade.TrimEnd(":\").Substring(0, 1)).Free
if ($livre -lt ($ultimo.Length * 3)) { Log "Pouco espaco livre no USB ($([math]::Round($livre/1MB)) MB)." "ERRO"; exit 1 }

Copy-Item $ultimo.FullName $destino -Force
$copia = Join-Path $destino $ultimo.Name
if ((Get-Item $copia).Length -ne $ultimo.Length) { Log "A copia $($ultimo.Name) ficou com tamanho diferente." "ERRO"; exit 1 }
Log ("Copiado {0} ({1:N1} MB) para {2}" -f $ultimo.Name, ($ultimo.Length / 1MB), $destino)

$envFile = Join-Path $PbDir ".env"
if (Test-Path $envFile) {
  Copy-Item $envFile (Join-Path $destino "env-ultimo.txt") -Force
  Log "pb\.env copiado (o USB tem de ter BitLocker)."
}

# manter so as ultimas N copias
Get-ChildItem $destino -Filter *.zip -File | Sort-Object LastWriteTime -Descending |
  Select-Object -Skip $Manter | ForEach-Object {
    Remove-Item $_.FullName -Force; Log "Removida copia antiga $($_.Name)"
  }
Log "Concluido. Retira o USB e guarda-o fora do Mini PC."
exit 0
