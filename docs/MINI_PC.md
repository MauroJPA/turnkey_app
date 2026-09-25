# Instalar a Gookie no Mini PC

Um só programa (o PocketBase) serve a **app web** e a **API**, na mesma porta (8090).
Tudo o que precisas vem no pacote `gookie-producao-<versão>.zip`
(criado no PC de desenvolvimento com `scripts\empacotar-producao.ps1`).

> Faz **por ordem**. Marca cada passo. Tempo estimado: 1 hora (mais o Google Drive dos backups).

## 0. O PC

- [ ] Windows 10/11 atualizado, com **conta de administrador**. Ligado à internet (Gemini e Vendus precisam de saída).
- [ ] **Nunca adormecer:** Definições → Sistema → Energia → "Nunca" para suspender e hibernar.
- [ ] **BIOS:** ligar sozinho quando volta a luz ("Restore on AC power loss" = *Power On*).
- [ ] Ideal: **UPS/nobreak** pequeno (evita a base de dados corromper num corte).
- [ ] Windows Update: definir as **horas ativas** para não reiniciar a meio do dia (ex.: 07:00–23:00).
- [ ] **Disco:** pelo menos 20 GB livres. Bitlocker no disco se o PC puder ser levado.

## 1. Copiar o pacote

- [ ] Copiar o zip para o Mini PC (USB ou rede). Conferir o **SHA-256** que o script mostrou:
      `Get-FileHash .\gookie-producao-1.6.0.zip -Algorithm SHA256`
- [ ] Descompactar para **`C:\Gookie\`** (fica `C:\Gookie\pb\…` e `C:\Gookie\docs\…`).
      Não ponhas em Ambiente de Trabalho/Transferências (podem ser apagados).

## 2. Chaves (`pb\.env`)

- [ ] `cd C:\Gookie\pb` → copiar `.env.example` para `.env` e preencher **só o que precisas**:
      `TURNKEY_AI_PROVIDER=gemini` e `GEMINI_API_KEY=…` (faturas por IA).
      **Não** ligar `TURNKEY_DEV` (a produção força-o a 0).
- [ ] Gerar a chave de cifra dos tokens: `.\gerar-chave-cifra.ps1 -Gravar`, depois abrir
      `pb\.env` e **copiar a linha `TURNKEY_ENC_KEY` para o gestor de palavras-passe**.
- [ ] O token do **Vendus** não vai aqui: guarda-se na app (Configurações → Integrações).
- [ ] O `.env` só deve poder ser lido por administradores (é o comportamento normal da pasta em `C:\`).

## 3. Superutilizador (só tu)

Cria a conta com que entras no painel de administração (`/_/`) e aprovas registos:

```powershell
cd C:\Gookie\pb
.\bin\pocketbase.exe superuser upsert o-teu-email@exemplo.pt "UMA-PALAVRA-PASSE-LONGA-E-UNICA" --dir .\pb_data
```

- [ ] Palavra-passe **longa e única** (16+ caracteres), no gestor de palavras-passe.

## 4. Primeiro arranque (teste manual)

```powershell
cd C:\Gookie\pb
.\serve-producao.ps1
```

- [ ] Aparece "PocketBase em http://127.0.0.1:8090". A 1.ª vez aplica as migrations (~1 min por causa da tabela INSA).
- [ ] No mesmo PC abrir `http://127.0.0.1:8090` → ecrã de login da app.
- [ ] `http://127.0.0.1:8090/_/` → entrar como superutilizador.
- [ ] Parar com Ctrl+C (o arranque automático vem no passo 6).

## 5. Dados: começar limpo ou levar os do teste?

- **Limpo (recomendado):** nada a fazer. No passo 8 crias a empresa real e carregas ingredientes,
  receitas e fichas (ou importas).
- **Levar o que já está no PC de desenvolvimento:** *no PC de desenvolvimento*, parar o servidor e
  copiar `pb\pb_data` para o Mini PC (`C:\Gookie\pb\pb_data`) **antes** do passo 4. Há empresas e
  utilizadores de teste lá dentro: apaga-os no painel `/_/` se não os quiseres.

## 6. Arranque automático

Abrir a PowerShell **como Administrador**:

```powershell
cd C:\Gookie\pb
.\instalar-arranque.ps1            # só neste PC / atrás de um túnel (recomendado com HTTPS, passo 7)
# ou
.\instalar-arranque.ps1 -Rede      # também acessível na rede local (http://<ip-do-mini-pc>:8090)
```

- [ ] Cria a tarefa **Gookie PocketBase** (arranca com o PC, reinicia se falhar) e a **vigia**
      (de 5 em 5 min verifica `/api/health` e reinicia se não responder).
- [ ] **Teste:** reiniciar o Mini PC sem iniciar sessão → passado 1–2 minutos `http://127.0.0.1:8090` responde.
- [ ] Registos: `C:\Gookie\pb\logs\`.

## 7. Como os telemóveis/PC chegam à app (escolhe **uma** via)

Sem HTTPS a sessão viaja em texto simples, por isso **fora da loja usa sempre HTTPS**.

| Via | Bom para | Como |
|---|---|---|
| **A. Cloudflare Tunnel** (recomendada se tiveres/comprares um domínio) | Toda a equipa, qualquer rede, sem instalar nada nos telemóveis; HTTPS incluído | Instalar `cloudflared`, criar um túnel para `http://127.0.0.1:8090` e um nome (ex.: `app.teudominio.pt`). **Bloquear `/_/`** (regra de caminho a devolver 404). Instalar sem `-Rede`. |
| **B. Tailscale** | Pouca gente, sem domínio; muito privado | Instalar Tailscale no Mini PC e em cada telemóvel/PC; `tailscale serve --https=443 http://127.0.0.1:8090`. Só quem estiver na tua rede Tailscale acede. |
| **C. Só rede local** | Só dentro da loja | `-Rede` no passo 6; abrir `http://<ip>:8090` (dá-lhe IP fixo no router). **Sem HTTPS**: não uses fora da loja. |

