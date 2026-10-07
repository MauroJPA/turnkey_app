# Instalar o gc_turnkey no servidor (Debian + Docker + Tailscale)

O gc_turnkey corre num **contentor próprio** (`gc_turnkey`): um PocketBase **novo e separado**, com a sua
própria base de dados — **não mexe** no PocketBase nem nas outras aplicações que já lá tens
(Immich, Portainer…). Serve a **app web** e a **API** na mesma porta (só em `127.0.0.1`); o
**Tailscale** dá o HTTPS. Pacote: `gc_turnkey-servidor-<versão>.tar.gz`.

> Tudo o que interessa fica em **`data/`** (base de dados e ficheiros) e **`.env`** (segredos):
> para mudar de máquina — ou para a nuvem — levas essas duas coisas (ver o passo 11).

> **Depois de instalado:** liga o **vigia de segurança** (um alarme que procura sinais de invasão de
> 10 em 10 minutos e avisa pela app/Telegram) — ver a secção "Vigia de segurança" no fim deste documento.

## 0. Antes de começar

```bash
docker --version && docker compose version        # tem de existir (o Portainer já implica Docker)
ss -ltn | grep -E ':80[0-9][0-9] '                 # portas 80xx já ocupadas (o instalador escolhe uma livre a partir da 8091)
tailscale status && tailscale serve status         # o que o Tailscale já expõe (para não chocar nas portas)
df -h /opt                                         # pelo menos 5 GB livres (mais depois, com as fotos das faturas)
```

- [ ] Docker + plugin *compose* instalados; o teu utilizador consegue correr `docker ps` (ou usa `sudo`).
- [ ] O servidor liga sozinho quando volta a luz (BIOS) e, se possível, tem **UPS**.
- [ ] Atualizações automáticas de segurança: `sudo apt install unattended-upgrades`.

## 1. Copiar e descompactar o pacote

No PC de desenvolvimento (o `scripts\empacotar-producao.ps1` mostra o SHA-256):

```bash
scp gc_turnkey-servidor-1.6.1.tar.gz utilizador@ip-do-servidor:/tmp/
```

No servidor:

```bash
sha256sum /tmp/gc_turnkey-servidor-1.6.1.tar.gz          # tem de coincidir com o do script
sudo mkdir -p /opt/gc_turnkey && sudo chown "$USER": /opt/gc_turnkey
tar -xzf /tmp/gc_turnkey-servidor-1.6.1.tar.gz -C /opt/gc_turnkey
cd /opt/gc_turnkey
```

## 2. Instalar (dados limpos)

```bash
bash gc_turnkey.sh instalar
```

Faz tudo: cria `.env`, **gera a chave de cifra** `GC_TURNKEY_ENC_KEY` (não a mostra), escolhe uma **porta
local livre** (8091 ou a seguinte), constrói a imagem, arranca e espera pelo servidor
(1.ª vez: ~1 min a aplicar as migrations).

- [ ] **Abrir `.env`, copiar a linha `GC_TURNKEY_ENC_KEY=…` para o gestor de palavras-passe** (fora do servidor).
- [ ] Preencher `GEMINI_API_KEY=` no `.env` (faturas por IA) e `bash gc_turnkey.sh reiniciar`.
- [ ] `bash gc_turnkey.sh estado` → contentor `healthy` e `{"code":200…}`.
- [ ] No Portainer aparece o *stack* `gc_turnkey` (só para ver; gere-se por `gc_turnkey.sh`).

## 3. Superutilizador (só tu)

```bash
bash gc_turnkey.sh superutilizador o-teu-email@exemplo.pt
```

Pede a palavra-passe (10+ caracteres, longa e única — no gestor de palavras-passe). É com esta conta
que entras no painel `/_/` e **aprovas registos**.

## 4. Tailscale: HTTPS para a equipa

No painel do Tailscale (login.tailscale.com → *DNS*) confirma **MagicDNS** e **HTTPS Certificates**
ligados. Depois, no servidor (troca `8091` pela porta que o `gc_turnkey.sh` escolheu — `grep GC_TURNKEY_PORTA .env`
— e a `8444` por uma porta HTTPS livre no Tailscale, ver `tailscale serve status`):

