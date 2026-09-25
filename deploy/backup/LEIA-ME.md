# Backups — instalação no servidor (Debian/Linux)

Plano e razões em `docs/BACKUPS.md`. Aqui ficam os passos, **por ordem**, a correr no
servidor, na pasta do gc_turnkey (ex.: `/opt/gc_turnkey`). Decisões tomadas: destino **Google
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

1. `n` → nome: **`gc_turnkey-crypt`** → storage: **`crypt`**
2. `remote`: **`gdrive:gc_turnkey_backups`**
3. `filename_encryption`: **standard** · `directory_name_encryption`: **true**
4. Password: **g** (gerar) com **1024 bits** → o rclone **mostra a password** → **copiar já**
5. Password2 (o "sal"): **g** de novo → **copiar também**

**Guardar a password e o sal AGORA** (só aparecem nesta altura): no gestor de palavras-passe
e numa folha impressa num sítio seguro. **Sem elas os backups não se abrem — nem por nós, nem
pela Google.** Guardar também uma cópia do `rclone.conf` (`rclone config file` diz onde
está): tem o acesso ao Drive **e** as chaves. Nunca no Git nem no mesmo disco dos backups.

## 2b. Alternativa: Backblaze B2 em vez do Google Drive (mais simples)

Sem projeto Google, sem ecrã de consentimento e sem expiração de autorização. Grátis até **10 GB**
(depois cerca de 6 US$/TB por mês; confirmar em backblaze.com/cloud-storage/pricing).

1. Criar conta em backblaze.com (B2 Cloud Storage), escolhendo a região **EU Central (Amsterdão)**
   (a região não se muda depois).
2. *Buckets → Create a Bucket*: nome único (ex.: `gc_turnkey-backups-xxxx`), **Private**.
3. Nas definições do bucket, **Lifecycle Settings → Keep only the last version of the file**
   (senão os ficheiros "apagados" ficam escondidos e continuam a ocupar espaço).
4. *Application Keys → Add a New Application Key*: nome `gc_turnkey-rclone`, acesso **só a esse bucket**,
   Read and Write. Copiar o **keyID** e a **applicationKey** (só aparece uma vez).
5. No servidor: `rclone config` → `n` → nome **`b2-gc_turnkey`** → storage **`b2`** → `account` = keyID,
   `key` = applicationKey, **`hard_delete` = true**, avançadas = n.
6. Passo 3 abaixo, mas com `remote` = **`b2-gc_turnkey:NOME-DO-BUCKET/gc_turnkey_backups`** (em vez de `gdrive:…`).

Limites do plano gratuito: 10 GB guardados, 1 GB/dia de descarga (o teste de restauro mensal cabe),
2 500 operações "B" e 2 500 "C" por dia. Com 42 cópias, cada uma tem de ter **< ~240 MB** para
ficar grátis; para ficar dentro do gratuito por mais tempo, baixar `DIAS_DIARIOS` (ex.: 14).

## 4. Testar a ligação

```bash
echo teste > /tmp/t.txt
rclone copy /tmp/t.txt gc_turnkey-crypt:teste
rclone lsf gc_turnkey-crypt:teste           # mostra t.txt
```

No Google Drive a pasta `gc_turnkey_backups` deve mostrar **nomes ilegíveis** (prova de que está
cifrado). Apagar depois: `rclone purge gc_turnkey-crypt:teste`.

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
sudo systemctl start gc_turnkey-backup.service         # testar já
journalctl -u gc_turnkey-backup -n 20
systemctl list-timers gc_turnkey-backup*
```

Corre com o teu utilizador (é onde está o `rclone.conf`).

## 7. Alerta por email se falhar (recomendado)

No `.env` acrescentar (ver `.env.example`): `BACKUP_ALERT_TO`, `BACKUP_SMTP_HOST`,
`BACKUP_SMTP_PORT`, `BACKUP_SMTP_USER`, `BACKUP_SMTP_PASS` (no Gmail, uma "palavra-passe de
aplicação"). Sem isto a falha só fica no registo e em `systemctl status gc_turnkey-backup`.

## 8. USB semanal (cifrado com LUKS)

Uma vez (**apaga o USB!** confirmar o dispositivo com `lsblk`, aqui `/dev/sdX1`):

```bash
sudo cryptsetup luksFormat /dev/sdX1              # escolher uma palavra-passe forte (guardá-la no cofre)
sudo cryptsetup open /dev/sdX1 gcturnkeyusb
sudo mkfs.ext4 -L GCTURNKEYUSB /dev/mapper/gcturnkeyusb
sudo cryptsetup close gcturnkeyusb
```

Todos os domingos:

```bash
sudo cryptsetup open /dev/sdX1 gcturnkeyusb
sudo mkdir -p /mnt/gc_turnkey-usb && sudo mount /dev/mapper/gcturnkeyusb /mnt/gc_turnkey-usb
sudo bash backup/copia-usb.sh /mnt/gc_turnkey-usb
sudo umount /mnt/gc_turnkey-usb && sudo cryptsetup close gcturnkeyusb
```

Retirar o USB e guardá-lo **fora do servidor**. Mantém as últimas 12 cópias e o `.env`.

## 9. Teste de restauro (todos os meses)

```bash
bash backup/teste-restauro.sh                               # a partir da nuvem (decifra)
bash backup/teste-restauro.sh /mnt/gc_turnkey-usb/gc_turnkey_backups  # a partir do USB
```

Tem de acabar com `RESTAURO OK`. Não toca na produção (contentor descartável na porta 18090).
Anotar a data e o tempo.

## Restauro a sério (desastre) ou mudança de máquina

1. `rclone copy gc_turnkey-crypt:diario/<ficheiro>.zip .` (decifra) — ou copiar do USB.
2. Na pasta do gc_turnkey: `bash gc_turnkey.sh restaurar <ficheiro>.zip` (guarda os dados atuais em
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
