import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/settings/data/avisos_repository.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('lê a configuração do registo', () {
    final c = AvisosConfig.fromRecord(
      RecordModel({
        'id': 'a1',
        'ativo': true,
        'hora': '07:30',
        'email_ativo': true,
        'email_para': 'a@x.pt, b@x.pt',
        'telegram_ativo': true,
        'telegram_chat': '987654',
        'inc_haccp': true,
        'inc_stock': false,
        'ultimo_envio': '2026-10-05',
        'ultimo_resultado': 'telegram: enviado',
      }),
    );
    expect(c.ativo, isTrue);
    expect(c.hora, '07:30');
    expect(c.emailPara, 'a@x.pt, b@x.pt');
    expect(c.telegramChat, '987654');
    expect(c.incStock, isFalse);
    expect(c.ultimoEnvio, '2026-10-05');
  });

  test('hora inválida cai em 08:00; sem registo tudo incluído e desligado', () {
    final c = AvisosConfig.fromRecord(RecordModel({'id': 'x', 'hora': 'lixo'}));
    expect(c.hora, '08:00');
    const v = AvisosConfig();
    expect(v.ativo, isFalse);
    expect(v.telegramAtivo, isFalse);
    expect(v.emailAtivo, isFalse);
    expect(
      v.incHaccp &&
          v.incStock &&
          v.incPagamentos &&
          v.incFaturas &&
          v.incPrecos,
      isTrue,
    );
  });

  test('o corpo a gravar traz tudo e tira espaços', () {
    final b = const AvisosConfig(
      ativo: true,
      hora: '09:15',
    ).copyWith(emailPara: '  a@x.pt ', telegramChat: ' 123 ').toBody();
    expect(b['ativo'], true);
    expect(b['hora'], '09:15');
    expect(b['email_para'], 'a@x.pt');
    expect(b['telegram_chat'], '123');
    expect(
      b.keys,
      containsAll([
        'inc_haccp',
        'inc_stock',
        'inc_pagamentos',
        'inc_faturas',
        'inc_precos',
      ]),
    );
    expect(b.containsKey('ultimo_envio'), isFalse); // só o servidor escreve
  });
}