```bash
sudo tailscale serve --bg --https=8444 http://127.0.0.1:8091
tailscale serve status
```

A app fica em **`https://<nome-do-servidor>.<a-tua-rede>.ts.net:8444`**. Cada telemóvel/PC precisa da
app Tailscale ligada à mesma rede (o Tailscale é a "porta" — fora dele ninguém chega).

- [ ] Abrir esse endereço num telemóvel **com** Tailscale → ecrã de login. **Sem** Tailscale (dados
      móveis) → não abre.
- [ ] Definir as **ACL** do Tailscale para que só as pessoas/dispositivos certos vejam este servidor.
- [ ] Painel `/_/` → **Definições → Application**: pôr o **Application URL** (o endereço acima) e, em
      **Trusted proxy headers**, `X-Forwarded-For` (senão o limite de tentativas de login trata toda a
      gente como um só utilizador). Confirmar **Rate limiting** ligado.

Para retirar: `sudo tailscale serve --https=8444 off`.

## 5. Criar a empresa real (na app)

- [ ] Abrir o endereço → **Não tenho conta → criar** → ver "A tua conta aguarda aprovação".
- [ ] `/_/` (superutilizador) → **users** → marcar **aprovado** nessa conta.
- [ ] Na app: "Verificar novamente" → **criar a tua empresa** (ex.: Gookie Cookies). Fica proprietário.
- [ ] Configurações → **Integrações** → guardar o **token do Vendus** (o novo, não o exposto).
- [ ] **Equipa** (utilizadores e papéis) e **Navegação e permissões**.
- [ ] Carregar ingredientes, receitas, fichas, formatos; **Produtos**: descrição, validade,
      conservação e o **produtor** (nome e morada) para as etiquetas.

## 6. Backups (antes de usar a sério!)

- [ ] Seguir `backup/LEIA-ME.md` (rclone + Google Drive cifrado + timer + USB com LUKS).
- [ ] O PocketBase já faz backup local todas as noites (03:00 UTC, 7 mais recentes em `data/backups/`).
- [ ] Guardar **fora do servidor**: a `GC_TURNKEY_ENC_KEY`, a password e o sal do rclone, a palavra-passe do
      superutilizador e a do LUKS.
- [ ] **Primeiro restauro de teste:** `bash backup/teste-restauro.sh` → `RESTAURO OK` (anotar o tempo).
- [ ] Antes de mexer em algo grande: `bash gc_turnkey.sh backup-agora`.

## 7. Ensaio de aceitação (antes de a equipa usar)

- [ ] Login/logout; palavra-passe errada recusada; conta nova fica por aprovar.
- [ ] **Comprar → produzir → stock → vender** com dados reais (uma produção completa).
- [ ] Fatura por foto (IA) e por PDF; abrir o ficheiro da fatura.
- [ ] Sincronizar com o Vendus (dados reais).
- [ ] **Imprimir** uma etiqueta (impressora térmica real) e um talão.
- [ ] `sudo reboot` no servidor → passado ~2 min a app volta sozinha (`restart: unless-stopped`).
- [ ] Do telemóvel **sem** Tailscale: a app não abre.
- [ ] Papel Leitura não consegue editar.

## 8. Dia a dia

```bash
bash gc_turnkey.sh estado          # contentor e /api/health
bash gc_turnkey.sh logs            # registos em direto (Ctrl+C sai)
bash gc_turnkey.sh reiniciar
docker stats --no-stream gc_turnkey
```

- Registos novos por aprovar: `/_/` → users → filtro `aprovado = false`.
- Verificar de vez em quando: espaço livre (`df -h`), que o último backup na Google Drive tem a data de
  ontem (`rclone lsf gc_turnkey-crypt:diario | tail -n2`) e o estado do timer (`systemctl list-timers gc_turnkey-backup*`).
- Combinar **quem é avisado** se a app parar (a equipa avisa; ou o alerta por email dos backups).

## 9. Atualizar a app (novo pacote)

### Automático (recomendado) — `scripts/publicar-producao.sh`

