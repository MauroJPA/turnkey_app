# Cria o pacote para instalar no servidor Linux (Docker): a app web compilada,
# hooks/migrations do PocketBase, Dockerfile + compose, scripts de gestao e de
# backups, e os documentos.
#
#   powershell -ExecutionPolicy Bypass -File scripts\empacotar-producao.ps1
#
# Resultado: dist\gc_turnkey-servidor-<versao>.tar.gz  (e a pasta dist\gc_turnkey-servidor).
# Correr na raiz do projeto, no ramo main (versao lancada). Nao inclui dados
# (data), chaves (.env) nem copias de seguranca. Instalar: docs\SERVIDOR_LINUX.md

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$versao = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value -split '\+')[0]
$commit = (git rev-parse --short HEAD).Trim()
$ramo = (git branch --show-current).Trim()
if ($ramo -ne "main") { Write-Host "AVISO: estas a empacotar o ramo '$ramo' (o normal e 'main')." -ForegroundColor Yellow }
if ((git status --porcelain | Where-Object { $_ -notmatch '^\?\?' })) { throw "Ha alteracoes por gravar no git. Faz commit primeiro." }

Write-Host "1/4  A compilar a app web (v$versao) ..."
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --dart-define=PB_URL=origin --dart-define=APP_VERSION=$versao
if ($LASTEXITCODE -ne 0) { throw "flutter build web falhou" }

$saida = Join-Path (Get-Location) "dist\gc_turnkey-servidor"
if (Test-Path $saida) { Remove-Item $saida -Recurse -Force }
New-Item -ItemType Directory -Force "$saida\docs", "$saida\backup", "$saida\seguranca" | Out-Null

Write-Host "2/4  A juntar ficheiros ..."
Copy-Item "build\web" "$saida\web" -Recurse

# Comprime os ficheiros grandes da app (<ficheiro>.gz ao lado): o servidor
# (pb/hooks/web_cabecalhos.pb.js) serve-os a quem aceita gzip -> o primeiro
# carregamento no telemovel passa de ~12 MB para ~3 MB.
$tiposGz = ".js", ".wasm", ".json", ".css", ".svg", ".otf", ".ttf", ".html", ".frag"
Get-ChildItem "$saida\web" -Recurse -File | Where-Object {
  $tiposGz -contains $_.Extension.ToLower() -and $_.Length -ge 1024
} | ForEach-Object {
  $dest = $_.FullName + ".gz"
  $in = [System.IO.File]::OpenRead($_.FullName)
  $out = [System.IO.File]::Create($dest)
  $gz = New-Object System.IO.Compression.GZipStream($out, [System.IO.Compression.CompressionLevel]::Optimal)
  $in.CopyTo($gz); $gz.Dispose(); $out.Dispose(); $in.Dispose()
}
Copy-Item "pb\hooks" "$saida\hooks" -Recurse
Copy-Item "pb\migrations" "$saida\migrations" -Recurse
foreach ($f in "Dockerfile", "compose.yaml", ".env.example", "gc_turnkey.sh") {
  Copy-Item "deploy\$f" "$saida\$f"
}
Copy-Item "deploy\backup\*" "$saida\backup" -Recurse
Remove-Item "$saida\backup\logs" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "deploy\seguranca\*" "$saida\seguranca" -Recurse
Remove-Item "$saida\seguranca\__pycache__" -Recurse -Force -ErrorAction SilentlyContinue
foreach ($d in "SERVIDOR_LINUX.md", "BACKUPS.md", "SEGURANCA.md") {
  Copy-Item "docs\$d" "$saida\docs\$d"
}
$pbv = (Select-String -Path deploy\compose.yaml -Pattern 'PB_VERSION:-([0-9.]+)').Matches[0].Groups[1].Value
@"
gc_turnkey - pacote de producao (Linux/Docker)
App:        v$versao (commit $commit, ramo $ramo)
PocketBase: $pbv (descarregado ao construir a imagem, com SHA-256 conferido)
Criado em:  $(Get-Date -Format s)
Instalar:   ver docs/SERVIDOR_LINUX.md
"@ | Set-Content "$saida\VERSAO.txt" -Encoding UTF8

# Tudo o que e texto vai com fins de linha Unix (LF): os scripts .sh nao
# funcionam com CRLF. (A app web compilada nao se mexe.)
$utf8 = New-Object System.Text.UTF8Encoding($false)
Get-ChildItem $saida -Recurse -File | Where-Object {
  $_.FullName -notlike "$saida\web\*" -and $_.Extension -in ".sh", ".md", ".yaml", ".js", ".txt", ".example", ".py", ""
} | ForEach-Object {
  $t = [System.IO.File]::ReadAllText($_.FullName)
  [System.IO.File]::WriteAllText($_.FullName, ($t -replace "`r`n", "`n"), $utf8)
}

Write-Host "3/4  A criar o .tar.gz ..."
$tgz = Join-Path (Get-Location) "dist\gc_turnkey-servidor-$versao.tar.gz"
if (Test-Path $tgz) { Remove-Item $tgz -Force }
tar -czf $tgz -C $saida .
if ($LASTEXITCODE -ne 0) { throw "tar falhou" }
$hash = (Get-FileHash $tgz -Algorithm SHA256).Hash

Write-Host "4/4  Pronto."
Write-Host "  $tgz  ($([math]::Round((Get-Item $tgz).Length / 1MB, 1)) MB)"
Write-Host "  SHA-256: $hash"
Write-Host "Copia para o servidor (scp) e segue docs\SERVIDOR_LINUX.md. Confere o SHA-256 la (sha256sum)."
