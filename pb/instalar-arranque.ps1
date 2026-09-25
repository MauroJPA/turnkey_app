# Instala o PocketBase como tarefa de arranque do Windows (Mini PC):
# arranca sozinho com o PC (sem ninguem ter sessao iniciada), reinicia se falhar
# e uma "vigia" verifica de 5 em 5 minutos se responde.
#
#   Abrir a PowerShell COMO ADMINISTRADOR:
#   cd C:\Gookie\pb
#   .\instalar-arranque.ps1                    # so acessivel neste PC / atras de tunel
#   .\instalar-arranque.ps1 -Rede              # tambem acessivel na rede local (porta 8090)
#   .\instalar-arranque.ps1 -Desinstalar
#
# Nao precisa de software extra (usa o Agendador de Tarefas).

param(
  [switch]$Rede,
  [switch]$Desinstalar,
  [int]$Porta = 8090
)

$ErrorActionPreference = "Stop"
$nomeServ = "Gookie PocketBase"
$nomeVigia = "Gookie PocketBase vigia"
$regraFw = "Gookie PocketBase (rede local)"

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw "Corre esta PowerShell como Administrador." }

if ($Desinstalar) {
  foreach ($n in $nomeServ, $nomeVigia) {
    Stop-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $n -Confirm:$false -ErrorAction SilentlyContinue
  }
  Remove-NetFirewallRule -DisplayName $regraFw -ErrorAction SilentlyContinue
  Get-Process pocketbase -ErrorAction SilentlyContinue | Stop-Process -Force
  Write-Host "Desinstalado."
  exit 0
}

$pb = $PSScriptRoot
$escuta = if ($Rede) { "0.0.0.0:$Porta" } else { "127.0.0.1:$Porta" }
$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

# --- servidor ---------------------------------------------------------------
$acao = New-ScheduledTaskAction -Execute $ps -WorkingDirectory $pb `
  -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$pb\serve-producao.ps1`" -Escuta $escuta"
$gatilho = New-ScheduledTaskTrigger -AtStartup
$def = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
  -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$quem = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $nomeServ -Action $acao -Trigger $gatilho -Settings $def -Principal $quem -Force | Out-Null

# --- vigia: se nao responder duas vezes seguidas, reinicia -------------------
$script = @"
`$ok = `$false
foreach (`$i in 1..2) {
  try { if ((Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:$Porta/api/health' -TimeoutSec 10).StatusCode -eq 200) { `$ok = `$true; break } } catch {}
  Start-Sleep -Seconds 15
}
if (-not `$ok) {
  Add-Content -Path '$pb\logs\vigia.log' -Value ((Get-Date -Format s) + ' sem resposta: a reiniciar')
  Get-Process pocketbase -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 3
  Start-ScheduledTask -TaskName '$nomeServ'
}
"@
New-Item -ItemType Directory -Force "$pb\logs" | Out-Null
$vigiaPs1 = Join-Path $pb "vigia.ps1"
Set-Content -Path $vigiaPs1 -Value $script -Encoding UTF8
$acaoV = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$vigiaPs1`""
$gatV = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName $nomeVigia -Action $acaoV -Trigger $gatV -Settings $def -Principal $quem -Force | Out-Null

# --- firewall ----------------------------------------------------------------
Remove-NetFirewallRule -DisplayName $regraFw -ErrorAction SilentlyContinue
if ($Rede) {
  New-NetFirewallRule -DisplayName $regraFw -Direction Inbound -Protocol TCP -LocalPort $Porta `
    -Action Allow -Profile Private | Out-Null
  Write-Host "Firewall: porta $Porta aberta so na rede PRIVADA."
}

Start-ScheduledTask -TaskName $nomeServ
Write-Host "Instalado. PocketBase a escutar em http://$escuta (arranca sozinho com o PC)."
Write-Host "Registos em $pb\logs. Para desinstalar: .\instalar-arranque.ps1 -Desinstalar"
