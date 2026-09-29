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

  /// Trocar o ingrediente (ou sub-receita) ligado a uma linha da receita —
  /// mais sensível do que só ajustar a quantidade, porque muda a composição,
  /// o custo e os alergénios da receita.
  bool get canSwapRecipeIngredient =>
      this == Papel.owner || this == Papel.admin;

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
