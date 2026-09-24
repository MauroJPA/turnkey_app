# Backups — instalação no Mini PC

Plano e razões em `docs/BACKUPS.md`. Aqui ficam os passos, **por ordem**.
Decisões tomadas: destino **Google Drive**, cifra **rclone crypt** (a chave fica com o
Mauro), retenção **30 diários + 12 mensais**, cópia semanal para **USB**.

## 0. O que já funciona sem fazer nada

A migration `1707609600_backups_cron.js` liga o backup automático do PocketBase:
**todas as noites às 03:00**, guarda os **7** mais recentes em `pb\pb_data\backups\`.
Aplica-se sozinha quando se reinicia o `serve.ps1`. (Confirmar em Admin UI →
Definições → Backups.)

## 1. Instalar o rclone (uma vez, no Mini PC)

```powershell
winget install Rclone.Rclone
rclone version
```

## 2. Ligar ao Google Drive

```powershell
rclone config
```

1. `n` (novo remoto) → nome: **`gdrive`**
2. Storage: escrever **`drive`** (Google Drive)
3. `client_id` e `client_secret`: deixar vazios (Enter)
4. `scope`: escolher **`3` — drive.file** ("só ficheiros criados pelo rclone"). Assim o
   rclone **não consegue ver nem apagar** mais nada da conta.
5. Restantes perguntas: Enter (valores por omissão). "Use web browser to automatically
   authenticate?" → **y** e fazer login na conta Google **da empresa** que vai guardar os backups.
6. "Configure as Shared Drive?" → n. Confirmar e sair.

> O Google Drive gratuito tem 15 GB **partilhados** com o Gmail dessa conta. Ver o
> cálculo de espaço no fim.

## 3. Criar o remoto cifrado (a parte crítica)

Na mesma `rclone config`:

1. `n` → nome: **`gookie-crypt`** → storage: **`crypt`**
2. `remote`: **`gdrive:GookieBackups`**
3. `filename_encryption`: **standard** · `directory_name_encryption`: **true**
4. Password: escolher **g** (gerar) com **1024 bits** → o rclone **mostra a password**
   → **copiar já**
5. Password2 (o "sal"): **g** de novo → **copiar também**
6. Guardar.

**Guardar a password e o sal AGORA** (o rclone só as mostra nesta altura):
- no gestor de palavras-passe;
- numa **folha impressa** num sítio seguro.

**Sem estas duas coisas os backups não se conseguem abrir — nem por nós, nem pela Google.**
Não guardar no Git nem no mesmo disco que os backups. Guardar também uma cópia do
ficheiro `rclone.conf` (`rclone config file` diz onde está) num sítio seguro: tem o
acesso ao Drive **e** as chaves.

## 4. Testar a ligação

```powershell
cd C:\...\turnkey_app\pb\backup
"teste" | Out-File $env:TEMP\t.txt
rclone copy $env:TEMP\t.txt gookie-crypt:teste
rclone lsf gookie-crypt:teste          # mostra t.txt
```

No Google Drive, a pasta `GookieBackups` deve mostrar **nomes ilegíveis**
(é a prova de que está cifrado). Apagar depois: `rclone purge gookie-crypt:teste`.

## 5. Primeira cópia à mão

Reiniciar o `serve.ps1` (para a migration do cron), esperar pelas 03:00 **ou** criar um
backup já em Admin UI → Definições → Backups → "Initialize backup". Depois:

```powershell
.\copia-externa.ps1
```

Tem de terminar com `Concluido.` (os registos ficam em `logs\copia-externa.log`).

## 6. Agendar a cópia noturna

Como **Administrador**:

```powershell
.\instalar-tarefas.ps1            # todos os dias às 03:30
Start-ScheduledTask -TaskName Gookie-Backup-Nuvem    # testar já
```

A tarefa corre com a conta do Windows atual (é onde está o `rclone.conf`).

## 7. Alerta por email se falhar (recomendado)

Em `pb\.env` acrescentar (ver `.env.example`): `BACKUP_ALERT_TO`, `BACKUP_SMTP_HOST`,
`BACKUP_SMTP_PORT`, `BACKUP_SMTP_USER`, `BACKUP_SMTP_PASS` (no Gmail usar uma
"palavra-passe de aplicação"). Sem isto a falha só fica no registo e no Agendador
(coluna "Resultado da última execução" diferente de 0).

## 8. USB semanal

1. Ligar o USB → clicar com o botão direito na unidade → **Ativar BitLocker** (guardar a
   chave de recuperação no gestor de palavras-passe).
2. Todos os domingos: ligar o USB e correr `.\copia-usb.ps1 -Unidade E:` (a letra pode variar).
3. Retirar o USB e guardá-lo **fora do Mini PC**. Mantém as últimas 12 cópias e o `pb\.env`.

## 9. Teste de restauro (todos os meses)

```powershell
.\teste-restauro.ps1                          # a partir da nuvem (decifra)
.\teste-restauro.ps1 -Origem E:\GookieBackups  # a partir do USB
```

Tem de acabar com `RESTAURO OK`. Não toca na produção (usa uma pasta temporária e a
porta 8199). Anotar a data e o tempo.

## Restauro a sério (desastre)

1. Parar o `serve.ps1`.
2. `rclone copy gookie-crypt:diario/<ficheiro>.zip .` (decifra) — ou copiar do USB.
3. Renomear a `pb_data` atual (não apagar) e descompactar o `.zip` para uma nova `pb\pb_data`.
4. Repor `pb\.env` (do cofre/USB) e arrancar `.\serve.ps1`.
5. Entrar e conferir vendas/produções recentes e as imagens.

## Quanto espaço é preciso

**Uma cópia = 1 ficheiro `.zip` de tudo** (base de dados + imagens/PDFs). Hoje pesa
menos de 1 MB por cada 7 MB de dados de teste; com a app em uso serão dezenas a
centenas de MB (as fotos de faturas são o que mais pesa).

| Onde | Cópias | Conta | Espaço |
|---|---|---|---|
| Google Drive | 30 diárias + 12 mensais = **42** | 42 × tamanho | 15 GB chegam enquanto cada cópia tiver **< 350 MB** |
| USB | **12** semanais + `.env` | 12 × tamanho | Uma cópia de 500 MB → 6 GB |

**USB: 32 GB chegam**; recomendo **64 GB** (ou um disco externo pequeno, que costuma
durar mais do que uma pen). Se as cópias passarem os 350 MB, ou passa-se a Google One
(100 GB, ≈ 2 €/mês) ou muda-se para o Backblaze B2 — o `-Remote` dos scripts é só o
nome do remoto rclone, por isso a migração é trocar o `gdrive:` por outro destino.
