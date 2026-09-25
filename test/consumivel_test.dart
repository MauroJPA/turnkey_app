import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/consumables/domain/consumivel.dart';

DocumentoConsumivel doc(TipoDocumento t, DateTime data) => DocumentoConsumivel(
  id: '${t.name}$data',
  consumivelId: 'c1',
  tipo: t,
  ficheiro: 'x.pdf',
  dataDocumento: data,
);

void main() {
  final hoje = DateTime(2026, 9, 25);
  const limpa = Consumivel(id: 'c1', nome: 'Desengordurante');

  test('exige FDS e não tem nenhum documento: falta', () {
    expect(estadoFds(limpa, const [], agora: hoje), EstadoFds.falta);
  });

  test('outros documentos não substituem a FDS', () {
    final docs = [doc(TipoDocumento.fichaTecnica, DateTime(2026, 1, 1))];
    expect(estadoFds(limpa, docs, agora: hoje), EstadoFds.falta);
  });

  test('FDS recente: ok; com mais de 3 anos: antiga', () {
    expect(
      estadoFds(limpa, [
        doc(TipoDocumento.fds, DateTime(2025, 6, 1)),
      ], agora: hoje),
      EstadoFds.ok,
    );
    expect(
      estadoFds(limpa, [
        doc(TipoDocumento.fds, DateTime(2022, 6, 1)),
      ], agora: hoje),
      EstadoFds.antiga,
    );
  });

  test('conta a FDS mais recente, não a mais antiga', () {
    final docs = [
      doc(TipoDocumento.fds, DateTime(2020, 1, 1)),
      doc(TipoDocumento.fds, DateTime(2026, 2, 1)),
    ];
    expect(estadoFds(limpa, docs, agora: hoje), EstadoFds.ok);
  });

  test('item que não exige FDS nunca fica pendente', () {
    const embalagem = Consumivel(
      id: 'c1',
      nome: 'Luvas',
      categoria: CategoriaConsumivel.insumo,
      exigeFds: false,
    );
    expect(estadoFds(embalagem, const [], agora: hoje), EstadoFds.naoExige);
  });

  test('categorias: limpeza e desinfeção exigem FDS por omissão', () {
    expect(CategoriaConsumivel.limpeza.exigeFdsPorOmissao, isTrue);
    expect(CategoriaConsumivel.desinfecao.exigeFdsPorOmissao, isTrue);
    expect(CategoriaConsumivel.insumo.exigeFdsPorOmissao, isFalse);
    expect(CategoriaConsumivel.fromApi('???'), CategoriaConsumivel.outro);
  });
}