Corre **na tua máquina** (nunca no servidor), dentro da pasta do projeto. Envia o pacote por `scp`,
confirma o SHA-256 já no servidor (aborta sem mexer em nada se não bater certo) e depois faz sozinho o
backup, a extração e a atualização:

```bash
bash scripts/publicar-producao.sh <pacote.tar.gz> <utilizador@servidor> [pasta-no-servidor] [porta-ssh]
```

Exemplo real:

```bash
bash scripts/publicar-producao.sh dist/gc_turnkey-servidor-1.27.0.tar.gz virusserver@192.168.1.151 /opt/gc_turnkey 2022
```

`pasta-no-servidor` por omissão é `/opt/gc_turnkey`; `porta-ssh` por omissão é `22`.

No **PowerShell do Windows** (onde `bash` não é reconhecido diretamente), chama o Git Bash pelo caminho
completo:

```powershell
& "C:\Program Files\Git\bin\bash.exe" scripts/publicar-producao.sh <pacote.tar.gz> <utilizador@servidor> [pasta-no-servidor] [porta-ssh]
```

### Manual (passo a passo, para perceber o que o script faz por dentro)

```bash
cd /opt/gc_turnkey
bash gc_turnkey.sh backup-agora                                  # cópia antes de mexer
rm -rf web hooks migrations                                # tira os ficheiros antigos da app (data/ e .env ficam)
tar -xzf /tmp/gc_turnkey-servidor-NOVO.tar.gz -C /opt/gc_turnkey     # o pacote não traz data/ nem .env
bash gc_turnkey.sh atualizar                                     # reconstrói a imagem e reinicia (migrations aplicam-se sozinhas)
bash gc_turnkey.sh estado
```

Se o `backup-agora` falhar (mensagem "A cópia de segurança FALHOU"), a atualização pára **sem mexer na app**
e o servidor volta a arrancar sozinho (v1.48.1+; em versões anteriores ficava parado: `bash gc_turnkey.sh iniciar`).
Se o disco do servidor for pequeno e houver outro maior (ex.: `/home`), guarda lá os backups manuais:
`mkdir -p /home/UTILIZADOR/gc_turnkey-backups && mv backups-manuais/* /home/UTILIZADOR/gc_turnkey-backups/ &&
rmdir backups-manuais && ln -s /home/UTILIZADOR/gc_turnkey-backups backups-manuais`.
Cada backup manual (`backups-manuais/`) tem o tamanho dos dados; desde a v1.48.2 o `backup-agora` verifica o
espaço antes de parar o servidor e guarda só os últimos 5 (`GC_TURNKEY_BACKUPS_MANTER=N` no `.env` muda o número).
Causas habituais: disco cheio (`df -h .`) ou ficheiros de `data/` que o teu utilizador não consegue ler
(`ls -la data | head`; corrige o dono com `sudo chown -R "$USER" data`, ou corre o backup com `sudo`).

Depois, o ensaio rápido: login, uma produção, uma venda. Para atualizar só o PocketBase: mudar
`PB_VERSION` no `.env` e `bash gc_turnkey.sh atualizar` (testa antes em cópia — ver `docs/SEGURANCA.md`).

## 9b. Atualizar da 1.6.x (instalação antiga chamada `gookie`)

Só uma vez, para passar ao nome **gc_turnkey**. Os dados (`data/`) e o `.env` mantêm-se; muda o nome do
contentor, do script, das variáveis do `.env` (migradas sozinhas) e do remoto rclone.

```bash
cd /opt/gookie
bash gookie.sh backup-agora                                   # cópia por segurança (script antigo)
bash gookie.sh parar
cd /opt && sudo mv gookie gc_turnkey && cd gc_turnkey         # (opcional: renomear a pasta)
rm -rf web hooks migrations gookie.sh
tar -xzf /tmp/gc_turnkey-servidor-1.7.0.tar.gz -C /opt/gc_turnkey
bash gc_turnkey.sh atualizar          # migra o .env, remove o contentor antigo, reconstrói e arranca
bash gc_turnkey.sh estado
```

Depois:
- **Timer dos backups:** `sudo bash backup/instalar-agendamento.sh` (troca `gookie-backup` por `gc_turnkey-backup`).
- **Remoto rclone:** `rclone config` → `r` (Rename remote): `gookie-crypt` → `gc_turnkey-crypt`. (O remoto `b2gookie`
  e a pasta no bucket podem ficar como estão; só o nome do remoto cifrado é usado pelos scripts.)
