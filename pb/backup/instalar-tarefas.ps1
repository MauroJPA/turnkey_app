# Cria a tarefa agendada do Windows para a copia noturna para a nuvem.
# Correr UMA vez, como Administrador, depois de configurar o rclone (LEIA-ME.md).
#
#   .\instalar-tarefas.ps1
#   .\instalar-tarefas.ps1 -Hora "03:30" -Remover     # desinstalar

param(
  [string]$Hora = "03:30",
  [switch]$Remover
)

$nome = "Gookie-Backup-Nuvem"
if ($Remover) {
  Unregister-ScheduledTask -TaskName $nome -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host "Tarefa removida."
  exit 0
}

$script = Join-Path $PSScriptRoot "copia-externa.ps1"
$acao = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -WorkingDirectory $PSScriptRoot
$gatilho = New-ScheduledTaskTrigger -Daily -At $Hora
$def = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 `
  -RestartInterval (New-TimeSpan -Minutes 15) -ExecutionTimeLimit (New-TimeSpan -Hours 2)

# corre com a conta atual (e la que esta o rclone.conf com a chave)
Register-ScheduledTask -TaskName $nome -Action $acao -Trigger $gatilho -Settings $def `
  -Description "Envia o backup do PocketBase para o Google Drive (cifrado)." -Force | Out-Null

Write-Host "Tarefa '$nome' criada: todos os dias as $Hora."
Write-Host "Ver em: Agendador de Tarefas. Testar ja: Start-ScheduledTask -TaskName $nome"
Write-Host "Nota: o PocketBase cria o backup as 03:00; esta tarefa envia-o as $Hora."
