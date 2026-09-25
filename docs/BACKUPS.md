# Backups da base de dados — plano

> Estado: **decidido e implementado** (2026-09-24). O servidor é **Linux (Debian) com Docker**; falta só instalar — passos em `deploy/backup/LEIA-ME.md`.
>
> **Decisões do Mauro:** destino **Google Drive** (talvez migrar mais tarde) · a chave de cifra fica **com o Mauro** · retenção **30 diários + 12 mensais** · cópia semanal para **USB** (pen ou disco; 32 GB chegam, recomendado 64 GB).

## O que é preciso guardar

| O quê | Onde está | Porquê |
|---|---|---|
| Dados e ficheiros da app | `pb/pb_data/` (`data.db`, `auxiliary.db`, `storage/` com imagens, faturas, rótulos, logótipos) | É **tudo** o que a empresa tem na app. |
| Segredos | `pb/.env` (chaves da IA, Vendus, SMTP) | Não vão no backup automático; sem eles a app não fala com o exterior. Guardam-se à parte, cifrados. |
| Código | Git | Já protegido pelo repositório (ver `docs/FLUXO_GIT.md`). |

A base de dados é pequena (dezenas de MB, mais as imagens), por isso guardar muitas
cópias custa cêntimos.

## Regra 3-2-1

**3** cópias, em **2** tipos de suporte, **1** fora do local. Em concreto:

1. **Cópia local automática** — o próprio PocketBase cria todas as noites um `.zip` de
   `pb_data` (Definições → Backups: cron `0 3 * * *`, guardar os últimos **7**).
2. **Cópia na nuvem, cifrada** — todas as noites, depois da 1.ª, uma tarefa envia o
   `.zip` mais recente para um armazenamento externo (ver abaixo), **já cifrado antes de
   sair do computador**. Retenção: 30 dias diários + 1 por mês durante 12 meses.
3. **Cópia física** — uma vez por semana, um disco USB externo (com LUKS) que fica
   guardado noutro sítio que não o Mini PC.

## Para onde enviar (opções)

| Destino | Custo | Prós | Contras |
|---|---|---|---|
| **Backblaze B2** *(recomendado)* | 10 GB grátis; depois ≈ 6 US$/TB/mês | Barato, feito para backups, chaves de acesso só para esse bucket, versões | Conta nova a criar |
| Google Drive (conta da empresa) | 15 GB grátis | Já existe conta | Ligação por conta pessoal; menos controlo; risco de bloqueio da conta |
| Hetzner Storage Box | ≈ 4 €/mês por 1 TB | Europa, SFTP | Mensalidade fixa |
| NAS/disco em casa | Só o equipamento | Controlo total | Fica no mesmo país/edifício se não for de outro sítio |

Recomendo **Backblaze B2** (ou Google Drive se preferirem não abrir conta nova) **mais**
o disco USB semanal. O PocketBase também sabe enviar backups para um S3 sozinho, mas
**não os cifra por nós** — por isso preferimos o passo próprio abaixo.

## Como se cifra

Usamos o **`rclone` com o modo `crypt`**: um programa pequeno e gratuito que cifra os
ficheiros (e até os nomes) no nosso computador **antes** de os enviar. O fornecedor da
nuvem só vê dados ilegíveis.

- Algoritmo: XSalsa20 + Poly1305 (cifra autenticada; deteta se o ficheiro foi alterado).
- Chave: uma **palavra-passe longa + um "sal"** que se geram uma vez.
- **A chave é o ponto crítico**: sem ela os backups são irrecuperáveis (nem nós, nem o
  fornecedor). Por isso:
  - guardar no **gestor de palavras-passe** da empresa;
  - guardar uma **cópia impressa** num sítio seguro (cofre/gaveta fechada);
  - **nunca** no repositório Git nem no mesmo disco dos backups.
- Alternativa equivalente: `age` (chave pública para cifrar, chave privada guardada
  offline). Só a trocamos se preferirem esse modelo.
- O disco USB e o Mini PC ficam com **LUKS** ligado (cifra do disco em repouso).

## O que corre e quando

| Hora | Quem | O quê |
|---|---|---|
| 03:00 | PocketBase (cron interno) | Cria `pb_data/backups/backup_AAAAMMDD.zip` e apaga os mais antigos que 7 |
| 03:30 | Agendador de Tarefas do Windows | `rclone copy` da pasta de backups para o remoto cifrado; `rclone delete --min-age 30d` (mantendo 1/mês) |
| 03:45 | Mesma tarefa | Verifica que o ficheiro de hoje chegou; se não, avisa por email |
| Domingo | Pessoa responsável | Liga o disco USB e corre a cópia semanal |
| Todos os meses | Pessoa responsável | **Teste de restauro** (abaixo) |

O alerta por email reutiliza o SMTP já previsto no `pb/.env`.

## Restaurar (o que se faz num desastre)

1. Instalar o PocketBase numa máquina limpa (mesma versão).
2. `rclone copy remoto-cifrado:backup_AAAAMMDD.zip .` — descarrega e **decifra**.
3. Descompactar o `.zip` para `pb/pb_data/` com o servidor parado.
4. Copiar o `pb/.env` (do cofre) e arrancar `pb\serve.ps1`.
5. Entrar, conferir vendas/produções recentes e as imagens.

**Teste mensal:** fazer estes passos numa pasta temporária e registar quanto demorou e
o que faltou. Um backup que nunca foi restaurado não é um backup.

## Decisões (tomadas)

1. **Destino externo:** Google Drive (com `scope drive.file`, só vê o que o rclone cria). Migrar para Backblaze B2 ou outro é trocar o nome do remoto.
2. **Chave de cifra:** fica com o Mauro (gestor de palavras-passe + cópia em papel).
3. **Retenção:** 30 diários + 12 mensais.
4. **USB:** pen drive ou disco externo, com LUKS; 32 GB chegam, 64 GB de margem.

## O que ficou implementado

| Ficheiro | Para quê |
|---|---|
| `pb/migrations/1707609600_backups_cron.js` | Liga o backup diário do PocketBase (03:00, guarda 7) |
| `deploy/backup/copia-externa.sh` | Envia o último backup cifrado para o Drive, confirma, faz a retenção e avisa por email se falhar |
| `deploy/backup/instalar-agendamento.sh` | Cria o timer do systemd (03:30) |
| `deploy/backup/copia-usb.sh` | Cópia semanal para o USB cifrado com LUKS (mantém 12) |
| `deploy/backup/teste-restauro.sh` | Teste mensal de restauro (nuvem ou USB) num contentor descartável |
| `deploy/backup/LEIA-ME.md` | Instalação passo a passo |

Testado aqui com um rclone simulado: envio, confirmação, falha por backup antigo /
pasta inexistente (saída ≠ 0), cópia USB e restauro a partir de um backup real.
**Ainda por testar no Mini PC:** o rclone a sério com a conta Google e o Agendador.
