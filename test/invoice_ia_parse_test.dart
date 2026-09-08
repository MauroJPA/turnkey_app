import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/invoices/domain/fatura.dart';

void main() {
  group('FaturaLinhaIa.fromJson', () {
    test('lê todos os campos', () {
      final l = FaturaLinhaIa.fromJson(const {
        'descricao': 'Farinha T55 25kg',
        'quantidade': 2,
        'unidade': 'un',
        'preco_unitario': 12.5,
        'total': 25.0,
        'embalagem_g': 25000,
      });
      expect(l.descricao, 'Farinha T55 25kg');
      expect(l.quantidade, 2);
      expect(l.precoUnitario, 12.5);
      expect(l.total, 25.0);
      expect(l.embalagemG, 25000);
    });

    test('campos em falta ficam null e strings vazias', () {
      final l = FaturaLinhaIa.fromJson(const {'descricao': 'Sal grosso'});
      expect(l.descricao, 'Sal grosso');
      expect(l.quantidade, isNull);
      expect(l.precoUnitario, isNull);
      expect(l.total, isNull);
      expect(l.embalagemG, isNull);
      expect(l.unidade, '');
    });

    test('aceita "nome" como alternativa a "descricao"', () {
      final l = FaturaLinhaIa.fromJson(const {'nome': 'Manteiga', 'quantidade': 1});
      expect(l.descricao, 'Manteiga');
    });

    test('quantidadeG converte kg e L para gramas', () {
      expect(
        FaturaLinhaIa.fromJson(const {'descricao': 'x', 'quantidade': 2, 'unidade': 'kg'})
            .quantidadeG,
        2000,
      );
      expect(
        FaturaLinhaIa.fromJson(const {'descricao': 'x', 'quantidade': 1.5, 'unidade': 'L'})
            .quantidadeG,
        1500,
      );
      expect(
        FaturaLinhaIa.fromJson(const {'descricao': 'x', 'quantidade': 500, 'unidade': 'g'})
            .quantidadeG,
        500,
      );
    });
  });

  group('Fatura.linhasIa', () {
    Fatura comDados(Map<String, dynamic> dados) => Fatura(
          id: 'f1',
          tipo: FaturaTipo.fatura,
          estado: FaturaEstado.analisada,
          dadosIa: dados,
        );

    test('extrai as linhas do JSON da IA', () {
      final dados = jsonDecode('''
        {
          "fornecedor": "Makro",
          "linhas": [
            {"descricao": "Farinha T55", "quantidade": 1, "unidade": "kg", "preco_unitario": 0.9},
            {"descricao": "Açúcar", "quantidade": 2, "unidade": "kg", "preco_unitario": 1.1}
          ]
        }
      ''') as Map<String, dynamic>;
      final linhas = comDados(dados).linhasIa;
      expect(linhas, hasLength(2));
      expect(linhas.first.descricao, 'Farinha T55');
      expect(linhas.first.quantidadeG, 1000);
    });

    test('linhas vazias ou sem descrição são ignoradas', () {
      final linhas = comDados(const {
        'linhas': [
          {'descricao': '  '},
          {'descricao': 'Válido'},
          'lixo',
        ],
      }).linhasIa;
      expect(linhas, hasLength(1));
      expect(linhas.single.descricao, 'Válido');
    });

    test('sem chave "linhas" devolve lista vazia', () {
      expect(comDados(const {}).linhasIa, isEmpty);
      expect(comDados(const {'linhas': 'nada'}).linhasIa, isEmpty);
    });

    test('erroIa lê a mensagem de erro guardada', () {
      final f = comDados(const {'erro': 'Falha na IA'});
      expect(f.erroIa, 'Falha na IA');
    });
  });
}
