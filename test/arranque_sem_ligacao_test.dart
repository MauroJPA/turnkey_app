import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/auth/auth_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

String _b64(Map<String, Object?> m) =>
    base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');

/// Um token com a forma de um JWT que ainda não expirou.
String _jwt() =>
    '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.'
    '${_b64({'exp': DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch ~/ 1000, 'id': 'u1'})}.'
    'assinatura';

PocketBase _pb(MockClient cliente) {
  final pb = PocketBase(
    'http://servidor.teste',
    httpClientFactory: () => cliente,
  );
  pb.authStore.save(
    _jwt(),
    RecordModel({'id': 'u1', 'collectionName': 'users', 'empresa': 'e1'}),
  );
  return pb;
}

void main() {
  test(
    'sem ligação ao servidor a sessão fica (arranque do quiosque offline)',
    () async {
      final pb = _pb(
        MockClient((_) async => throw http.ClientException('sem rede')),
      );
      expect(pb.authStore.isValid, isTrue);
      await AuthRepository(pb).refresh();
      expect(pb.authStore.isValid, isTrue);
      expect(pb.authStore.record?.getStringValue('empresa'), 'e1');
    },
  );

  test('servidor em baixo (503) também não termina a sessão', () async {
    final pb = _pb(MockClient((_) async => http.Response('{}', 503)));
    await AuthRepository(pb).refresh();
    expect(pb.authStore.isValid, isTrue);
  });

  test('token recusado pelo servidor (401) termina a sessão', () async {
    final pb = _pb(
      MockClient(
        (_) async => http.Response(
          '{"status":401,"message":"The request requires valid record authorization token."}',
          401,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await AuthRepository(pb).refresh();
    expect(pb.authStore.isValid, isFalse);
  });

  test('conta apagada (404) termina a sessão', () async {
    final pb = _pb(
      MockClient(
        (_) async => http.Response(
          '{"status":404,"message":"The requested resource wasn\'t found."}',
          404,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await AuthRepository(pb).refresh();
    expect(pb.authStore.isValid, isFalse);
  });

  test('sem sessão guardada não faz nada', () async {
    var pedidos = 0;
    final pb = PocketBase(
      'http://servidor.teste',
      httpClientFactory: () => MockClient((_) async {
        pedidos++;
        return http.Response('{}', 200);
      }),
    );
    await AuthRepository(pb).refresh();
    expect(pedidos, 0);
  });
}
