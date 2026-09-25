# Copia o backup mais recente do PocketBase para a nuvem (Google Drive), CIFRADO
# antes de sair do computador (rclone "crypt"). Corre todas as noites (03:30) por
# tarefa agendada — ver instalar-tarefas.ps1 e LEIA-ME.md.
#
#   .\copia-externa.ps1                       # usa o remoto "gookie-crypt:"
#   .\copia-externa.ps1 -Remote "outro:"      # outro remoto rclone
#
# Retencao: 30 dias em "diario/" + 12 meses em "mensal/" (dia 1 de cada mes).
# Alerta por email (opcional) se falhar: variaveis BACKUP_ALERT_TO,
# BACKUP_SMTP_HOST, BACKUP_SMTP_PORT, BACKUP_SMTP_USER, BACKUP_SMTP_PASS em pb\.env.

param(
  [string]$Remote = "gookie-crypt:",
  [string]$RcloneExe = "rclone",
  [string]$PbDir = (Split-Path -Parent $PSScriptRoot),
  [int]$DiasDiarios = 30,
  [int]$MesesMensais = 12,
  [int]$IdadeMaximaHoras = 30
)

$ErrorActionPreference = "Stop"
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir "copia-externa.log"

function Log($msg, $nivel = "INFO") {
  $linha = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $nivel, $msg
  Add-Content -Path $logFile -Value $linha
  Write-Host $linha
}

function CarregarEnv {
  $f = Join-Path $PbDir ".env"
  if (-not (Test-Path $f)) { return }
  foreach ($l in Get-Content $f) {
    $t = $l.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    $i = $t.IndexOf("=")
    if ($i -lt 1) { continue }
    Set-Item -Path ("Env:" + $t.Substring(0, $i).Trim()) -Value $t.Substring($i + 1).Trim().Trim('"')
  }
}

function Alertar($assunto, $corpo) {
  CarregarEnv
  if (-not $env:BACKUP_ALERT_TO -or -not $env:BACKUP_SMTP_HOST) {
    Log "Sem BACKUP_ALERT_TO/BACKUP_SMTP_HOST em pb\.env - alerta por email nao enviado." "AVISO"
    return
  }
  try {
    $port = 587
    if ($env:BACKUP_SMTP_PORT) { $port = [int]$env:BACKUP_SMTP_PORT }
    $mail = @{
      To = $env:BACKUP_ALERT_TO; From = $env:BACKUP_SMTP_USER
      Subject = $assunto; Body = $corpo
      SmtpServer = $env:BACKUP_SMTP_HOST; Port = $port; UseSsl = $true
    }
    if ($env:BACKUP_SMTP_USER -and $env:BACKUP_SMTP_PASS) {
      $sec = ConvertTo-SecureString $env:BACKUP_SMTP_PASS -AsPlainText -Force
      $mail.Credential = New-Object System.Management.Automation.PSCredential($env:BACKUP_SMTP_USER, $sec)
    }
    Send-MailMessage @mail
    Log "Alerta enviado para $($env:BACKUP_ALERT_TO)."
  } catch {
    Log "Falhou o envio do alerta: $($_.Exception.Message)" "ERRO"
  }
}

function Falhar($msg) {
  Log $msg "ERRO"
  Alertar "[Gookie] FALHA no backup externo" ($msg + "`n`nVer " + $logFile)
  exit 1
}

function Rclone {
  & $RcloneExe @args | Out-Null
  return $LASTEXITCODE
}

# --- 1. o backup do PocketBase de hoje existe? ---------------------------------
$pastaBackups = Join-Path $PbDir "pb_data\backups"
if (-not (Test-Path $pastaBackups)) { Falhar "Pasta de backups nao existe: $pastaBackups" }
$ultimo = Get-ChildItem $pastaBackups -Filter *.zip -File |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $ultimo) { Falhar "Nao ha nenhum .zip em $pastaBackups (o backup das 03:00 do PocketBase nao correu?)." }
$idade = (New-Object TimeSpan((Get-Date).Ticks - $ultimo.LastWriteTime.Ticks)).TotalHours
if ($idade -gt $IdadeMaximaHoras) {
  Falhar ("O backup mais recente ({0}) tem {1:N0} h - o backup automatico do PocketBase falhou." -f $ultimo.Name, $idade)
}
Log ("Backup a enviar: {0} ({1:N1} MB)" -f $ultimo.Name, ($ultimo.Length / 1MB))

# --- 2. enviar (cifrado pelo remoto crypt) --------------------------------------
$rc = Rclone copy $ultimo.FullName ($Remote + "diario") --checksum
if ($rc -ne 0) { Falhar "rclone copy (diario) falhou com codigo $rc." }

# confirmar que chegou
$existe = & $RcloneExe lsf ($Remote + "diario") --files-only
if ($LASTEXITCODE -ne 0 -or -not ($existe -contains $ultimo.Name)) {
  Falhar "O ficheiro $($ultimo.Name) nao aparece no destino depois de enviado."
}
Log "Enviado e confirmado em ${Remote}diario/."

# copia mensal (dia 1)
if ((Get-Date).Day -eq 1) {
  $rc = Rclone copy $ultimo.FullName ($Remote + "mensal") --checksum
  if ($rc -ne 0) { Falhar "rclone copy (mensal) falhou com codigo $rc." }
  Log "Copia mensal guardada em ${Remote}mensal/."
}

# --- 3. retencao ---------------------------------------------------------------
$rc = Rclone delete ($Remote + "diario") --min-age ("{0}d" -f $DiasDiarios)
if ($rc -ne 0) { Log "Limpeza dos diarios falhou (codigo $rc) - nao bloqueia." "AVISO" }
$rc = Rclone delete ($Remote + "mensal") --min-age ("{0}d" -f ($MesesMensais * 31))
if ($rc -ne 0) { Log "Limpeza dos mensais falhou (codigo $rc) - nao bloqueia." "AVISO" }

Log "Concluido."
exit 0
