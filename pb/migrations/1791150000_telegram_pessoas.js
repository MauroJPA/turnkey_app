/// <reference path="../pb_data/types.d.ts" />

// Telegram de cada pessoa (2.20.0).
//
// `telegram_pessoas`: liga um utilizador à sua conversa privada com o bot da
// empresa, para lhe mandar o que é só dele (as menções nas Tarefas).
// Liga-se assim: a app pede um código (`/api/gc_turnkey/telegram/pessoal/ligar`)
// e abre o bot com `t.me/<bot>?start=<código>`; ao carregar em "Iniciar", a
// sondagem de minuto a minuto apanha o código e grava o chat.
//
// Só o servidor escreve (create/update sem regra = só superutilizador e hooks).
// Cada pessoa vê e apaga (desliga) a sua; a administração vê e desliga as da
// empresa. O código e a validade estão escondidos da API.
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const ehAdmin = "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const minhaOuAdmin = `@request.auth.id != '' && empresa = @request.auth.empresa && (user = @request.auth.id || ${ehAdmin})`;

    const c = new Collection({
      type: 'base',
      name: 'telegram_pessoas',
      listRule: minhaOuAdmin,
      viewRule: minhaOuAdmin,
      createRule: null,
      updateRule: null,
      deleteRule: minhaOuAdmin,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'relation', name: 'user', required: true, maxSelect: 1, collectionId: users.id, cascadeDelete: true },
        // id do chat privado (vazio enquanto a pessoa não carregar em "Iniciar")
        { type: 'text', name: 'chat', required: false, max: 30 },
        // nome que o Telegram mostra (para a pessoa confirmar que é ela)
        { type: 'text', name: 'nome', required: false, max: 80 },
        { type: 'text', name: 'codigo', required: false, max: 40, hidden: true },
        { type: 'date', name: 'expira', required: false, hidden: true },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_telegram_pessoas_user` ON `telegram_pessoas` (`user`)',
        'CREATE INDEX `idx_telegram_pessoas_empresa` ON `telegram_pessoas` (`empresa`, `codigo`)',
      ],
    });
    app.save(c);
  },
  (app) => {
    try {
      app.delete(app.findCollectionByNameOrId('telegram_pessoas'));
    } catch (_) {}
  },
);
