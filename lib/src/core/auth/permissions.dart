/// Papel de um utilizador dentro da sua empresa e o que cada um pode fazer.
///
/// A UI usa estes helpers para esconder/desativar ações; o PocketBase aplica
/// as mesmas regras do lado do servidor (ver `pb/README.md`).
enum Papel {
  owner,
  admin,
  editor,
  viewer;

  static Papel fromName(String? name) {
    return Papel.values.firstWhere(
      (p) => p.name == name,
      orElse: () => Papel.viewer,
    );
  }

  /// Criar/editar/apagar ingredientes, receitas e fichas técnicas.
  bool get canEditBusiness => this != Papel.viewer;

  /// Editar as configurações de custo e a personalização da empresa.
  bool get canEditConfig => this == Papel.owner || this == Papel.admin;

  /// Convidar utilizadores e alterar papéis.
  bool get canManageTeam => this == Papel.owner || this == Papel.admin;

  /// Apagar a empresa / transferir propriedade.
  bool get isOwner => this == Papel.owner;

  String get label => switch (this) {
        Papel.owner => 'Proprietário',
        Papel.admin => 'Administrador',
        Papel.editor => 'Editor',
        Papel.viewer => 'Leitura',
      };
}
