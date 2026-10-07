# Vigia de segurança do servidor

Um script que corre **de 10 em 10 minutos** no servidor e procura sinais de invasão ou de descuido.
**Só lê**: não altera o sistema, não bloqueia ninguém, não envia dados para fora (o único envio é o
aviso, por Telegram/email). O resultado aparece na app (**Configurações → Segurança e backups**) e no
**Início** quando há algo a pedir atenção.

## Instalar (uma vez, no servidor)

```bash
cd /opt/gc_turnkey
sudo bash seguranca/instalar-vigia.sh
```

Precisa só de `python3` (o Debian já traz). A primeira ronda **aprende o que é normal** neste servidor,
por isso instala-o num servidor que sabes estar limpo.

## O que vigia

| Área | O que procura |
|---|---|
| **Acesso SSH** | entradas vindas da internet pública; muitas tentativas falhadas (força bruta) **seguidas de uma entrada**; entradas de um IP/aparelho novo, ou a uma hora a que nunca entras; entradas como `root` |
| **Contas** | utilizadores novos; quem ganhou `sudo`/`docker`; 2.º utilizador root; contas sem palavra-passe; alterações ao `sudoers` |
| **Persistência** (como um intruso volta a entrar) | chaves SSH novas; tarefas `cron` e serviços `systemd` novos ou alterados; comandos típicos de ataque (`curl … \| sh`, `base64 -d`, `/dev/tcp`, `nc -e`); `/etc/ld.so.preload`; `.bashrc` alterado |
| **Rede** | portas novas à escuta; contentores Docker novos ou com portas abertas a toda a rede; **aparelhos novos na rede Tailscale**; ligações a pools de mineração |
| **Processos** | mineradores de criptomoedas (xmrig, kinsing…); programas a correr de `/tmp` ou `/dev/shm`; um processo a 90 % do CPU durante mais de 1 hora; programas setuid novos |
| **A app** | ficheiros da app (hooks, migrations, web, scripts) **alterados sem haver uma atualização**; novo superutilizador do PocketBase; mudanças nos proprietários/administradores; rajadas de falhas de login e pedidos "à procura de falhas" nos registos da app; `.env` legível por todos |
| **Higiene** | atualizações de segurança por instalar há mais de 7 dias; reinício pendente; disco cheio; serviços do gc_turnkey que falharam |

## Como é "inteligente"

- **Aprende o normal**: quem entra e de onde, que portas e contentores existem, que chaves e tarefas há…
  e só avisa do que **muda**. Com "Já verifiquei" ensinas-lhe o que foi legítimo e ele não volta a avisar.
- **Liga os pontos**: uma chave SSH nova **mais** um acesso novo, ou um minerador **mais** uma tarefa
  nova, sobem para **"POSSÍVEL INTRUSÃO"** com o que fazer primeiro.
- **Explica em português** o que significa cada alerta e o que fazer.
- **Percebe atualizações**: quando atualizas a app (a versão muda) ele reaprende os ficheiros; se algo
  muda **sem** versão nova, é alerta crítico.

## Avisos

- **Na app**: Início ("Precisa de ti") e Configurações → Segurança e backups.
- **Telegram/email**: a app avisa **uma vez** de cada alerta novo (crítico ou de atenção) pelos canais
  de Configurações → Avisos, e inclui-os no resumo diário. Também avisa se o próprio vigia parar.
- **Aviso direto** (opcional, mesmo com a app em baixo): põe `TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID`
  em `/etc/gc_turnkey-vigia.conf`.

## Quando recebes um alerta

1. Lê o texto: diz o que é e **o que fazer**.
2. Se foi uma mudança tua (nova chave, novo contentor, atualização feita à mão): **"Já verifiquei"**.
3. Se **não** reconheces: segue o "O que fazer". Num **"Possível intrusão"**: muda já as palavras-passe e
   chaves SSH, remove o acesso suspeito (chave, utilizador, aparelho Tailscale) e, na dúvida, restaura
   de um backup limpo (`docs/BACKUPS.md`).

## Comandos úteis

```bash
sudo python3 seguranca/vigia.py estado            # último resultado
sudo python3 seguranca/vigia.py --tudo            # correr já todas as verificações
sudo python3 seguranca/vigia.py aceitar           # "o estado atual é o normal" (reaprende tudo)
systemctl list-timers gc_turnkey-vigia
journalctl -u gc_turnkey-vigia -n 30
sudo bash seguranca/instalar-vigia.sh remover     # desligar
```

## Limites (honestidade)

- É um **alarme de movimento**, não um muro: apanha o que muda e o que é típico de ataques, mas um
  intruso muito discreto pode passar. Complementa (não substitui) as atualizações automáticas, o Tailscale
  como única porta e os backups testados.
- Se o servidor **já estava comprometido** quando o instalaste, o vigia aprendeu isso como normal
  (as regras duras — mineradores, `/tmp`, root a mais — avisam na mesma).
- Quem tiver `root` no servidor consegue desligá-lo; por isso o aviso sai para fora (Telegram/email) e a app
  avisa se ele **deixar de correr**.
