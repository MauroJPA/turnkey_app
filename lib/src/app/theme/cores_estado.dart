import 'package:flutter/material.dart';

/// Cores de estado (sucesso, aviso) afinadas à marca e legíveis nos dois
/// modos — para usar no lugar de `Colors.green` / `Colors.orange`, que tinham
/// um tom diferente em cada ecrã. O perigo continua a ser `cs.error`.
extension CoresEstado on ColorScheme {
  bool get _escuro => brightness == Brightness.dark;

  /// Tudo certo / dentro do esperado (verde da marca, mais claro no escuro).
  Color get sucesso => _escuro ? const Color(0xFF7FC79A) : const Color(0xFF2E6B45);

  /// Atenção / a precisar de olhar (caramelo queimado).
  Color get aviso => _escuro ? const Color(0xFFE0B070) : const Color(0xFF9A5B12);

  /// Fundo suave para avisos (cartões, faixas) e o texto que lá vai.
  Color get avisoSuave => _escuro ? const Color(0xFF3A3020) : const Color(0xFFFBEFD5);
  Color get sobreAvisoSuave => _escuro ? const Color(0xFFF1D9A8) : const Color(0xFF6B3F08);
}
