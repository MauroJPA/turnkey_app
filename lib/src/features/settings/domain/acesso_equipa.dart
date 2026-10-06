import '../../../core/auth/permissions.dart';

/// Quem pode repor a palavra-passe ou remover [alvo] da equipa — as mesmas
/// regras do servidor (pb/hooks/team_acesso.pb.js), só para mostrar ou
/// esconder os botões: o proprietário gere qualquer pessoa menos a si próprio;
/// o administrador só Editores e Leitores; os outros ninguém.
bool podeGerirAcesso({
  required Papel eu,
  required Papel alvo,
  required bool souEu,
}) {
  if (souEu) return false;
  return switch (eu) {
    Papel.owner => true,
    Papel.admin => alvo == Papel.editor || alvo == Papel.viewer,
    _ => false,
  };
}

/// Valida a palavra-passe nova (depois de entrar com a provisória). Devolve a
/// mensagem do problema, ou `null` se está bem.
String? validarSenhaNova(String nova, String confirmar) {
  if (nova.length < 8) return 'Usa pelo menos 8 caracteres.';
  if (nova != confirmar) return 'As duas palavras-passe não são iguais.';
  return null;
}

/// O texto para mandar à pessoa (WhatsApp, SMS…) com a palavra-passe
/// provisória.
String mensagemSenhaProvisoria(String nome, String senha) {
  final ola = nome.trim().isEmpty ? 'Olá' : 'Olá ${nome.trim()}';
  return '$ola! A tua palavra-passe provisória na app é: $senha\n'
      'Entra com ela e escolhe logo uma nova.';
}
