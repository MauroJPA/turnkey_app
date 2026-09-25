# Cria o pacote para instalar no Mini PC: a app web compilada + PocketBase +
# hooks/migrations + scripts de arranque, backups e atualizacao + documentos.
#
#   powershell -ExecutionPolicy Bypass -File scripts\empacotar-producao.ps1
#
# Resultado: dist\gookie-producao-<versao>.zip  (e a pasta dist\gookie-producao).
# Correr na raiz do projeto, no ramo main (versao lancada). Nao inclui dados
# (pb_data), chaves (pb\.env) nem cópias de seguranca.

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$versao = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value -split '\+')[0]
$commit = (git rev-parse --short HEAD).Trim()
$ramo = (git branch --show-current).Trim()
if ($ramo -ne "main") { Write-Host "AVISO: estas a empacotar o ramo '$ramo' (o normal e 'main')." -ForegroundColor Yellow }
if ((git status --porcelain | Where-Object { $_ -notmatch '^\?\?' })) { throw "Ha alteracoes por gravar no git. Faz commit primeiro." }

Write-Host "1/4  A compilar a app web (v$versao) ..."
flutter build web --release --no-wasm-dry-run --dart-define=PB_URL=origin
if ($LASTEXITCODE -ne 0) { throw "flutter build web falhou" }

$saida = Join-Path (Get-Location) "dist\gookie-producao"
if (Test-Path $saida) { Remove-Item $saida -Recurse -Force }
New-Item -ItemType Directory -Force "$saida\pb", "$saida\docs" | Out-Null

Write-Host "2/4  A juntar ficheiros ..."
Copy-Item "build\web" "$saida\pb\web" -Recurse
New-Item -ItemType Directory -Force "$saida\pb\bin" | Out-Null
Copy-Item "pb\bin\pocketbase.exe" "$saida\pb\bin\pocketbase.exe"
Copy-Item "pb\hooks" "$saida\pb\hooks" -Recurse
Copy-Item "pb\migrations" "$saida\pb\migrations" -Recurse
Copy-Item "pb\backup" "$saida\pb\backup" -Recurse
Remove-Item "$saida\pb\backup\logs" -Recurse -Force -ErrorAction SilentlyContinue
foreach ($f in "serve-producao.ps1", "instalar-arranque.ps1", "gerar-chave-cifra.ps1", "atualizar-pocketbase.ps1") {
  Copy-Item "pb\$f" "$saida\pb\$f"
}
Copy-Item "pb\.env.example" "$saida\pb\.env.example"
foreach ($d in "MINI_PC.md", "BACKUPS.md", "SEGURANCA.md") {
  Copy-Item "docs\$d" "$saida\docs\$d"
}
$pbv = ((& "pb\bin\pocketbase.exe" --version) -join " ")
@"
Gookie - pacote de producao
App:        v$versao (commit $commit, ramo $ramo)
PocketBase: $pbv
Criado em:  $(Get-Date -Format s)
Instalar:   ver docs\MINI_PC.md
"@ | Set-Content "$saida\VERSAO.txt" -Encoding UTF8

Write-Host "3/4  A criar o zip ..."
$zip = Join-Path (Get-Location) "dist\gookie-producao-$versao.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$saida\*" -DestinationPath $zip
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash

Write-Host "4/4  Pronto."
Write-Host "  $zip  ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)"
Write-Host "  SHA-256: $hash"
Write-Host "Copia o zip para o Mini PC (USB/rede) e segue docs\MINI_PC.md. Confere o SHA-256 la."
