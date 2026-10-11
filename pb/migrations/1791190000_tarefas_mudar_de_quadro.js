/// <reference path="../pb_data/types.d.ts" />

// Mudar uma tarefa de quadro (2.22.2).
//
// Antes, uma tarefa nunca mudava de quadro (`quadro` não podia ser alterado).
// Agora pode, para corrigir uma tarefa criada no quadro errado, com estas
// garantias (a regra de atualização das tarefas):
//   - o quadro de destino é da mesma empresa de quem muda e não está arquivado;
//   - a fase vem no mesmo pedido e é uma fase do quadro de destino (nunca fica
//     uma tarefa com a fase de outro quadro);
//   - a empresa e o autor continuam a não poder mudar;
//   - sem mudar de quadro, tudo se mantém como era (a fase é do próprio quadro).
// Os comentários seguem a tarefa (ligam-se a ela, não ao quadro).
migrate(
  (app) => {
    const membro = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const escreve = `${membro} && @request.auth.papel != 'viewer'`;
    const naoMuda = (campo) => `(@request.body.${campo}:isset = false || @request.body.${campo} = ${campo})`;
    const pessoasDaEmpresa = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo}:length = 0 || @request.body.${campo}.empresa = @request.auth.empresa)`;

    const mesmoQuadro = '(@request.body.quadro:isset = false || @request.body.quadro = quadro)';
    const faseDoQuadro = '(@request.body.coluna:isset = false || @request.body.coluna.quadro = quadro)';
    const outroQuadro =
      '(@request.body.quadro.empresa = @request.auth.empresa && @request.body.quadro.arquivado = false' +
      ' && @request.body.coluna:isset = true && @request.body.coluna.quadro = @request.body.quadro)';

    const tarefas = app.findCollectionByNameOrId('tarefas');
    tarefas.updateRule =
      `${escreve} && ${naoMuda('empresa')} && ${naoMuda('autor')}` +
      ` && ((${mesmoQuadro} && ${faseDoQuadro}) || ${outroQuadro})` +
      ` && ${pessoasDaEmpresa('responsaveis')}`;
    app.save(tarefas);
  },
  (app) => {
    const membro = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const escreve = `${membro} && @request.auth.papel != 'viewer'`;
    const naoMuda = (campo) => `(@request.body.${campo}:isset = false || @request.body.${campo} = ${campo})`;
    const pessoasDaEmpresa = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo}:length = 0 || @request.body.${campo}.empresa = @request.auth.empresa)`;

    const tarefas = app.findCollectionByNameOrId('tarefas');
    tarefas.updateRule =
      `${escreve} && ${naoMuda('empresa')} && ${naoMuda('quadro')} && ${naoMuda('autor')}` +
      ' && (@request.body.coluna:isset = false || @request.body.coluna.quadro = quadro)' +
      ` && ${pessoasDaEmpresa('responsaveis')}`;
    app.save(tarefas);
  },
);
