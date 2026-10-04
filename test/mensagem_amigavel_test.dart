import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/errors/mensagem_amigavel.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('sem ligação ao servidor', () {
    final e = ClientException(
      url: Uri.parse('http://192.168.1.151:8091/api/x'),
      statusCode: 0,
    );
    final m = mensagemAmigavel(e);
    expect(m, contains('Sem ligação'));
    expect(m, isNot(contains('192.168')));
  });

  test('erro do servidor com mensagem nossa mostra a mensagem', () {
    final e = ClientException(
      url: Uri.parse('http://x/api'),
      statusCode: 400,
      response: {'message': 'Esta ficha não tem massa.', 'data': {}},
    );
    expect(mensagemAmigavel(e), 'Esta ficha não tem massa.');
  });

  test('erro 500 não mostra detalhes', () {
    final e = ClientException(
      url: Uri.parse('http://x/api'),
      statusCode: 500,
      response: {'message': 'boom'},
    );
    expect(mensagemAmigavel(e), isNot(contains('boom')));
  });

  test('erros nossos em português mostram-se; os técnicos escondem-se', () {
    expect(mensagemAmigavel(StateError('Operação requer uma empresa ativa.')),
        'Operação requer uma empresa ativa.');
    expect(mensagemAmigavel(Exception('Escolhe o sabor.')), 'Escolhe o sabor.');
    final generico = mensagemAmigavel(Exception('http://192.168.1.151/x falhou'));
    expect(generico, isNot(contains('192.168')));
    expect(generico, contains('Não foi possível'));
    expect(mensagemAmigavel(TypeError()), contains('Não foi possível'));
    expect(mensagemAmigavel("type 'Null' is not a subtype"), contains('Não foi possível'));
  });
}