- [ ] Depois de escolhida a via, abrir `/_/` → **Definições → Application**: pôr o **Application URL**
      (o endereço final) e, em **Trusted proxy headers**, o cabeçalho do proxy
      (`CF-Connecting-IP` no Cloudflare; `X-Forwarded-For` no Tailscale). Sem isto o **limite de
      tentativas de login** trata toda a gente como um só utilizador.
- [ ] Confirmar **Definições → Application → Rate limiting** ligado (já vem ligado).
- [ ] Cloudflare: acrescentar (Transform Rules) os cabeçalhos `Strict-Transport-Security`,
      `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`.
- [ ] O painel `/_/` **não** deve abrir a partir da internet: testar no telemóvel com dados móveis.

## 8. Criar a empresa real (na app)

- [ ] Abrir o endereço final → **Não tenho conta → criar** → ver "A tua conta aguarda aprovação".
- [ ] No painel `/_/` → **users** → marcar **aprovado** nessa conta.
- [ ] Na app: "Verificar novamente" → **criar a empresa** (Gookie). Fica proprietário.
- [ ] Configurações → **Integrações** → guardar o **token do Vendus** (o novo, não o exposto).
- [ ] **Equipa**: criar os utilizadores e papéis. **Navegação e permissões**: definir o que cada nível vê.
- [ ] Carregar ingredientes, receitas, fichas técnicas, formatos; **Produtos Gookie**: descrição, validade,
      conservação e o **produtor** (nome e morada) para as etiquetas.

## 9. Backups (antes de usar a sério!)

- [ ] Seguir `pb\backup\LEIA-ME.md` (rclone + Google Drive cifrado + USB semanal). Sem isto **não há**
      cópia fora do PC.
- [ ] O PocketBase já faz backup local **todas as noites às 03:00** (7 mais recentes).
- [ ] Guardar num sítio seguro (**fora do Mini PC**): a chave `TURNKEY_ENC_KEY`, a password e o sal do rclone,
      a palavra-passe do superutilizador.
- [ ] Fazer o **primeiro restauro de teste** (`pb\backup\teste-restauro.ps1`) e anotar o tempo.

## 10. Ensaio de aceitação (antes de a equipa usar)

- [ ] Login/logout; recusa de palavra-passe errada; criar conta nova fica por aprovar.
- [ ] **Comprar → produzir → stock → vender** com dados reais (uma produção completa).
- [ ] Fatura por foto (IA) e por PDF; abrir o ficheiro da fatura.
- [ ] Sincronizar com o Vendus (dados reais).
- [ ] **Imprimir** uma etiqueta (impressora térmica real) e um talão.
- [ ] Reiniciar o Mini PC e voltar a entrar.
- [ ] Do telemóvel, fora da loja: entra por HTTPS; `/_/` **não** abre.
- [ ] Papéis: com um utilizador Leitura confirmar que não consegue editar.

## 11. Atualizar mais tarde

**App/hooks/migrations (novo pacote):**
1. Fazer um backup: `Copy-Item C:\Gookie\pb\pb_data C:\Gookie\pb_data_antes_$(Get-Date -f yyyyMMdd-HHmm) -Recurse`.
2. Parar: `Stop-ScheduledTask "Gookie PocketBase"; Get-Process pocketbase | Stop-Process -Force`.
3. Copiar do novo pacote para `C:\Gookie\pb\`: as pastas `web`, `hooks`, `migrations` (substituir) e, se vier,
   `bin\pocketbase.exe`. **Não tocar** em `pb_data` nem em `.env`.
4. Arrancar: `Start-ScheduledTask "Gookie PocketBase"` (as migrations novas aplicam-se sozinhas).
5. Repetir o ensaio rápido (login, uma produção, uma venda).

**Só o PocketBase:** `cd C:\Gookie\pb ; .\atualizar-pocketbase.ps1` e reiniciar a tarefa.

## 12. Se correr mal (retrocesso)

1. Parar o serviço (passo 2 acima).
2. Apagar `pb_data` e repor a cópia `pb_data_antes_…` (ou um backup de `pb_data\backups`).
3. Repor a versão anterior de `web`, `hooks`, `migrations` (do pacote antigo) e, se mudaste, o `pocketbase.exe.antiga`.
4. Arrancar outra vez.

## 13. Monitorização mínima

- [ ] A tarefa **vigia** reinicia o servidor se deixar de responder (`pb\logs\vigia.log`).
- [ ] Verificar de vez em quando: **espaço livre** no disco, o log mais recente em `pb\logs\`, e que o
      último backup na Google Drive tem data de ontem.
- [ ] Combinar **quem é avisado** se o serviço parar (ex.: pedir à equipa para avisar se a app não abrir).
- [ ] Registos novos por aprovar: `/_/` → users → `aprovado = false`.
