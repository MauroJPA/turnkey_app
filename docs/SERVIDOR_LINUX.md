# Instalar a Gookie no servidor (Debian + Docker + Tailscale)

A Gookie corre num **contentor próprio** (`gookie`): um PocketBase **novo e separado**, com a sua
própria base de dados — **não mexe** no PocketBase nem nas outras aplicações que já lá tens
(Immich, Portainer…). Serve a **app web** e a **API** na mesma porta (só em `127.0.0.1`); o
**Tailscale** dá o HTTPS. Pacote: `gookie-servidor-<versão>.tar.gz`.

> Tudo o que interessa fica em **`data/`** (base de dados e ficheiros) e **`.env`** (segredos):
> para mudar de máquina — ou para a nuvem — levas essas duas coisas (ver o passo 11).

## 0. Antes de começar

```bash
docker --version && docker compose version        # tem de existir (o Portainer já implica Docker)
ss -ltn | grep -E ':80[0-9][0-9] '                 # portas 80xx já ocupadas (a Gookie escolhe uma livre a partir da 8091)
tailscale status && tailscale serve status         # o que o Tailscale já expõe (para não chocar nas portas)
df -h /opt                                         # pelo menos 5 GB livres (mais depois, com as fotos das faturas)
```

- [ ] Docker + plugin *compose* instalados; o teu utilizador consegue correr `docker ps` (ou usa `sudo`).
- [ ] O servidor liga sozinho quando volta a luz (BIOS) e, se possível, tem **UPS**.
- [ ] Atualizações automáticas de segurança: `sudo apt install unattended-upgrades`.

## 1. Copiar e descompactar o pacote

No PC de desenvolvimento (o `scripts\empacotar-producao.ps1` mostra o SHA-256):

```bash
scp gookie-servidor-1.6.1.tar.gz utilizador@ip-do-servidor:/tmp/
```

No servidor:

```bash
sha256sum /tmp/gookie-servidor-1.6.1.tar.gz          # tem de coincidir com o do script
sudo mkdir -p /opt/gookie && sudo chown "$USER": /opt/gookie
tar -xzf /tmp/gookie-servidor-1.6.1.tar.gz -C /opt/gookie
cd /opt/gookie
```

## 2. Instalar (dados limpos)

```bash
bash gookie.sh instalar
```

Faz tudo: cria `.env`, **gera a chave de cifra** `TURNKEY_ENC_KEY` (não a mostra), escolhe uma **porta
local livre** (8091 ou a seguinte), constrói a imagem, arranca e espera pelo servidor
(1.ª vez: ~1 min a aplicar as migrations).

- [ ] **Abrir `.env`, copiar a linha `TURNKEY_ENC_KEY=…` para o gestor de palavras-passe** (fora do servidor).
- [ ] Preencher `GEMINI_API_KEY=` no `.env` (faturas por IA) e `bash gookie.sh reiniciar`.
- [ ] `bash gookie.sh estado` → contentor `healthy` e `{"code":200…}`.
- [ ] No Portainer aparece o *stack* `gookie` (só para ver; gere-se por `gookie.sh`).

## 3. Superutilizador (só tu)

```bash
bash gookie.sh superutilizador o-teu-email@exemplo.pt
```

Pede a palavra-passe (10+ caracteres, longa e única — no gestor de palavras-passe). É com esta conta
que entras no painel `/_/` e **aprovas registos**.

## 4. Tailscale: HTTPS para a equipa

No painel do Tailscale (login.tailscale.com → *DNS*) confirma **MagicDNS** e **HTTPS Certificates**
ligados. Depois, no servidor (troca `8091` pela porta que o `gookie.sh` escolheu — `grep GOOKIE_PORTA .env`
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
- [ ] Na app: "Verificar novamente" → **criar a empresa** (Gookie). Fica proprietário.
- [ ] Configurações → **Integrações** → guardar o **token do Vendus** (o novo, não o exposto).
- [ ] **Equipa** (utilizadores e papéis) e **Navegação e permissões**.
- [ ] Carregar ingredientes, receitas, fichas, formatos; **Produtos Gookie**: descrição, validade,
      conservação e o **produtor** (nome e morada) para as etiquetas.

## 6. Backups (antes de usar a sério!)

- [ ] Seguir `backup/LEIA-ME.md` (rclone + Google Drive cifrado + timer + USB com LUKS).
- [ ] O PocketBase já faz backup local todas as noites (03:00 UTC, 7 mais recentes em `data/backups/`).
- [ ] Guardar **fora do servidor**: a `TURNKEY_ENC_KEY`, a password e o sal do rclone, a palavra-passe do
      superutilizador e a do LUKS.
- [ ] **Primeiro restauro de teste:** `bash backup/teste-restauro.sh` → `RESTAURO OK` (anotar o tempo).
- [ ] Antes de mexer em algo grande: `bash gookie.sh backup-agora`.

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
bash gookie.sh estado          # contentor e /api/health
bash gookie.sh logs            # registos em direto (Ctrl+C sai)
bash gookie.sh reiniciar
docker stats --no-stream gookie
```

- Registos novos por aprovar: `/_/` → users → filtro `aprovado = false`.
- Verificar de vez em quando: espaço livre (`df -h`), que o último backup na Google Drive tem a data de
  ontem (`rclone lsf gookie-crypt:diario | tail -n2`) e o estado do timer (`systemctl list-timers gookie-backup*`).
- Combinar **quem é avisado** se a app parar (a equipa avisa; ou o alerta por email dos backups).

## 9. Atualizar a app (novo pacote)

```bash
cd /opt/gookie
bash gookie.sh backup-agora                                  # cópia antes de mexer
rm -rf web hooks migrations                                # tira os ficheiros antigos da app (data/ e .env ficam)
tar -xzf /tmp/gookie-servidor-NOVO.tar.gz -C /opt/gookie     # o pacote não traz data/ nem .env
bash gookie.sh atualizar                                     # reconstrói a imagem e reinicia (migrations aplicam-se sozinhas)
bash gookie.sh estado
```

Depois, o ensaio rápido: login, uma produção, uma venda. Para atualizar só o PocketBase: mudar
`PB_VERSION` no `.env` e `bash gookie.sh atualizar` (testa antes em cópia — ver `docs/SEGURANCA.md`).

## 10. Se correr mal (retrocesso)

1. `bash gookie.sh parar`.
2. `bash gookie.sh restaurar backups-manuais/gookie-dados-…tar.gz` (ou um `.zip` de `data/backups`).
3. Voltar a extrair o pacote **anterior** por cima e `bash gookie.sh atualizar`.

## 11. Mudar para outra máquina (por exemplo, a nuvem)

A imagem constrói-se sozinha em `amd64` e `arm64`, por isso qualquer Linux com Docker serve.

1. Na máquina antiga: `bash gookie.sh backup-agora` → `backups-manuais/gookie-dados-….tar.gz`.
2. Copiar para a nova: esse ficheiro **e** o `.env` (`scp`, com cuidado: tem os segredos) **e** o pacote da app.
3. Na nova: instalar Docker, extrair o pacote em `/opt/gookie`, pôr o `.env` no lugar e correr
   `bash gookie.sh restaurar gookie-dados-….tar.gz` (o `.env` tem de ter a **mesma** `TURNKEY_ENC_KEY`).
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
