# Login com Google / Apple

O `turnkey_app` usa o **fluxo OAuth2 do PocketBase**: o servidor guarda o
`client id` + `secret`, a app só abre o browser. Os botões na tela de login
**ativam-se sozinhos** quando o provedor estiver configurado (a app pergunta ao
servidor quais estão ativos).

---

## 1. Google

### Google Cloud Console

1. https://console.cloud.google.com → cria/escolhe um projeto.
2. **APIs & Services → OAuth consent screen**: tipo "External", preenche nome da
   app, email de suporte, domínio. Publica (ou deixa em "Testing" e adiciona os
   emails de teste).
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**
   - Application type: **Web application**
   - **Authorized redirect URIs** — adiciona os dois:
     - `http://127.0.0.1:8090/api/oauth2-redirect` (desenvolvimento local)
     - `https://<dominio-do-mini-pc>/api/oauth2-redirect` (produção)
   - Guarda o **Client ID** e o **Client secret**.

### PocketBase

`Admin UI → Collections → users → ⚙ (Options) → Auth methods → OAuth2` →
ativar, **Add provider → Google**, colar o Client ID e o Client secret → Save.

---

## 2. Apple

Requer conta **Apple Developer paga** (99 USD/ano).

1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles**
   - **Identifiers → App ID** (`com.gookie.turnkey`) com "Sign In with Apple".
   - **Identifiers → Services ID** (ex. `com.gookie.turnkey.web`) com "Sign In
     with Apple" configurado:
     - Domains: `<dominio-do-mini-pc>`
     - Return URLs: `https://<dominio-do-mini-pc>/api/oauth2-redirect`
   - **Keys → +** → "Sign In with Apple" → descarrega o `.p8` e anota o **Key ID**.
   - Anota o **Team ID** (canto superior direito).
2. No PocketBase, provider **Apple**:
   - Client ID = o **Services ID** (`com.gookie.turnkey.web`)
   - Team ID, Key ID
   - Private key = conteúdo do ficheiro `.p8`

> Nota iOS: a App Store exige "Sign in with Apple" **nativo** quando há outros
> logins sociais. O fluxo web do PocketBase serve para já; para publicar na App
> Store adiciona-se depois o `sign_in_with_apple` nativo.

---

## 3. Verificar

- Reinicia a app de login (ou faz pull-to-refresh) — o botão do provedor
  configurado fica clicável.
- Clicar abre o browser no ecrã do Google/Apple; ao voltar, entra-se na app.
- Utilizador novo por OAuth entra sem `empresa` → vai para o **onboarding**.

## Como a app sabe que está ativo

`AuthRepository.enabledOAuthProviders()` chama
`pb.collection('users').listAuthMethods()` e lê `oauth2.providers`. Nada a mudar
na app quando ligas/desligas um provedor no servidor.
