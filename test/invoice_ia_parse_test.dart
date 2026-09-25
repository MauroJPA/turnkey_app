import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/invoices/data/invoice_repository.dart';
import 'package:gc_turnkey/src/features/invoices/domain/fatura.dart';
import 'package:pocketbase/pocketbase.dart';

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

    test('unidades: quantidade x peso da embalagem (2 un de 15 g = 30 g)', () {
      final noz = FaturaLinhaIa.fromJson(const {
        'descricao': 'Noz moscada moída 15g',
        'quantidade': 2,
        'unidade': 'un',
        'embalagem_g': 15,
      });
      expect(noz.contaEmbalagens, isTrue);
      expect(noz.quantidadeG, 30);
      final cravo = FaturaLinhaIa.fromJson(const {
        'descricao': 'Cravinho moído 14gr',
        'quantidade': 1,
        'unidade': 'un',
        'embalagem_g': 14,
      });
      expect(cravo.quantidadeG, 14);
      // sem unidade escrita também conta embalagens
      final semUn = FaturaLinhaIa.fromJson(const {
        'descricao': 'x',
        'quantidade': 3,
        'embalagem_g': 100,
      });
      expect(semUn.quantidadeG, 300);
    });

    test('unidades sem peso de embalagem: fica a quantidade lida', () {
      final l = FaturaLinhaIa.fromJson(const {
        'descricao': 'x',
        'quantidade': 2,
        'unidade': 'un',
      });
      expect(l.contaEmbalagens, isFalse);
      expect(l.quantidadeG, 2);
    });

    test('peso/volume com embalagem conhecida não se multiplica', () {
      final l = FaturaLinhaIa.fromJson(const {
        'descricao': 'x',
        'quantidade': 500,
        'unidade': 'g',
        'embalagem_g': 250,
      });
      expect(l.contaEmbalagens, isFalse);
      expect(l.quantidadeG, 500);
      expect(
        FaturaLinhaIa.fromJson(const {
          'descricao': 'x',
          'quantidade': 25,
          'unidade': 'cl',
        }).quantidadeG,
        250,
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

  group('Fatura.fromRecord', () {
    test('dados_ia vazio ("") de um json field por preencher não rebenta', () {
      final r = RecordModel({
        'id': 'f1',
        'tipo': 'fatura',
        'estado': 'nova',
        'dados_ia': '', // PocketBase devolve "" para json por preencher
      });
      final f = Fatura.fromRecord(r);
      expect(f.dadosIa, isEmpty);
      expect(f.linhasIa, isEmpty);
      expect(f.estado, FaturaEstado.nova);
    });

    test('dados_ia com objeto é lido', () {
      final r = RecordModel({
        'id': 'f2',
        'tipo': 'lista_precos',
        'estado': 'analisada',
        'dados_ia': {
          'fornecedor': 'Makro',
          'linhas': [
            {'descricao': 'Farinha', 'preco_unitario': 0.9},
          ],
        },
      });
      final f = Fatura.fromRecord(r);
      expect(f.tipo, FaturaTipo.listaPrecos);
      expect(f.linhasIa, hasLength(1));
      expect(f.linhasIa.single.descricao, 'Farinha');
    });
  });

  group('InvoiceRepository.nomeFicheiro', () {
    test('segue FT-FORNECEDOR-DDMMAAAA.ext (data da fatura)', () {
      expect(
        InvoiceRepository.nomeFicheiro(
            'Makro', DateTime(2026, 9, 8), 'IMG_0421.JPG'),
        'FT-MAKRO-08092026.jpg',
      );
      expect(
        InvoiceRepository.nomeFicheiro(
            'Nova Distribuição, Lda', DateTime(2025, 12, 1), 'fatura.pdf'),
        'FT-NOVADISTRIBUICAOLDA-01122025.pdf',
      );
      expect(
        InvoiceRepository.nomeFicheiro('', DateTime(2026, 1, 3), 'x.webp'),
        'FT-FORNECEDOR-03012026.webp',
      );
    });
  });
}