- **Painel do PocketBase** (`/_/` → Settings → Application): confirma o *Application name* `gc_turnkey`.
- Se a app pedir para voltar a entrar, é normal (o browser guarda a app antiga em cache): recarrega a página.
- Se o aviso "Há uma versão nova" ficar e o botão "Atualizar" não resolver (versões até à 1.77.0), faz **Ctrl+Shift+R** (computador) uma vez; a partir da 1.78.0 o botão atualiza sozinho.

**Atualizar para a 1.8.0 (faturas com vários documentos por PDF):** a imagem Docker passou a incluir o `qpdf`
(para cortar PDFs). Segue o mesmo procedimento de atualização acima (`gc_turnkey.sh atualizar` reconstrói a imagem).
Depois confirma: `docker exec gc_turnkey qpdf --version`. Se a IA estiver sobrecarregada, o servidor repete e usa os
modelos de reserva do `.env`.

## 10. Se correr mal (retrocesso)

1. `bash gc_turnkey.sh parar`.
2. `bash gc_turnkey.sh restaurar backups-manuais/gc_turnkey-dados-…tar.gz` (ou um `.zip` de `data/backups`).
3. Voltar a extrair o pacote **anterior** por cima e `bash gc_turnkey.sh atualizar`.

## 11. Mudar para outra máquina (por exemplo, a nuvem)

A imagem constrói-se sozinha em `amd64` e `arm64`, por isso qualquer Linux com Docker serve.

1. Na máquina antiga: `bash gc_turnkey.sh backup-agora` → `backups-manuais/gc_turnkey-dados-….tar.gz`.
2. Copiar para a nova: esse ficheiro **e** o `.env` (`scp`, com cuidado: tem os segredos) **e** o pacote da app.
3. Na nova: instalar Docker, extrair o pacote em `/opt/gc_turnkey`, pôr o `.env` no lugar e correr
   `bash gc_turnkey.sh restaurar gc_turnkey-dados-….tar.gz` (o `.env` tem de ter a **mesma** `GC_TURNKEY_ENC_KEY`).
4. Acesso: **Tailscale** também na nuvem (mesmo passo 4) — ou, se for público, um proxy com HTTPS
   automático (ex.: Caddy) à frente de `127.0.0.1:8091`, **bloqueando `/_/`** ao público:
   ```
   app.teudominio.pt {
       @admin path /_/*
       respond @admin 404
       reverse_proxy 127.0.0.1:8091
   }
   ```
   (com proxy público, pôr `X-Forwarded-For` nos *Trusted proxy headers* e abrir só as portas 80/443/22
   na *firewall* da nuvem; manter o SSH só por chave).
5. Backups na nova máquina: repetir `backup/LEIA-ME.md` (o rclone.conf tem de ir para lá ou voltar a configurar-se).
6. Ensaio (passo 7) e só depois desligar o servidor antigo.

## Vigia de segurança (recomendado)

Um script que corre **de 10 em 10 minutos** e procura sinais de invasão: entradas SSH estranhas, chaves e
tarefas novas, mineradores, aparelhos novos no Tailscale, ficheiros da app alterados sem atualização,
atualizações de segurança em atraso… **Só lê** (não altera nada). Avisa na app (Início e Configurações →
Segurança e backups) e, se tiveres o Telegram/email ligados, também por aí.

```bash
cd /opt/gc_turnkey
sudo bash seguranca/instalar-vigia.sh        # instala o timer e faz a 1.ª ronda (aprende o que é normal)
sudo python3 seguranca/vigia.py estado       # ver o último resultado
```

- [ ] Instalar **num servidor que sabes estar limpo** (o que existir hoje fica como "normal").
- [ ] Na app, **Configurações → Segurança e backups → Vigia do servidor** mostra "Tudo calmo".
- [ ] Depois de uma mudança tua (nova chave SSH, novo contentor…), carregar em **"Já verifiquei"**.
- Detalhes, lista do que vigia e limites: `seguranca/LEIA-ME.md`.
