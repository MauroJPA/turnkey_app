# Backups — instalação no servidor (Debian/Linux)

Plano e razões em `docs/BACKUPS.md`. Aqui ficam os passos, **por ordem**, a correr no
servidor, na pasta do Gookie (ex.: `/opt/gookie`). Decisões tomadas: destino **Google
Drive**, cifra **rclone crypt** (a chave fica com o Mauro), retenção **30 diários + 12
mensais**, cópia semanal para **USB cifrado (LUKS)**.

## 0. O que já funciona sem fazer nada

A migration `1707609600_backups_cron.js` liga o backup automático do PocketBase:
**todas as noites às 03:00 (UTC)**, guarda os **7** mais recentes em `data/backups/`.
Confirmar: painel `/_/` → Definições → Backups.

## 1. Instalar o rclone (uma vez)

```bash
curl -fsSL https://rclone.org/install.sh | sudo bash     # versão atual (a do apt costuma ser antiga)
rclone version
```

## 2. Ligar ao Google Drive

```bash
rclone config
```

1. `n` (novo remoto) → nome: **`gdrive`** → storage: **`drive`**
2. `client_id` e `client_secret`: vazios (Enter)
3. `scope`: **`3` — drive.file** (só ficheiros criados pelo rclone: não vê nem apaga mais nada da conta)
4. Restantes: Enter. "Use web browser to automatically authenticate?" → **n** (o servidor não tem
   browser): o rclone dá um comando `rclone authorize "drive" "..."` para correr **no teu PC**
   (que tenha rclone), e pede o resultado de volta. Faz login na conta Google **da empresa**.
5. "Configure as Shared Drive?" → n. Confirmar e sair.

> O Google Drive gratuito tem 15 GB **partilhados** com o Gmail dessa conta (ver o cálculo no fim).

## 3. Criar o remoto cifrado (a parte crítica)

Na mesma `rclone config`:

1. `n` → nome: **`gookie-crypt`** → storage: **`crypt`**
2. `remote`: **`gdrive:GookieBackups`**
3. `filename_encryption`: **standard** · `directory_name_encryption`: **true**
4. Password: **g** (gerar) com **1024 bits** → o rclone **mostra a password** → **copiar já**
5. Password2 (o "sal"): **g** de novo → **copiar também**

**Guardar a password e o sal AGORA** (só aparecem nesta altura): no gestor de palavras-passe
e numa folha impressa num sítio seguro. **Sem elas os backups não se abrem — nem por nós, nem
pela Google.** Guardar também uma cópia do `rclone.conf` (`rclone config file` diz onde
está): tem o acesso ao Drive **e** as chaves. Nunca no Git nem no mesmo disco dos backups.

## 4. Testar a ligação

```bash
echo teste > /tmp/t.txt
rclone copy /tmp/t.txt gookie-crypt:teste
rclone lsf gookie-crypt:teste           # mostra t.txt
```

No Google Drive a pasta `GookieBackups` deve mostrar **nomes ilegíveis** (prova de que está
cifrado). Apagar depois: `rclone purge gookie-crypt:teste`.

## 5. Primeira cópia à mão

Criar um backup já: painel `/_/` → Definições → Backups → **Initialize backup** (ou esperar
pelas 03:00). Depois:

```bash
bash backup/copia-externa.sh
```

Tem de terminar com `Concluído.` (registos em `backup/logs/copia-externa.log`).

## 6. Agendar a cópia noturna

```bash
sudo bash backup/instalar-agendamento.sh          # todos os dias às 03:30
sudo systemctl start gookie-backup.service         # testar já
journalctl -u gookie-backup -n 20
systemctl list-timers gookie-backup*
```

Corre com o teu utilizador (é onde está o `rclone.conf`).

## 7. Alerta por email se falhar (recomendado)

No `.env` acrescentar (ver `.env.example`): `BACKUP_ALERT_TO`, `BACKUP_SMTP_HOST`,
`BACKUP_SMTP_PORT`, `BACKUP_SMTP_USER`, `BACKUP_SMTP_PASS` (no Gmail, uma "palavra-passe de
aplicação"). Sem isto a falha só fica no registo e em `systemctl status gookie-backup`.

## 8. USB semanal (cifrado com LUKS)

Uma vez (**apaga o USB!** confirmar o dispositivo com `lsblk`, aqui `/dev/sdX1`):

```bash
sudo cryptsetup luksFormat /dev/sdX1              # escolher uma palavra-passe forte (guardá-la no cofre)
sudo cryptsetup open /dev/sdX1 gookieusb
sudo mkfs.ext4 -L GOOKIEUSB /dev/mapper/gookieusb
sudo cryptsetup close gookieusb
```

Todos os domingos:

```bash
sudo cryptsetup open /dev/sdX1 gookieusb
sudo mkdir -p /mnt/gookie-usb && sudo mount /dev/mapper/gookieusb /mnt/gookie-usb
sudo bash backup/copia-usb.sh /mnt/gookie-usb
sudo umount /mnt/gookie-usb && sudo cryptsetup close gookieusb
```

Retirar o USB e guardá-lo **fora do servidor**. Mantém as últimas 12 cópias e o `.env`.

## 9. Teste de restauro (todos os meses)

```bash
bash backup/teste-restauro.sh                               # a partir da nuvem (decifra)
bash backup/teste-restauro.sh /mnt/gookie-usb/GookieBackups  # a partir do USB
```

Tem de acabar com `RESTAURO OK`. Não toca na produção (contentor descartável na porta 18090).
Anotar a data e o tempo.

## Restauro a sério (desastre) ou mudança de máquina

1. `rclone copy gookie-crypt:diario/<ficheiro>.zip .` (decifra) — ou copiar do USB.
2. Na pasta do Gookie: `bash gookie.sh restaurar <ficheiro>.zip` (guarda os dados atuais em
   `data.antes-…` e põe os do backup).
3. Repor o `.env` (do cofre/USB) **antes** de arrancar, se for uma máquina nova.
4. Entrar e conferir vendas/produções recentes e as imagens.

## Quanto espaço é preciso

**Uma cópia = 1 ficheiro `.zip` de tudo** (base de dados + imagens/PDFs). Com a app em uso serão
dezenas a centenas de MB (as fotos de faturas são o que mais pesa).

| Onde | Cópias | Conta | Espaço |
|---|---|---|---|
| Google Drive | 30 diárias + 12 mensais = **42** | 42 × tamanho | 15 GB chegam enquanto cada cópia tiver **< 350 MB** |
| USB | **12** semanais + `.env` | 12 × tamanho | Uma cópia de 500 MB → 6 GB |

**USB: 32 GB chegam**; recomendo **64 GB** (ou um disco externo pequeno). Se as cópias passarem
os 350 MB: Google One (100 GB, ≈ 2 €/mês) ou Backblaze B2 — o `REMOTE` dos scripts é só o nome
do remoto rclone, por isso a migração é trocar o destino.
