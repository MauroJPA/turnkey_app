# Atualiza o binário do PocketBase (pb\bin\pocketbase.exe) com segurança.
#   cd pb ; .\atualizar-pocketbase.ps1            # última versão testada (ver $VersaoPadrao)
#   cd pb ; .\atualizar-pocketbase.ps1 -Versao 0.40.4
#
# O que faz: descarrega o zip oficial, confere o SHA-256 com o checksums.txt da
# release, copia pb_data para pb_data_antes_<versão>_<data> (cópia de
# segurança), guarda o binário antigo como pocketbase.exe.antiga e põe o novo.
# NÃO reinicia o servidor: quem estiver a correr continua na versão antiga até
# o parares e voltares a arrancar (.\serve.ps1). Para voltar atrás: para o
# servidor, apaga pocketbase.exe, renomeia pocketbase.exe.antiga e (se for
# preciso) repõe a pasta pb_data_antes_*.
#
# Depois de atualizar: bash scripts/verificar.sh (na raiz do projeto).

param([string]$Versao = "0.40.4")

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$exe = Join-Path $PSScriptRoot "bin\pocketbase.exe"
if (-not (Test-Path $exe)) { throw "Não encontrei $exe" }
$atual = (& $exe --version) -join " "
Write-Host "Versão atual: $atual"
if ($atual -match [regex]::Escape($Versao)) { Write-Host "Já está na $Versao."; exit 0 }

$zip = "pocketbase_${Versao}_windows_amd64.zip"
$base = "https://github.com/pocketbase/pocketbase/releases/download/v$Versao"
$tmp = Join-Path $env:TEMP "pb_update_$Versao"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Force $tmp | Out-Null

Write-Host "A descarregar $zip ..."
Invoke-WebRequest "$base/$zip" -OutFile (Join-Path $tmp $zip)
Invoke-WebRequest "$base/checksums.txt" -OutFile (Join-Path $tmp "checksums.txt")

$linha = Select-String -Path (Join-Path $tmp "checksums.txt") -Pattern ([regex]::Escape($zip)) | Select-Object -First 1
if (-not $linha) { throw "Sem checksum para $zip na release." }
$esperado = ($linha.Line -split "\s+")[0].ToLower()
$real = (Get-FileHash (Join-Path $tmp $zip) -Algorithm SHA256).Hash.ToLower()
if ($esperado -ne $real) { throw "SHA-256 não confere (esperado $esperado, obtido $real). Abortado." }
Write-Host "SHA-256 confere."

Expand-Archive (Join-Path $tmp $zip) -DestinationPath (Join-Path $tmp "novo") -Force
$novo = Join-Path $tmp "novo\pocketbase.exe"
if ((& $novo --version) -notmatch [regex]::Escape($Versao)) { throw "O binário descarregado não é a $Versao." }

$copia = "pb_data_antes_v${Versao}_" + (Get-Date -Format "yyyyMMdd-HHmm")
if (Test-Path "pb_data") {
  Copy-Item "pb_data" $copia -Recurse
  Write-Host "Cópia de segurança dos dados: pb\$copia"
}

$antiga = "$exe.antiga"
if (Test-Path $antiga) { Remove-Item $antiga -Force }
Move-Item $exe $antiga
Copy-Item $novo $exe
Write-Host "Binário atualizado: $((& $exe --version) -join ' ')"
Write-Host "O servidor que estiver a correr mantém a versão antiga até o reiniciares (.\serve.ps1)."
