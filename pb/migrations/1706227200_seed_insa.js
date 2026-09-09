/// <reference path="../pb_data/types.d.ts" />

// Semente da tabela de referencia nutricional: INSA BDCA v7.1 (2026),
// "Valores por 100 g de parte edivel". Fonte: portfir.insa.pt (uso publico).
// Colunas (tab): cod, nome, grupo, nome_normalizado(sinonimos), kcal, lipidos,
//   saturados, hidratos, acucares, fibra, proteina, sal.
// Idempotente: nao faz nada se `ingredientes_referencia` ja tiver linhas.

migrate(
  (app) => {
    const ja = app.findRecordsByFilter(
      "ingredientes_referencia", "id != ''", "", 1, 0, {},
    );
    if (ja.length > 0) return;

    const FONTE = "INSA BDCA v7.1 (2026)";
    const NL = String.fromCharCode(10);
    const TAB = String.fromCharCode(9);
    const DATA = `624	Abacate, Hass	Frutos e produtos derivados de frutos	abacate, hass	176	17.4	4.2	2.3	2.3	3	1.1	0
625	Abóbora cristalizada	Produtos hortícolas e derivados	abobora cristalizada	293	0.2	0.1	72.4	72.4	0.7	0	0.1
579	Abóbora crua	Produtos hortícolas e derivados	abobora crua	11	0.2	0.1	1.7	1.4	0.7	0.3	0
801	Abrótea cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	abrotea cozida	79	0.1	0	0	0	0	19.4	0.9
800	Abrótea crua	Peixes, mariscos, anfíbios, répteis e invertebrados	abrotea crua	70	0.1	0	0	0	0	17.2	0.2
1188	Açafrão	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	acafrao	353	5.9	1.6	61.5	42.4	3.9	11.4	0.4
1187	Açafrão-da-índia seco	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	acafrao-da-india seco	312	7	2.9	44.1	44.1	22.7	6.7	0.1
1900000023	Acelga crua	Produtos hortícolas e derivados	acelga crua	23	0.2	0	2.7	0.6	1.6	1.8	0.5
510	Achocolatado com alto teor de gordura, pó	Açúcar e similares, confeitaria e sobremesas doces à base de água	achocolatado com alto teor de gordura, po	428	10.6	4.8	70.6	45.3	1	12	0.9
509	Achocolatado com baixo teor de gordura, pó	Açúcar e similares, confeitaria e sobremesas doces à base de água	achocolatado com baixo teor de gordura, po	395	2.5	1.1	86.2	73.4	1	6.5	0.6
1008	Açorda	Pratos compostos	acorda	104	4	0.6	13.1	0.5	1	3.3	0.5
1010	Açorda à alentejana	Pratos compostos	acorda a alentejana	95	3.3	0.7	12.3	0.5	0.9	3.5	0.6
1011	Açorda de bacalhau	Pratos compostos	acorda de bacalhau	69	3.5	0.6	5.7	0.4	0.5	3.4	0.6
1014	Açorda de marisco	Pratos compostos	acorda de marisco	51	1.2	0.2	5.4	0.2	0.4	4.5	0.4
949	Açorda de ovo	Pratos compostos	acorda de ovo	108	4	0.7	14	0.5	0.9	3.6	0.8
502	Açúcar amarelo	Açúcar e similares, confeitaria e sobremesas doces à base de água	acucar amarelo	390	0	0	97.5	97.5	0	0	0
503	Açúcar branco	Açúcar e similares, confeitaria e sobremesas doces à base de água	acucar branco	397	0	0	99.3	99.3	0	0	0
580	Agrião cru	Produtos hortícolas e derivados	agriao cru	29	0.9	0.3	0.4	0.4	3	3.4	0.1
2	Água mineral natural gaseificada, "Água Castello"	Água e bebidas à base de água	agua mineral natural gaseificada, "agua castello"	0	0	0	0	0	0	0	0
5	Água mineral natural gaseificada, "Vimeiro"	Água e bebidas à base de água	agua mineral natural gaseificada, "vimeiro"	0	0	0	0	0	0	0	0
3	Água mineral natural gasocarbónica, "Pedras Salgadas"	Água e bebidas à base de água	agua mineral natural gasocarbonica, "pedras salgadas"	0	0	0	0	0	0	0	0.2
4	Água mineral natural, "Luso"	Água e bebidas à base de água	agua mineral natural, "luso"	0	0	0	0	0	0	0	0
1	Água, rede pública de abastecimento (Lisboa)	Água e bebidas à base de água	agua, rede publica de abastecimento (lisboa)	0	0	0	0	0	0	0	0
729	Aguardente	Bebidas alcoólicas	aguardente	308	0	0	0	0	0	0	0
959	Aipo cru	Produtos hortícolas e derivados	aipo cru	15	0.1	0	1.5	1.5	2	1.1	0.3
583	Alcachofra cozida	Produtos hortícolas e derivados	alcachofra cozida	46	0.2	0	5.3	2.1	5.6	3	0.4
582	Alcachofra crua	Produtos hortícolas e derivados	alcachofra crua	51	0.2	0	6.8	2.7	5	3	0.2
1900000033	Alcaparras (picles)	Produtos hortícolas e derivados	alcaparras (picles)	44	0.9	0.2	4.9	0.4	3.2	2.4	7.4
1189	Alecrim fresco	Produtos hortícolas e derivados	alecrim fresco	115	4.4	1.1	13.5	13.5	7.7	1.4	0
1190	Alecrim seco	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	alecrim seco	377	15.2	3.9	46.4	46.4	17.7	4.9	0.1
584	Alface	Produtos hortícolas e derivados	alface	12	0	0	1.5	1.5	1.1	0.9	0
1900000024	Alface roxa	Produtos hortícolas e derivados	alface roxa	12	0	0	1.5	1.5	1.1	0.9	0.1
250030	Algas nori	Produtos hortícolas e derivados	algas nori	256	2.6	0.5	9.2	0.6	36	30.8	8
339	Alheira cozida	Carne e produtos cárneos	alheira cozida	269	14	4.1	26.8	1	1.4	8.3	1.5
338	Alheira crua	Carne e produtos cárneos	alheira crua	309	18.1	5.2	27.4	1	1.4	8.3	1.7
340	Alheira grelhada	Carne e produtos cárneos	alheira grelhada	302	17	4.9	28.5	1	1.5	8.1	1.7
581	Alho-francês cru	Produtos hortícolas e derivados	alho-frances cru	26	0.3	0.1	2.9	2.2	2.4	1.8	0
8	Alho cru	Produtos hortícolas e derivados	alho cru	72	0.6	0.1	11.3	1.3	3	3.8	0
9	Alho em pó	Produtos hortícolas e derivados	alho em po	310	1.2	0.2	52.3	6	10	17.6	0.1
1035	Almôndegas de porco	Pratos compostos	almondegas de porco	234	8.9	2.8	29.2	2.2	2.2	8	0.9
1036	Almôndegas de vaca	Pratos compostos	almondegas de vaca	252	17.4	7.1	6.4	1.1	0.7	17	0.9
373	Almôndegas de vaca e porco	Pratos compostos	almondegas de vaca e porco	243	16.7	6.9	3.8	1.2	0.2	19.2	1.9
644	Alperce	Frutos e produtos derivados de frutos	alperce	48	0.1	0	8.5	8.5	2.1	0.8	0
648	Alperce seco	Frutos e produtos derivados de frutos	alperce seco	242	0.9	0.1	41.2	41.2	19	5.4	0.1
645	Alperce, conserva em calda de açúcar	Frutos e produtos derivados de frutos	alperce, conserva em calda de acucar	163	0.1	0	39.3	39.3	1.2	0.5	0
250025	Alternativa vegetal ao iogurte à base de coco, sem açúcar	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	alternativa vegetal ao iogurte a base de coco, sem acucar	89	6.5	5.5	6.6	2.3	0.5	0.7	0
2122000001	Alternativa vegetal ao iogurte à base de soja	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	alternativa vegetal ao iogurte a base de soja	59	2.4	0.6	5.9	4.5	0.9	3	0.1
908	Amêijoa aberta ao natural sem sal	Peixes, mariscos, anfíbios, répteis e invertebrados	ameijoa aberta ao natural sem sal	131	1.8	0.4	5.2	0	0	23.4	1.2
907	Amêijoa crua	Peixes, mariscos, anfíbios, répteis e invertebrados	ameijoa crua	65	0.9	0.2	2.6	0	0	11.7	0.6
1162	Amêijoas à Bulhão Pato	Pratos compostos	ameijoas a bulhao pato	89	2.5	0.4	3.2	0.3	0.4	12.8	0.7
626	Ameixa branca	Frutos e produtos derivados de frutos	ameixa branca	40	0.2	0	7.8	7.8	1.6	0.6	0.1
627	Ameixa encarnada	Frutos e produtos derivados de frutos	ameixa encarnada	41	0.2	0	7.4	7.4	1.9	0.8	0
630	Ameixa rainha Cláudia	Frutos e produtos derivados de frutos	ameixa rainha claudia	57	0.1	0	11.8	11.8	2.3	0.8	0
631	Ameixa seca	Frutos e produtos derivados de frutos	ameixa seca	198	0.3	0	37.8	37.8	15.6	2.9	0
628	Ameixa, conserva em calda de açúcar	Frutos e produtos derivados de frutos	ameixa, conserva em calda de acucar	115	0.2	0	27.5	27.5	1	0.2	0
697	Amêndoa, miolo, com pele	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	amendoa, miolo, com pele	643	56	4.7	7.2	4.6	12	21.6	0
698	Amêndoa, miolo, torrada, sem pele	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	amendoa, miolo, torrada, sem pele	650	56.8	4.7	7.1	5	12.2	21.6	0
699	Amendoim, miolo	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	amendoim, miolo	589	47.7	8.5	10.1	4.8	8.8	25.4	0
701	Amendoim, miolo, torrado com sal	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	amendoim, miolo, torrado com sal	622	51	9.2	6	6	15	27.3	1
700	Amendoim, miolo, torrado sem sal	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	amendoim, miolo, torrado sem sal	622	51	8.8	6	6	15	27.3	0
1900000089	Amora silvestre	Frutos e produtos derivados de frutos	amora silvestre	43	0.9	0	4.5	4.2	4.6	1.4	0
632	Ananás	Frutos e produtos derivados de frutos	ananas	42	0	0	8.6	8.3	1.1	0.5	0
1900000104	Ananás desidratado	Frutos e produtos derivados de frutos	ananas desidratado	363	1.5	0	72.8	72.8	9.2	3.8	0
633	Ananás, conserva em calda de açúcar	Frutos e produtos derivados de frutos	ananas, conserva em calda de acucar	98	0	0	23.2	23.2	0.5	0.5	0
1191	Anchova, conserva em óleo, escorrido	Peixes, mariscos, anfíbios, répteis e invertebrados	anchova, conserva em oleo, escorrido	191	10	1.6	0	0	0	25.2	9.8
635	Anona	Frutos e produtos derivados de frutos	anona	82	0.4	0	16.8	14.8	2.4	1.7	0
1900000105	Anona desidratada	Frutos e produtos derivados de frutos	anona desidratada	351	1.7	0	71.6	63	10.2	7.2	0.1
1087	Arroz à valenciana	Pratos compostos	arroz a valenciana	111	5.3	1.4	7.7	0.7	0.8	7.6	0.5
402	Arroz agulha cru	Cereais e produtos à base de cereais	arroz agulha cru	347	0.4	0.1	78.1	0	2.1	6.7	0
400	Arroz carolino branqueado cru	Cereais e produtos à base de cereais	arroz carolino branqueado cru	357	0.5	0.1	79.6	0	2.2	7.4	0
403	Arroz cozido simples	Cereais e produtos à base de cereais	arroz cozido simples	125	0.2	0	28	0	0.8	2.5	0.8
1058	Arroz de bacalhau	Pratos compostos	arroz de bacalhau	90	1.6	0.2	15.3	1.4	0.9	3.1	0.4
1059	Arroz de bacalhau com margarina	Pratos compostos	arroz de bacalhau com margarina	91	2.1	1	12.2	0.8	0.7	5.4	1
1096	Arroz de cabidela	Pratos compostos	arroz de cabidela	105	1.9	0.3	12.2	0.3	0.5	9.4	0.5
405	Arroz de cenoura com azeite	Pratos compostos	arroz de cenoura com azeite	127	4.2	0.6	19.9	0.9	1.1	1.8	0.7
1091	Arroz de ervilhas	Pratos compostos	arroz de ervilhas	85	0.2	0.1	18	0.2	1	2.3	0.3
1093	Arroz de feijão	Pratos compostos	arroz de feijao	139	4.4	0.6	20.8	0.4	1.9	3.1	0.4
958	Arroz de frango	Pratos compostos	arroz de frango	205	7.6	1.5	25.2	0.7	1	8.4	0.9
1098	Arroz de frango com feijão e chouriço	Pratos compostos	arroz de frango com feijao e chourico	116	3.4	1.4	8.8	0.4	1.4	10.9	0.3
1097	Arroz de frango malandrinho à moda de Monção	Pratos compostos	arroz de frango malandrinho a moda de moncao	132	5.8	1.3	9.3	0.2	0.4	10.5	0.6
1041	Arroz de gambas	Pratos compostos	arroz de gambas	94	3.4	0.5	8.8	0.6	0.5	6.9	0.2
1060	Arroz de lulas	Pratos compostos	arroz de lulas	66	2.1	0.7	6.7	0.4	0.4	4.8	0.6
404	Arroz de manteiga	Pratos compostos	arroz de manteiga	265	7.7	4.3	44.4	0.1	1.2	3.8	0.9
1040	Arroz de marisco	Pratos compostos	arroz de marisco	72	1.4	0.3	8.2	0.4	0.4	6.5	0.7
1099	Arroz de pato	Pratos compostos	arroz de pato	115	4.2	1.3	8.4	0.1	0.3	10.8	0.5
408	Arroz de peixe	Pratos compostos	arroz de peixe	125	3.7	0.6	15.5	0.7	0.7	7	0.6
1061	Arroz de peixe com ervilhas	Pratos compostos	arroz de peixe com ervilhas	110	0.8	0.1	19.8	0.7	1.9	4.9	0.6
924	Arroz de polvo com azeite	Pratos compostos	arroz de polvo com azeite	127	4.6	0.7	10.9	0.2	0.4	10.2	0.6
1062	Arroz de polvo com tomate	Pratos compostos	arroz de polvo com tomate	128	7.1	1.1	10	0.5	0.6	5.7	0.9
1063	Arroz de polvo com tomate e vinho	Pratos compostos	arroz de polvo com tomate e vinho	90	3.6	0.6	6.9	0.5	0.4	6.5	0.7
1065	Arroz de tamboril	Pratos compostos	arroz de tamboril	87	3.8	0.5	7.1	0.7	0.6	5.7	0.5
1064	Arroz de tamboril malandrinho	Pratos compostos	arroz de tamboril malandrinho	67	0.2	0	10	0.6	0.6	5.9	0.5
407	Arroz de tomate com azeite	Pratos compostos	arroz de tomate com azeite	129	4.2	0.6	20.1	1.7	1.2	2	0.7
406	Arroz de tomate com margarina	Pratos compostos	arroz de tomate com margarina	122	3.4	1.6	20.2	1.7	1.2	2	0.8
1090	Arroz de tomate malandrinho	Pratos compostos	arroz de tomate malandrinho	132	6	0.9	16.8	1.5	1.2	1.9	0.8
499	Arroz doce	Leite e produtos lácteos	arroz doce	233	3.8	1.2	45.2	29.1	0.4	4.4	0.1
401	Arroz integral cru	Cereais e produtos à base de cereais	arroz integral cru	351	2.5	0.5	71.6	0	3.8	8.6	0
814	Atum conserva em óleo	Peixes, mariscos, anfíbios, répteis e invertebrados	atum conserva em oleo	214	13	0.9	0	0	0	24.3	1.1
1159	Atum de cebolada	Pratos compostos	atum de cebolada	135	9	1.6	2.6	2.2	1	9	0
811	Atum fresco cru	Peixes, mariscos, anfíbios, répteis e invertebrados	atum fresco cru	138	1.7	0.6	0	0	0	30.7	0.1
812	Atum fresco grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	atum fresco grelhado	166	5.8	2	0	0	0	28.4	0.8
813	Atum fresco, bife estufado com azeite e vinho	Peixes, mariscos, anfíbios, répteis e invertebrados	atum fresco, bife estufado com azeite e vinho	196	10.1	2.4	0.2	0.2	0	23.1	0.8
702	Avelã, miolo	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	avela, miolo	689	66.3	4.9	6	3.9	6.1	14	0
395	Azeite (4 marcas)	Óleos e gorduras de origem animal e vegetal e seus derivados	azeite (4 marcas)	899	99.9	14.4	0	0	0	0	0
703	Azeitona	Frutos e produtos derivados de frutos	azeitona	164	16.8	2.6	0	0	4	1.3	5.3
809	Bacalhau à Brás	Pratos compostos	bacalhau a bras	164	10.1	1.5	8.3	0.8	0.8	9.5	1.4
1044	Bacalhau à Brás com azeite	Pratos compostos	bacalhau a bras com azeite	195	14.7	2.3	6.5	0.8	0.8	8.7	1.4
1045	Bacalhau à Brás com azeite e azeitonas	Pratos compostos	bacalhau a bras com azeite e azeitonas	93	3.6	0.8	6.5	1.2	1.1	8	1.2
810	Bacalhau à Gomes de Sá	Pratos compostos	bacalhau a gomes de sa	139	6.3	1	13.1	1.5	1.4	6.7	1.3
1047	Bacalhau à Gomes de Sá, com azeite	Pratos compostos	bacalhau a gomes de sa, com azeite	160	10.4	1.6	7.4	1.1	1.1	8.6	1.6
807	Bacalhau assado no forno com azeite	Peixes, mariscos, anfíbios, répteis e invertebrados	bacalhau assado no forno com azeite	136	4.9	0.7	0.8	0.6	0.3	20.8	3.4
1038	Bacalhau com natas	Pratos compostos	bacalhau com natas	98	2.6	1.4	9.2	1.6	1	9	1.5
1039	Bacalhau com natas, com queijo ralado	Pratos compostos	bacalhau com natas, com queijo ralado	167	12.6	6.3	7.6	2.1	0.9	5.3	0.9
805	Bacalhau cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	bacalhau cozido	106	0.1	0	0	0	0	26.2	3.1
803	Bacalhau fresco cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	bacalhau fresco cozido	84	0.8	0.1	0	0	0	19.1	0.8
802	Bacalhau fresco cru	Peixes, mariscos, anfíbios, répteis e invertebrados	bacalhau fresco cru	76	0.5	0.1	0	0	0	17.8	0.2
806	Bacalhau grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	bacalhau grelhado	123	0.2	0	0	0	0	30.2	3.1
804	Bacalhau seco e salgado, demolhado cru	Peixes, mariscos, anfíbios, répteis e invertebrados	bacalhau seco e salgado, demolhado cru	80	0.4	0.1	0	0	0	19	3.7
808	Bacalhau, filetes fritos	Peixes, mariscos, anfíbios, répteis e invertebrados	bacalhau, filetes fritos	194	10.7	1.5	5.1	0.1	0.2	19.2	2.9
1900000061	Bacalhau, ovas cruas	Peixes, mariscos, anfíbios, répteis e invertebrados	bacalhau, ovas cruas	104	1.9	0.4	0	0	0	21.7	0.3
311	Bacon	Carne e produtos cárneos	bacon	367	34.6	11.9	0	0	0	13.8	3
312	Bacon, grelhado	Carne e produtos cárneos	bacon, grelhado	372	31.5	10.8	0	0	0	22.2	4.3
2122000013	Bagas goji secas	Produtos hortícolas e derivados	bagas goji secas	303	2.8	0.4	51.8	39.6	12.8	11.2	1
636	Banana	Frutos e produtos derivados de frutos	banana	97	0	0.1	22.1	17.5	1.1	1.4	0
313	Banha de porco	Óleos e gorduras de origem animal e vegetal e seus derivados	banha de porco	896	99.5	26.3	0	0	0	0	0
738	Base em pó para bebida de ananás	Água e bebidas à base de água	base em po para bebida de ananas	369	0	0	89.5	89.5	0	0	0
743	Base em pó para bebida de laranja	Água e bebidas à base de água	base em po para bebida de laranja	375	0	0	88.9	88.9	0	0	0
588	Batata assada com pele, sem sal (só a polpa)	Raízes amiláceas ou tubérculos e seus produtos, plantas sacarinas	batata assada com pele, sem sal (so a polpa)	90	0	0	19.2	1.2	1.7	2.5	0
587	Batata assada no forno	Raízes amiláceas ou tubérculos e seus produtos, plantas sacarinas	batata assada no forno	159	4.8	0.6	24.8	1.6	2.1	3.2	1.4
586	Batata cozida	Raízes amiláceas ou tubérculos e seus produtos, plantas sacarinas	batata cozida	59	0	0	12.4	0.8	1.8	1.5	0.3
585	Batata crua	Raízes amiláceas ou tubérculos e seus produtos, plantas sacarinas	batata crua	90	0	0	19.2	1.2	1.6	2.5	0
594	Batata doce assada	Raízes amiláceas ou tubérculos e seus produtos, plantas sacarinas	batata doce assada	123	0	0	28.3	7.9	3	1	0.1
593	Batata doce crua	Raízes amiláceas ou tubérculos e seus produtos, plantas sacarinas	batata doce crua	123	0	0	28.3	7.9	2.7	1	0.1
590	Batata estufada com cebola, azeite e óleo alimentar	Pratos compostos	batata estufada com cebola, azeite e oleo alimentar	97	3.1	0.4	14.5	1.2	1.4	2	0.8
591	Batata frita caseira (em palitos)	Pratos compostos	batata frita caseira (em palitos)	227	10.8	1.4	27.6	1.7	2.4	3.7	0
592	Batata frita, de pacote (em rodelas)	Pratos compostos	batata frita, de pacote (em rodelas)	543	38.1	14.7	39	0.6	10.7	5.7	1.2
453	Batata, fécula	Ingredientes principais isolados, aditivos, aromas, fermentos e auxiliares tecnológicos	batata, fecula	345	0.3	0	85	3.1	0.1	0.5	0
763	Bebida refrigerante, cola	Água e bebidas à base de água	bebida refrigerante, cola	32	0	0	7.9	7.9	0	0	0
764	Bebida refrigerante, cola sem açúcar	Água e bebidas à base de água	bebida refrigerante, cola sem acucar	0	0	0	0	0	0	0	0
765	Bebida refrigerante, gasosa	Água e bebidas à base de água	bebida refrigerante, gasosa	28	0	0	7	7	0	0	0
766	Bebida refrigerante, laranja	Água e bebidas à base de água	bebida refrigerante, laranja	31	0	0	7.7	7.7	0	0	0
250002	Bebida vegetal à base de amêndoa (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de amendoa (alternativa ao leite)	29	1.3	0.1	3.7	2.9	0.2	0.4	0.1
250001	Bebida vegetal à base de amêndoa, 0% açúcares (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de amendoa, 0% acucares (alternativa ao leite)	17	1.5	0.1	0.3	0.1	0.1	0.4	0.1
250003	Bebida vegetal à base de amêndoa, com aroma a chocolate (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de amendoa, com aroma a chocolate (alternativa ao leite)	49	1.4	0.1	8.4	7.8	0	0.7	0.1
240006	Bebida vegetal à base de arroz (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de arroz (alternativa ao leite)	51	0.9	0.2	10.6	5.8	0.3	0.2	0.1
240007	Bebida vegetal à base de aveia (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de aveia (alternativa ao leite)	46	1.2	0.2	8.2	5.3	0.2	0.6	0.1
240008	Bebida vegetal à base de aveia, 0% de açúcar (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de aveia, 0% de acucar (alternativa ao leite)	36	1.2	0.2	6	1.4	0.3	0.2	0.1
240009	Bebida vegetal à base de aveia, com açúcares adicionados (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de aveia, com acucares adicionados (alternativa ao leite)	59	3.3	0.5	6	3.1	1	0.7	0.1
240005	Bebida vegetal à base de soja (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de soja (alternativa ao leite)	49	2.2	0.4	4.1	3	0.2	3	0.1
543	Bebida vegetal à base de soja com açúcar, com cálcio, sal e aromas (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de soja com acucar, com calcio, sal e aromas (alternativa ao leite)	42	1.6	0.2	3.3	3.3	1.2	3	0.4
544	Bebida vegetal à base de soja com açúcar, sal e aromas (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de soja com acucar, sal e aromas (alternativa ao leite)	59	2.2	0.4	6.7	6	0.2	3	0.1
542	Bebida vegetal à base de soja natural, sem açúcar e sem sal (alternativa ao leite)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	bebida vegetal a base de soja natural, sem acucar e sem sal (alternativa ao leite)	37	2.2	0.4	1.3	0.8	0.2	3.1	0.1
1900000028	Beldroega crua	Produtos hortícolas e derivados	beldroega crua	13	0	0	1	1	2.5	1	0.1
920	Berbigão aberto ao natural sem sal	Peixes, mariscos, anfíbios, répteis e invertebrados	berbigao aberto ao natural sem sal	118	1.4	0.3	5.4	0	0	21	1.9
919	Berbigão cru	Peixes, mariscos, anfíbios, répteis e invertebrados	berbigao cru	59	0.7	0.1	2.7	0	0	10.5	1
619	Beringela crua	Produtos hortícolas e derivados	beringela crua	21	0.2	0	2.4	2.2	2.5	1.1	0
620	Beringela grelhada com azeite	Produtos hortícolas e derivados	beringela grelhada com azeite	99	7.1	1	4.3	3.9	4.4	2	1.1
1920000019	Besugo cru	Peixes, mariscos, anfíbios, répteis e invertebrados	besugo cru	102	2.7	0.7	0	0	0	19.5	0.3
596	Beterraba (raiz) cozida sem sal	Produtos hortícolas e derivados	beterraba (raiz) cozida sem sal	23	0	0	3.4	3.4	2.5	1	0.1
595	Beterraba (raiz) crua	Produtos hortícolas e derivados	beterraba (raiz) crua	23	0	0	3.5	3.5	2.6	1	0.2
460	Biscoitos caseiros	Cereais e produtos à base de cereais	biscoitos caseiros	423	11	4.7	73.4	32	1.9	6.7	0.2
456	Biscoitos limão	Cereais e produtos à base de cereais	biscoitos limao	382	4.4	1.4	77.9	24	1.8	6.7	0.1
455	Biscoitos, argolas	Cereais e produtos à base de cereais	biscoitos, argolas	451	16.5	6.2	69.7	25.9	1.1	5.4	0.6
457	Biscoitos, línguas de gato	Cereais e produtos à base de cereais	biscoitos, linguas de gato	377	1.8	0.7	84.1	37.5	1.8	5.2	0.1
458	Biscoitos, línguas de veado	Cereais e produtos à base de cereais	biscoitos, linguas de veado	474	20.7	8	65.1	28.2	1.8	5.8	0.6
459	Biscoitos, palitos la Reine	Cereais e produtos à base de cereais	biscoitos, palitos la reine	381	7.2	3.4	66.6	36.7	1.8	11.5	0.2
472	Bola de Berlim sem creme	Cereais e produtos à base de cereais	bola de berlim sem creme	402	21.5	7	43.7	8.5	3	6.8	0.7
464	Bolacha "Belga"	Cereais e produtos à base de cereais	bolacha "belga"	487	19.6	9.5	70.1	28.4	1	7.1	0.1
466	Bolacha "Cream cracker"	Cereais e produtos à base de cereais	bolacha "cream cracker"	442	16.2	6.9	61.6	0	3.1	10.8	0.9
463	Bolacha "waffer" baunilha	Cereais e produtos à base de cereais	bolacha "waffer" baunilha	564	36.4	15.7	55.3	30.5	1	3.2	0.1
461	Bolacha água e sal	Cereais e produtos à base de cereais	bolacha agua e sal	437	12.6	5.4	71	5	2.6	8.7	1.4
462	Bolacha aveia	Cereais e produtos à base de cereais	bolacha aveia	443	18.3	8	57.5	3	4	10	3.1
465	Bolacha chocolate	Cereais e produtos à base de cereais	bolacha chocolate	510	23.4	14.7	67.3	33.2	3	6	0.2
467	Bolacha integral (trigo)	Cereais e produtos à base de cereais	bolacha integral (trigo)	450	15.6	7	65.6	3	6	8.8	1.6
468	Bolacha manteiga	Cereais e produtos à base de cereais	bolacha manteiga	483	21.3	11.3	65.2	18.3	3	6.2	0.1
469	Bolacha Maria	Cereais e produtos à base de cereais	bolacha maria	436	12.2	5.9	72	21.5	2.1	8.4	1.1
470	Bolacha torrada	Cereais e produtos à base de cereais	bolacha torrada	437	14.4	7	68.5	20.5	2.1	7.3	0.4
479	Bolo-Rei	Cereais e produtos à base de cereais	bolo-rei	407	14.9	5.9	57.4	17	2.1	7.9	0.8
473	Bolo de arroz	Cereais e produtos à base de cereais	bolo de arroz	391	19.2	5.1	48.1	27.1	1.5	5.8	0.4
474	Bolo de bolacha Maria	Cereais e produtos à base de cereais	bolo de bolacha maria	389	20.7	11.2	46.3	27.1	0.8	3.9	0.8
475	Bolo de chocolate	Cereais e produtos à base de cereais	bolo de chocolate	463	26.4	11.1	47	26.8	3.8	7.4	1.1
476	Bolo de coco	Cereais e produtos à base de cereais	bolo de coco	454	31	21.5	37.8	32.7	3.4	4.2	0.7
477	Bolo ferradura	Cereais e produtos à base de cereais	bolo ferradura	351	4.1	1.4	71.6	26.8	1.9	5.9	0.4
478	Bolo inglês	Cereais e produtos à base de cereais	bolo ingles	380	13.9	6.6	57	37.8	3.2	5.1	0.6
1147	Borrego, perna no forno	Carne e produtos cárneos	borrego, perna no forno	168	7.6	2.7	0.4	0.2	0.1	21.9	1
122	Borrego, perna ou costeleta assada com azeite e margarina	Carne e produtos cárneos	borrego, perna ou costeleta assada com azeite e margarina	234	15.6	5.5	0	0	0	23.3	1.4
123	Borrego, perna ou costeleta assada com margarina	Carne e produtos cárneos	borrego, perna ou costeleta assada com margarina	224	14.5	6.9	0	0	0	23.3	1.6
124	Borrego, perna ou costeleta assada com margarina, sem molho	Carne e produtos cárneos	borrego, perna ou costeleta assada com margarina, sem molho	166	7.6	3.4	0	0	0	24.5	0.4
116	Borrego, perna ou costeleta assada sem molho	Carne e produtos cárneos	borrego, perna ou costeleta assada sem molho	168	8	3.5	0	0	0	24.1	0.4
102	Borrego, perna ou costeleta cozida	Carne e produtos cárneos	borrego, perna ou costeleta cozida	157	5.7	2.5	0	0	0	26.5	0.4
96	Borrego, perna ou costeleta crua	Carne e produtos cárneos	borrego, perna ou costeleta crua	124	5	2.2	0	0	0	19.7	0.2
111	Borrego, perna ou costeleta estufada com azeite e margarina	Pratos compostos	borrego, perna ou costeleta estufada com azeite e margarina	183	12	4.2	1.6	1.5	0.6	16.2	1
112	Borrego, perna ou costeleta estufada com margarina	Pratos compostos	borrego, perna ou costeleta estufada com margarina	175	11.1	5.3	1.6	1.5	0.6	16.2	1.1
105	Borrego, perna ou costeleta estufada sem molho	Carne e produtos cárneos	borrego, perna ou costeleta estufada sem molho	185	9.2	4.1	0	0	0	25.5	0.6
113	Borrego, perna ou costeleta grelhada	Carne e produtos cárneos	borrego, perna ou costeleta grelhada	152	5.5	2.4	0	0	0	25.7	0.5
730	Brandy	Bebidas alcoólicas	brandy	246	0	0	0	0	0	0	0
551	Brócolos cozidos	Produtos hortícolas e derivados	brocolos cozidos	29	0.3	0	2.2	1	3	2.9	0.3
550	Brócolos crus	Produtos hortícolas e derivados	brocolos crus	32	0.8	0.1	1.5	1.2	2.6	3.4	0
2122000006	Bulgur	Cereais e produtos à base de cereais	bulgur	344	1.9	0.3	65.6	2.7	8	12.1	0
1900000100	Búzio cru	Peixes, mariscos, anfíbios, répteis e invertebrados	buzio cru	82	0.2	0	2.3	0	0	17.8	1
126	Cabrito, costeleta crua	Carne e produtos cárneos	cabrito, costeleta crua	120	2.7	0.8	0	0	0	23.9	0.2
136	Cabrito, costeleta grelhada	Carne e produtos cárneos	cabrito, costeleta grelhada	151	3	0.9	0	0	0	30.9	0.5
127	Cabrito, peito cru	Carne e produtos cárneos	cabrito, peito cru	116	3.8	1.2	0	0	0	20.5	0.2
132	Cabrito, peito estufado com azeite e margarina	Pratos compostos	cabrito, peito estufado com azeite e margarina	173	8.4	2.6	0.8	0.5	0.3	23.3	1.1
133	Cabrito, peito estufado com azeite e óleo alimentar	Pratos compostos	cabrito, peito estufado com azeite e oleo alimentar	176	8.8	1.9	0.7	0.5	0.3	23.3	1
130	Cabrito, peito estufado com manteiga e óleo alimentar	Pratos compostos	cabrito, peito estufado com manteiga e oleo alimentar	173	8.4	2.6	0.8	0.6	0.3	23.3	1.1
131	Cabrito, peito estufado com margarina e óleo alimentar	Pratos compostos	cabrito, peito estufado com margarina e oleo alimentar	173	8.4	2.5	0.8	0.5	0.3	23.3	1.1
129	Cabrito, peito estufado, sem molho	Carne e produtos cárneos	cabrito, peito estufado, sem molho	153	4.4	1.4	0	0	0	28.4	0.5
137	Cabrito, peito grelhado	Carne e produtos cárneos	cabrito, peito grelhado	144	4.2	1.3	0	0	0	26.5	0.5
140	Cabrito, perna assada com azeite e margarina	Carne e produtos cárneos	cabrito, perna assada com azeite e margarina	180	10	2.9	0.2	0.1	0	21.7	1.2
138	Cabrito, perna assada com óleo alimentar e margarina	Carne e produtos cárneos	cabrito, perna assada com oleo alimentar e margarina	180	10	2.8	0.2	0.1	0	21.7	1.2
139	Cabrito, perna assada, sem molho	Carne e produtos cárneos	cabrito, perna assada, sem molho	135	4.2	1.3	0	0	0	24.3	0.9
128	Cabrito, perna crua	Carne e produtos cárneos	cabrito, perna crua	113	4	1.2	0	0	0	19.3	0.2
815	Cação cru	Peixes, mariscos, anfíbios, répteis e invertebrados	cacao cru	82	0.2	0	0	0	0	20	0.4
816	Cação frito	Peixes, mariscos, anfíbios, répteis e invertebrados	cacao frito	170	7	0.8	2.7	0.1	0.1	24	1.2
505	Cacau em pó	Café, cacau, chá e tisanas	cacau em po	358	23.4	13.8	11.1	0	12.1	19.6	0.1
2120000014	Cachucho cru	Peixes, mariscos, anfíbios, répteis e invertebrados	cachucho cru	80	0.7	0.1	0	0	0	18.3	0.2
771	Café solúvel em pó	Café, cacau, chá e tisanas	cafe soluvel em po	272	0.5	0.2	41.1	3	21.5	14.9	0.1
773	Café solúvel, descafeinado, pó	Café, cacau, chá e tisanas	cafe soluvel, descafeinado, po	274	0.2	0.1	42.6	3	21.5	14.7	0.1
767	Café, infusão - bica	Café, cacau, chá e tisanas	cafe, infusao - bica	4	0.1	0	0.3	0	0	0.4	0
769	Café, infusão - café de cafeteira	Café, cacau, chá e tisanas	cafe, infusao - cafe de cafeteira	2	0	0	0.3	0	0	0.2	0
768	Café, infusão - carioca	Café, cacau, chá e tisanas	cafe, infusao - carioca	2	0	0	0.3	0	0	0.2	0
770	Café, infusão - valor médio (bica 60% e café de cafeteira 40%)	Café, cacau, chá e tisanas	cafe, infusao - valor medio (bica 60% e cafe de cafeteira 40%)	3	0.1	0	0.3	0	0	0.3	0
1050	Caldeirada de bacalhau	Pratos compostos	caldeirada de bacalhau	67	2.1	1	7.1	2	1.2	4.2	0.9
1049	Caldeirada de bacalhau com enchidos e massa	Pratos compostos	caldeirada de bacalhau com enchidos e massa	146	8.5	2.8	9.7	2	1.5	7	1.3
134	Caldeirada de cabrito com azeite e banha	Pratos compostos	caldeirada de cabrito com azeite e banha	119	4.3	1.1	8.3	0.9	0.9	11.3	0.8
135	Caldeirada de cabrito com azeite e margarina	Pratos compostos	caldeirada de cabrito com azeite e margarina	116	4	1.3	8.3	0.9	0.9	11.3	0.9
833	Caldeirada de enguias	Pratos compostos	caldeirada de enguias	171	11.9	3.5	8.2	1.7	1.1	6.6	0.6
1048	Caldeirada de enguias à moda de Aveiro	Pratos compostos	caldeirada de enguias a moda de aveiro	245	21.4	5.8	5.3	0.7	0.7	7.4	0.7
1052	Caldeirada de pargo e peixe-espada-preto	Pratos compostos	caldeirada de pargo e peixe-espada-preto	138	9.8	1.5	4.4	1.3	0.8	7.2	0.7
1053	Caldeirada de peixe	Pratos compostos	caldeirada de peixe	84	3.5	0.5	4.4	1.3	0.8	7.5	0.8
1127	Caldeirada de safio	Pratos compostos	caldeirada de safio	81	3.1	0.6	7.2	1.9	1.3	4.5	0.7
1051	Caldeirada de safio com amêijoas	Pratos compostos	caldeirada de safio com ameijoas	80	2.7	0.5	5.8	1.4	0.9	6.9	0.4
895	Caldeirada de safio, raia e tamboril	Pratos compostos	caldeirada de safio, raia e tamboril	98	2.9	0.4	9.8	1.8	1.3	7	0.9
300	Caldo preparado com cubo de carne de galinha (diluição 2%)	Temperos, molhos e condimentos	caldo preparado com cubo de carne de galinha (diluicao 2%)	5	0.3	0.1	0.2	0	0	0.3	0.8
299	Caldo preparado com cubo de carne de vaca (diluição 2%)	Temperos, molhos e condimentos	caldo preparado com cubo de carne de vaca (diluicao 2%)	4	0.2	0.1	0.2	0	0	0.4	0.8
971	Camarão cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	camarao cozido	99	0.8	0.2	0.4	0	0	22.6	4
970	Camarão cozido sem sal	Peixes, mariscos, anfíbios, répteis e invertebrados	camarao cozido sem sal	92	1.1	0.2	0.3	0	0	20.2	0.6
969	Camarão cru	Peixes, mariscos, anfíbios, répteis e invertebrados	camarao cru	77	0.6	0.1	0.3	0	0	17.6	0.5
549	Canela moída	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	canela moida	315	3.2	0.7	55.5	55.5	24.4	3.9	0.1
1116	Canja de frango com aipo	Pratos compostos	canja de frango com aipo	56	1.7	0.5	2.3	0.2	0.2	7.8	0.7
1117	Canja de frango com massa	Pratos compostos	canja de frango com massa	61	1	0.2	2.1	0.1	0.2	10.8	0.2
1900000026	Canónigos crus	Produtos hortícolas e derivados	canonigos crus	24	0.4	0.1	2	2	2.1	2	0
904	Cantarilho (Redfish) assado com cebola, tomate, azeite e bacon	Pratos compostos	cantarilho (redfish) assado com cebola, tomate, azeite e bacon	142	8.6	1.5	1.2	1.1	0.4	13.6	0.9
1160	Cantarilho (Redfish) com batata, no forno	Peixes, mariscos, anfíbios, répteis e invertebrados	cantarilho (redfish) com batata, no forno	108	4.9	0.9	5.7	1.9	1.1	8.7	0.5
903	Cantarilho (Redfish) cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	cantarilho (redfish) cozido	99	2.4	0.5	0	0	0	19.3	0.9
902	Cantarilho (Redfish) cru	Peixes, mariscos, anfíbios, répteis e invertebrados	cantarilho (redfish) cru	101	2.9	0.5	0	0	0	18.6	0.2
1161	Cantarilho (Redfish) no forno	Peixes, mariscos, anfíbios, répteis e invertebrados	cantarilho (redfish) no forno	114	2.7	0.5	1.1	1	0.5	17.3	1
250013	Caracol riscado, cozido	Anfíbios, répteis, e invertebrados terrestres	caracol riscado, cozido	89	3.9	0.6	3.5	0	0	10	0.2
1900000115	Caracol, cru	Anfíbios, répteis, e invertebrados terrestres	caracol, cru	85	1.4	0.2	2	0	0	16.1	0.2
623	Carambola	Frutos e produtos derivados de frutos	carambola	40	0.3	0	7.1	6.9	1.7	0.5	0
817	Carapau cru	Peixes, mariscos, anfíbios, répteis e invertebrados	carapau cru	105	2.9	0.7	0	0	0	19.7	0.2
819	Carapau frito	Peixes, mariscos, anfíbios, répteis e invertebrados	carapau frito	186	9.6	1.5	1	0	0	24	1.3
818	Carapau grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	carapau grelhado	139	3.7	0.9	0	0	0	26.3	1.1
1900000044	Cardamomo verde	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	cardamomo verde	335	6.2	0.7	49.5	5.2	19	10.8	0.9
1193	Caril em pó	Temperos, molhos e condimentos	caril em po	342	13.8	2	25.2	25.2	33.2	12.7	0.1
1027	Carne à bolonhesa	Pratos compostos	carne a bolonhesa	238	14	5.4	15.6	1.8	1.5	11.5	0.9
1028	Carne à jardineira	Pratos compostos	carne a jardineira	140	8.1	2.6	5.6	1.7	3.1	9.7	0.7
1030	Carne de porco à alentejana	Pratos compostos	carne de porco a alentejana	229	16.9	5.1	1.8	0.5	0.3	14.6	1.2
1029	Carne de porco à alentejana sem massa de pimentão	Pratos compostos	carne de porco a alentejana sem massa de pimentao	183	11.8	3.6	2.2	0.2	0.1	16	1.3
97	Carneiro, costeleta crua	Carne e produtos cárneos	carneiro, costeleta crua	151	7.5	3.2	0	0	0	20.8	0.2
119	Carneiro, pá assada com azeite e margarina	Carne e produtos cárneos	carneiro, pa assada com azeite e margarina	319	24.6	9.3	0	0	0	24.3	1.4
118	Carneiro, pá assada com margarina	Carne e produtos cárneos	carneiro, pa assada com margarina	310	23.6	10.7	0	0	0	24.3	1.6
117	Carneiro, pá assada, sem molho	Carne e produtos cárneos	carneiro, pa assada, sem molho	202	11.3	4.9	0	0	0	25.1	0.4
104	Carneiro, pá cozida	Carne e produtos cárneos	carneiro, pa cozida	238	14.2	6.1	0	0	0	27.6	0.4
98	Carneiro, pá crua	Carne e produtos cárneos	carneiro, pa crua	195	12.6	5.4	0	0	0	20.5	0.2
107	Carneiro, pá estufada sem molho	Carne e produtos cárneos	carneiro, pa estufada sem molho	238	14.2	6.1	0	0	0	27.6	0.6
103	Carneiro, peito gordo, cozido	Carne e produtos cárneos	carneiro, peito gordo, cozido	333	26.6	11.5	0	0	0	23.3	0.5
99	Carneiro, peito gordo, cru	Carne e produtos cárneos	carneiro, peito gordo, cru	396	36.5	15.7	0	0	0	16.8	0.3
115	Carneiro, perna gorda, assada, sem molho	Carne e produtos cárneos	carneiro, perna gorda, assada, sem molho	285	20.9	9	0	0	0	24.3	0.4
100	Carneiro, perna gorda, crua	Carne e produtos cárneos	carneiro, perna gorda, crua	276	22.2	9.6	0	0	0	19.1	0.2
106	Carneiro, perna gorda, estufada sem molho	Carne e produtos cárneos	carneiro, perna gorda, estufada sem molho	339	25.9	11.2	0	0	0	26.5	0.6
121	Carneiro, perna magra assada com azeite e margarina	Carne e produtos cárneos	carneiro, perna magra assada com azeite e margarina	242	16.4	5.8	0	0	0	23.5	1.5
120	Carneiro, perna magra assada com margarina	Carne e produtos cárneos	carneiro, perna magra assada com margarina	232	15.3	7.2	0	0	0	23.5	1.7
114	Carneiro, perna magra, assada, sem molho	Carne e produtos cárneos	carneiro, perna magra, assada, sem molho	178	9	3.9	0	0	0	24.2	0.6
101	Carneiro, perna magra, crua	Carne e produtos cárneos	carneiro, perna magra, crua	130	5.6	2.4	0	0	0	19.8	0.3
110	Carneiro, perna magra, estufada com azeite e margarina	Carne e produtos cárneos	carneiro, perna magra, estufada com azeite e margarina	201	13.4	4.6	1.7	1.6	0.6	17.4	1.1
109	Carneiro, perna magra, estufada com margarina	Pratos compostos	carneiro, perna magra, estufada com margarina	193	12.5	5.9	1.7	1.6	0.6	17.4	1.2
108	Carneiro, perna magra, estufada sem molho	Carne e produtos cárneos	carneiro, perna magra, estufada sem molho	195	10.3	4.5	0	0	0	25.6	0.7
125	Carneiro, perna ou costeleta magra frita com margarina, sem molho	Carne e produtos cárneos	carneiro, perna ou costeleta magra frita com margarina, sem molho	174	8.4	3.7	0	0	0	24.7	0.6
332	Carneiro, rim cru	Carne e produtos cárneos	carneiro, rim cru	92	3	1.3	0	0	0	16.2	0.4
333	Carneiro, rim frito com margarina	Carne e produtos cárneos	carneiro, rim frito com margarina	205	12.9	6.2	0	0	0	22.3	1.8
1900000084	Caseína	Ingredientes principais isolados, aditivos, aromas, fermentos e auxiliares tecnológicos	caseina	358	1.5	1	0	0	0	86.2	0
706	Castanha assada com sal	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	castanha assada com sal	222	1.3	0.2	45.5	11.2	7	3.5	1.4
1900000054	Castanha cozida sem sal	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	castanha cozida sem sal	175	1	0.2	35.9	8.8	5.5	2.8	0
704	Castanha de caju torrada e salgada	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	castanha de caju torrada e salgada	613	50	9.9	19.4	5.9	3.3	19.6	0.8
1900000052	Castanha de caju torrada, sem sal	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	castanha de caju torrada, sem sal	613	50	9.9	19.4	5.9	3.3	19.6	0
1900000093	Castanha do Brasil	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	castanha do brasil	690	66.7	16	2.6	2.6	20.5	9.6	0
707	Castanha pilada	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	castanha pilada	341	2	0.4	70	17.2	11.3	5.1	0
705	Castanha, miolo	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	castanha, miolo	194	1.1	0.2	39.8	9.8	6.1	3.1	0
821	Cavala cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	cavala cozida	192	12.2	3.2	0	0	0	20.5	0.8
820	Cavala crua	Peixes, mariscos, anfíbios, répteis e invertebrados	cavala crua	202	13.4	3.6	0	0	0	20.3	0.2
822	Cavala em filetes, conserva em azeite	Peixes, mariscos, anfíbios, répteis e invertebrados	cavala em filetes, conserva em azeite	182	9.6	1.5	0	0	0	24	1.6
1128	Cavala grelhada	Peixes, mariscos, anfíbios, répteis e invertebrados	cavala grelhada	192	12.2	3.3	0.6	0.6	0.7	18.5	0.9
1129	Cavala no forno	Peixes, mariscos, anfíbios, répteis e invertebrados	cavala no forno	192	14.3	3.1	2.3	1.6	1	12.9	0.9
141	Cavalo, bife de alcatra crua	Carne e produtos cárneos	cavalo, bife de alcatra crua	116	3.5	1.3	0	0	0	21.1	0.1
144	Cavalo, bife de alcatra frita com manteiga	Carne e produtos cárneos	cavalo, bife de alcatra frita com manteiga	177	9.3	4.5	0	0	0	23.3	1
145	Cavalo, bife de alcatra frita com margarina	Carne e produtos cárneos	cavalo, bife de alcatra frita com margarina	176	9.2	4.1	0	0	0	23.3	1.1
143	Cavalo, bife de alcatra frita, sem molho	Carne e produtos cárneos	cavalo, bife de alcatra frita, sem molho	147	5.4	2.2	0	0	0	24.7	0.6
150	Cavalo, lombo ou pá assado com azeite e manteiga	Carne e produtos cárneos	cavalo, lombo ou pa assado com azeite e manteiga	167	8	2.6	0.1	0.1	0	22.7	1.1
149	Cavalo, lombo ou pá assado com margarina	Carne e produtos cárneos	cavalo, lombo ou pa assado com margarina	161	7.3	3.4	0.1	0.1	0	22.7	1.2
148	Cavalo, lombo ou pá assado sem molho	Carne e produtos cárneos	cavalo, lombo ou pa assado sem molho	136	4.3	1.9	0	0	0	24.2	0.6
142	Cavalo, lombo ou pá cru	Carne e produtos cárneos	cavalo, lombo ou pa cru	99	2.3	0.9	0	0	0	19.6	0.1
146	Cavalo, lombo ou pá frito com manteiga	Carne e produtos cárneos	cavalo, lombo ou pa frito com manteiga	158	8	4.1	0	0	0	21.6	1
147	Cavalo, lombo ou pá frito com margarina	Carne e produtos cárneos	cavalo, lombo ou pa frito com margarina	157	7.8	3.7	0	0	0	21.6	1.1
598	Cebola cozida	Produtos hortícolas e derivados	cebola cozida	18	0.2	0	2.4	1.7	1.4	1	0.3
597	Cebola crua	Produtos hortícolas e derivados	cebola crua	20	0.2	0	3.1	2.2	1.3	0.9	0
220002	Cebola doce, crua	Produtos hortícolas e derivados	cebola doce, crua	25	0	0	4.9	4.8	1.1	0.8	0
599	Cebola frita com óleo alimentar	Produtos hortícolas e derivados	cebola frita com oleo alimentar	138	11.2	1.3	6.2	4.4	2.6	1.9	0.1
220001	Cebola roxa, crua	Produtos hortícolas e derivados	cebola roxa, crua	43	0	0	8.6	5.9	2.7	0.7	0
1194	Cebolinho fresco	Produtos hortícolas e derivados	cebolinho fresco	28	0.6	0.1	1.7	1.7	2.1	2.8	0
1900000018	Cenoura baby crua	Produtos hortícolas e derivados	cenoura baby crua	29	0.1	0	4.9	4.8	2.9	0.6	0.2
601	Cenoura cozida	Produtos hortícolas e derivados	cenoura cozida	33	0	0	5.7	3.3	3.2	0.9	0.3
600	Cenoura crua	Produtos hortícolas e derivados	cenoura crua	25	0	0	4.4	4.1	2.6	0.6	0.1
451	Cereal de pequeno almoço à base de farelo de trigo (tipo "All-Bran")	Cereais e produtos à base de cereais	cereal de pequeno almoco a base de farelo de trigo (tipo "all-bran")	310	3.4	0.6	39.8	14.7	30	15.1	3.7
450	Cereal de pequeno almoço de trigo integral tipo "Weetabix"	Cereais e produtos à base de cereais	cereal de pequeno almoco de trigo integral tipo "weetabix"	364	2	0.3	71.5	6.1	8.5	10.7	0.9
1195	Cerefólio fresco	Produtos hortícolas e derivados	cerefolio fresco	80	1	0	12	0	3.3	4	0
637	Cereja (4 variedades)	Frutos e produtos derivados de frutos	cereja (4 variedades)	67	0.7	0.2	13.3	13.3	1.6	0.8	0
1900000111	Cereja desidratada	Frutos e produtos derivados de frutos	cereja desidratada	366	3.8	1.1	72.6	72.6	8.7	4.4	0
638	Cereja, conserva em calda de açúcar	Frutos e produtos derivados de frutos	cereja, conserva em calda de acucar	120	0.2	0	28.7	28.7	1	0.4	0
641	Cereja, cristalizada	Frutos e produtos derivados de frutos	cereja, cristalizada	326	0.2	0	79.9	79.9	1.6	0.4	0.1
726	Cerveja branca	Bebidas alcoólicas	cerveja branca	30	0	0	0.5	0.5	0	0.4	0
727	Cerveja preta	Bebidas alcoólicas	cerveja preta	23	0	0	0.6	0.6	0	0.5	0
728	Cerveja sem álcool	Bebidas alcoólicas	cerveja sem alcool	7	0	0	1.5	1.2	0	0.3	0
962	Chá, infusão, preto	Café, cacau, chá e tisanas	cha, infusao, preto	1	0	0	0.2	0	0	0.1	0
963	Chá, infusão, verde	Café, cacau, chá e tisanas	cha, infusao, verde	1	0	0	0.2	0	0	0.1	0
369	Chamuça	Pratos compostos	chamuca	344	16.3	7	39.3	1.3	1.7	9.1	1.4
897	Cherne cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	cherne cozido	124	5.4	1.6	0	0	0	18.9	1
896	Cherne cru	Peixes, mariscos, anfíbios, répteis e invertebrados	cherne cru	132	6.7	2	0	0	0	17.9	0.3
898	Cherne grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	cherne grelhado	153	6.3	1.9	0	0	0	24.1	1.2
824	Chicharro cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	chicharro cozido	111	3	0.7	0	0	0	21.1	0.9
823	Chicharro cru	Peixes, mariscos, anfíbios, répteis e invertebrados	chicharro cru	105	2.9	0.7	0	0	0	19.7	0.2
825	Chicharro grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	chicharro grelhado	139	3.7	0.9	0	0	0	26.3	1.1
602	Chicória crua	Produtos hortícolas e derivados	chicoria crua	14	0.1	0	0.9	0.9	2.6	1	0
912	Choco cru	Peixes, mariscos, anfíbios, répteis e invertebrados	choco cru	79	0.4	0.1	0	0	0	18.9	0.5
913	Choco grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	choco grelhado	109	0.6	0.1	0	0	0	25.8	1.3
506	Chocolate culinária, tablete	Açúcar e similares, confeitaria e sobremesas doces à base de água	chocolate culinaria, tablete	502	30.5	19.3	44	44	15	5.4	0
508	Chocolate de leite, tablete	Açúcar e similares, confeitaria e sobremesas doces à base de água	chocolate de leite, tablete	552	33.9	19.8	53.1	53.1	1.3	8	0.3
1900000094	Chocolate negro (aproximadamente 50% cacau)	Açúcar e similares, confeitaria e sobremesas doces à base de água	chocolate negro (aproximadamente 50% cacau)	530	31.7	19.9	52.6	49	7.2	5.2	0
507	Chocolate, pó	Açúcar e similares, confeitaria e sobremesas doces à base de água	chocolate, po	469	20.3	12.8	63.8	60.5	7.3	4.2	0
70500004	Chouriço de carne de porco, cru	Carne e produtos cárneos	chourico de carne de porco, cru	476	44.1	15.2	0	0	0	20	6.2
342	Chouriço de carne de porco, gordo, cru	Carne e produtos cárneos	chourico de carne de porco, gordo, cru	544	53.6	18.5	0	0	0	15.4	6.6
343	Chouriço de carne de porco, magro, cozido sem adição de sal	Carne e produtos cárneos	chourico de carne de porco, magro, cozido sem adicao de sal	334	26.1	9	0	0	0	24.8	5.1
341	Chouriço de carne de porco, magro, cru	Carne e produtos cárneos	chourico de carne de porco, magro, cru	409	34.5	11.9	0	0	0	24.5	5.8
344	Chouriço de carne de porco, magro, grelhado	Carne e produtos cárneos	chourico de carne de porco, magro, grelhado	343	24.1	8.3	0	0	0	31.6	6.8
346	Chouriço de sangue cozido	Carne e produtos cárneos	chourico de sangue cozido	263	24.2	9.4	0	0	0	11.2	2.5
345	Chouriço de sangue, cru	Carne e produtos cárneos	chourico de sangue, cru	328	31.6	12.3	0	0	0	11	2.8
1196	Chuchu	Produtos hortícolas e derivados	chuchu	19	0.1	0	2.9	2.9	1.7	0.8	0
1900000082	Chucrute	Produtos hortícolas e derivados	chucrute	15	0.3	0.1	1.1	1.1	1.1	1.3	1.2
85	Clara de ovo de galinha, crua	Ovos e ovoprodutos	clara de ovo de galinha, crua	47	0.3	0.1	0	0	0	11	0.5
1900000055	Clara de ovo de galinha, pasteurizada	Ovos e ovoprodutos	clara de ovo de galinha, pasteurizada	46	0	0	1	0	0	10.5	0.4
642	Clementina	Frutos e produtos derivados de frutos	clementina	53	0.2	0	11.1	11.1	1.7	0.8	0
643	Coco seco, ralado	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	coco seco, ralado	648	62	53.3	6.4	6.4	21.1	5.6	0.1
302	Codorniz carne sem pele, crua	Carne e produtos cárneos	codorniz carne sem pele, crua	119	3.4	1	0	0	0	22.1	0.1
301	Codorniz com pele, crua	Carne e produtos cárneos	codorniz com pele, crua	170	9.3	2.6	0	0	0	21.5	0.1
303	Codorniz com pele, estufada com azeite	Carne e produtos cárneos	codorniz com pele, estufada com azeite	234	13.4	3.4	0.7	0.3	0.2	25.6	1.3
304	Codorniz com pele, grelhada	Carne e produtos cárneos	codorniz com pele, grelhada	202	11.6	3.2	0	0	0	24.5	0.8
1149	Coelho à caçador	Pratos compostos	coelho a cacador	182	12.7	3.7	1.6	1.4	0.7	12.3	0.6
274	Coelho cru	Carne e produtos cárneos	coelho cru	117	4	1.3	0	0	0	20.3	0.1
1150	Coelho em vinha de alhos	Pratos compostos	coelho em vinha de alhos	174	11.6	1.8	1.4	1.1	0.5	11.3	0.1
70208006	Coelho estufado	Pratos compostos	coelho estufado	211	10.2	1.7	0.9	0.7	0.3	26.6	1.3
276	Coelho estufado com azeite	Pratos compostos	coelho estufado com azeite	218	11	2.5	0.9	0.7	0.3	26.6	1.2
275	Coelho estufado com margarina	Pratos compostos	coelho estufado com margarina	205	9.5	3.8	0.9	0.7	0.3	26.6	1.4
7	Coentros crus	Produtos hortícolas e derivados	coentros crus	28	0.6	0.1	1.8	1.5	2.9	2.4	0.1
604	Cogumelos enlatados, escorridos	Produtos hortícolas e derivados	cogumelos enlatados, escorridos	17	0.4	0.1	0	0	2.7	2.1	0.9
605	Cogumelos fritos com óleo alimentar	Produtos hortícolas e derivados	cogumelos fritos com oleo alimentar	163	16.2	1.8	0.3	0.1	3	2.4	0
250028	Cogumelos marron	Produtos hortícolas e derivados	cogumelos marron	23	0.2	0	1.5	0.1	1.2	3.2	0
250029	Cogumelos ostra (pleurotus)	Produtos hortícolas e derivados	cogumelos ostra (pleurotus)	27	0.2	0	2.7	2.6	2.3	2.4	0
603	Cogumelos, genérico	Produtos hortícolas e derivados	cogumelos, generico	18	0.5	0.1	0.5	0.3	2.3	1.8	0
1197	Colorau	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	colorau	358	13	2.1	35	33.2	20.9	14.8	0.1
1900000045	Cominhos	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	cominhos	427	22	1.9	34	0	10.5	18	0.4
646	Compota de alperce	Frutos e produtos derivados de frutos	compota de alperce	239	0	0	58.9	58.9	0.9	0.4	0
629	Compota de ameixa	Frutos e produtos derivados de frutos	compota de ameixa	200	0	0	49.2	49.2	0.9	0.3	0
634	Compota de ananás	Frutos e produtos derivados de frutos	compota de ananas	211	0.1	0	50.8	50.8	0.8	0.5	0
639	Compota de cereja	Frutos e produtos derivados de frutos	compota de cereja	251	0	0	61.9	61.9	0.9	0.4	0
659	Compota de laranja	Frutos e produtos derivados de frutos	compota de laranja	242	0	0	59.5	59.5	0.9	0.4	0
1210	Condimento de mostarda	Temperos, molhos e condimentos	condimento de mostarda	158	6.4	0.3	18.5	14.5	1.7	5.7	1.9
827	Corvina cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	corvina cozida	95	1.4	0.3	0	0	0	20.7	0.8
826	Corvina crua	Peixes, mariscos, anfíbios, répteis e invertebrados	corvina crua	94	1.4	0.3	0	0	0	20.4	0.1
553	Couve-branca cozida	Produtos hortícolas e derivados	couve-branca cozida	17	0.4	0.1	1.7	1.6	1.7	0.7	0.3
552	Couve-branca crua	Produtos hortícolas e derivados	couve-branca crua	28	0.4	0.1	3.5	3.4	2.4	1.4	0
555	Couve-de-Bruxelas cozida	Produtos hortícolas e derivados	couve-de-bruxelas cozida	34	1.3	0.3	3.5	3	1.9	1.1	0.2
554	Couve-de-Bruxelas crua	Produtos hortícolas e derivados	couve-de-bruxelas crua	50	1.4	0.3	4	3.1	3.8	3.5	0
557	Couve-flor cozida	Produtos hortícolas e derivados	couve-flor cozida	21	0.3	0	2	1.7	1.9	1.6	0.3
556	Couve-flor crua	Produtos hortícolas e derivados	couve-flor crua	34	0.2	0	3.3	2.8	1.9	3.7	0
559	Couve-galega cozida	Produtos hortícolas e derivados	couve-galega cozida	29	0.4	0.1	2.9	2.5	2.7	2.1	0.3
558	Couve-galega crua	Produtos hortícolas e derivados	couve-galega crua	32	0.4	0.1	3.1	2.7	3.1	2.4	0.1
561	Couve-lombarda cozida	Produtos hortícolas e derivados	couve-lombarda cozida	22	0.2	0	1.4	1.3	2.9	2.2	0.3
560	Couve-lombarda crua	Produtos hortícolas e derivados	couve-lombarda crua	26	0.2	0	2.1	2	3.1	2.4	0
563	Couve-portuguesa cozida	Produtos hortícolas e derivados	couve-portuguesa cozida	25	0.4	0	2.5	2.4	2.4	1.6	0.3
562	Couve-portuguesa crua	Produtos hortícolas e derivados	couve-portuguesa crua	31	0.4	0	3.5	3.4	2.4	2.2	0
564	Couve-roxa crua	Produtos hortícolas e derivados	couve-roxa crua	30	0	0	3.9	3.3	3.3	2	0
1020	Cozido à portuguesa	Pratos compostos	cozido a portuguesa	120	7	0.8	6.2	2.2	2.5	6.8	0.8
1021	Cozido à portuguesa com grão	Pratos compostos	cozido a portuguesa com grao	259	13.5	4.5	20.5	1.5	4.1	11.7	0.7
1198	Cravinho	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	cravinho	431	20	1.9	52	0	9.6	6	0.6
2122000014	Creme culinário	Óleos e gorduras de origem animal e vegetal e seus derivados	creme culinario	531	59	31	0	0	0	0	0
383	Creme culinário líquido, 65% gordura, com sal	Óleos e gorduras de origem animal e vegetal e seus derivados	creme culinario liquido, 65% gordura, com sal	588	65.3	8.4	0	0	0	0	3
1119	Creme de camarão	Pratos compostos	creme de camarao	39	1.4	0.7	1.7	0.5	0.3	3.6	0.7
1118	Creme de camarão com natas	Pratos compostos	creme de camarao com natas	51	2.9	1.5	1.9	0.7	0.4	3.5	0.9
1104	Creme de ervilhas	Pratos compostos	creme de ervilhas	43	1.9	0.8	3	1.2	1.5	2.6	0.6
372	Creme para barrar de cacau e avelãs	Açúcar e similares, confeitaria e sobremesas doces à base de água	creme para barrar de cacau e avelas	545	33.3	8.2	54.7	53.4	1.2	5.9	0.1
375	Creme vegetal culinário, 75% gordura, sem sal	Óleos e gorduras de origem animal e vegetal e seus derivados	creme vegetal culinario, 75% gordura, sem sal	677	75	18	0.4	0.4	0	0.1	0
250031	Creme vegetal de soja para barrar	Óleos e gorduras de origem animal e vegetal e seus derivados	creme vegetal de soja para barrar	444	47.6	13.1	3.7	0.1	0	0.2	0.8
250026	Creme vegetal de soja para culinária (alternativa à nata)	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	creme vegetal de soja para culinaria (alternativa a nata)	162	14.3	1.1	5.7	0.9	0.6	2.3	0.1
374	Creme vegetal para barrar  72% gordura, 33% ácidos gordos polinsaturados	Óleos e gorduras de origem animal e vegetal e seus derivados	creme vegetal para barrar  72% gordura, 33% acidos gordos polinsaturados	651	72.1	18.8	0.4	0.4	0	0.1	0.9
376	Creme vegetal para barrar 35% gordura, com fitosteróis	Óleos e gorduras de origem animal e vegetal e seus derivados	creme vegetal para barrar 35% gordura, com fitosterois	328	35	8	3.2	0.2	0	0.1	0.1
378	Creme vegetal para barrar 37% gordura	Óleos e gorduras de origem animal e vegetal e seus derivados	creme vegetal para barrar 37% gordura	343	37.4	10.2	0.2	0.2	0	1.4	0.8
399	Creme vegetal para barrar 58% gordura, com cálcio	Óleos e gorduras de origem animal e vegetal e seus derivados	creme vegetal para barrar 58% gordura, com calcio	525	58	19.1	0.5	0.5	0	0.3	1.5
398	Creme vegetal para barrar 70% gordura, 53% ácidos gordos monoinsaturados	Óleos e gorduras de origem animal e vegetal e seus derivados	creme vegetal para barrar 70% gordura, 53% acidos gordos monoinsaturados	632	70	9.4	0.5	0.5	0	0.1	2.2
377	Creme vegetal para barrar 70% gordura, com sal	Óleos e gorduras de origem animal e vegetal e seus derivados	creme vegetal para barrar 70% gordura, com sal	632	70	30.7	0.3	0.3	0	0.1	3
480	Croissant	Cereais e produtos à base de cereais	croissant	418	22.8	10.4	44.6	0.6	2.4	7.5	1.1
367	Croquete	Pratos compostos	croquete	316	18.8	4.8	23.1	0.5	0.9	13.2	1.6
298	Cubo de carne de galinha para caldo	Temperos, molhos e condimentos	cubo de carne de galinha para caldo	236	15.4	3.6	9	1.8	0	15.4	41
297	Cubo de carne de vaca para caldo	Temperos, molhos e condimentos	cubo de carne de vaca para caldo	183	8	3.1	8	0	0	19.8	38
621	Curgete crua	Produtos hortícolas e derivados	curgete crua	19	0.3	0.1	2	1.9	1	1.6	0
622	Curgete frita com óleo alimentar	Produtos hortícolas e derivados	curgete frita com oleo alimentar	64	4.8	0.6	2.5	2.4	1.3	2	0.8
649	Dióspiro	Frutos e produtos derivados de frutos	diospiro	65	0	0	14.8	14.8	1.5	0.6	0
1900000110	Dióspiro desidratado	Frutos e produtos derivados de frutos	diospiro desidratado	353	0	0	80.8	80.8	8.2	3.3	0.1
647	Doce de alperce	Frutos e produtos derivados de frutos	doce de alperce	233	0	0	57.4	57.4	0.9	0.5	0
640	Doce de cereja	Frutos e produtos derivados de frutos	doce de cereja	262	0	0	64.9	64.9	0.7	0.2	0
654	Doce de framboesa	Frutos e produtos derivados de frutos	doce de framboesa	242	0	0	59.7	59.7	1	0.4	0
656	Doce de ginja	Frutos e produtos derivados de frutos	doce de ginja	263	0	0	64.8	64.8	0.9	0.4	0
664	Doce de maçã	Frutos e produtos derivados de frutos	doce de maca	239	0	0	59	59	0.9	0.2	0
677	Doce de morango	Frutos e produtos derivados de frutos	doce de morango	245	0	0	60.5	60.5	1	0.2	0
687	Doce de pêssego	Frutos e produtos derivados de frutos	doce de pessego	209	0	0	51.3	51.3	1	0.4	0
481	Donut	Cereais e produtos à base de cereais	donut	400	21.7	9.6	43	14.6	3	6.6	0.6
482	Donut recheado com doce de fruta	Cereais e produtos à base de cereais	donut recheado com doce de fruta	348	14.5	6.4	47	18.6	2.5	6	0.5
829	Dourada cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	dourada cozida	196	12.5	2.4	0	0	0	20.8	0.4
828	Dourada crua	Peixes, mariscos, anfíbios, répteis e invertebrados	dourada crua	167	9.8	2.1	0	0	0	19.7	0.1
830	Dourada grelhada	Peixes, mariscos, anfíbios, répteis e invertebrados	dourada grelhada	178	9.9	1.9	0	0	0	22.3	1.6
483	Éclair de chocolate	Cereais e produtos à base de cereais	eclair de chocolate	378	23.8	10.3	36.5	25.7	0.5	4.1	0.4
371	Empada	Pratos compostos	empada	374	21.9	9.7	33.9	1.8	1.3	9.6	1.3
1056	Empadão de atum	Pratos compostos	empadao de atum	234	15.2	6.1	10.7	1	0.9	12.9	0.9
1055	Empadão de bacalhau	Pratos compostos	empadao de bacalhau	118	5	2.4	10.9	2.1	0.9	6.9	1.3
1019	Empadão de carne com manteiga	Pratos compostos	empadao de carne com manteiga	134	6.3	2.6	10.7	1.3	1.1	6.6	0.4
1018	Empadão de carne com margarina	Pratos compostos	empadao de carne com margarina	134	6.3	2.4	10.7	1.3	1.1	6.6	0.5
1017	Empadão de carne guisada	Pratos compostos	empadao de carne guisada	167	9.3	4.2	10.9	1.5	0.9	9.4	0.8
1054	Empadão de pescada e camarão	Pratos compostos	empadao de pescada e camarao	122	4.5	1.8	11	2.2	1.1	8.7	1.1
1900000025	Endívia crua	Produtos hortícolas e derivados	endivia crua	19	0.4	0.1	1.2	1.2	1.8	1.8	0.1
831	Enguia crua	Peixes, mariscos, anfíbios, répteis e invertebrados	enguia crua	303	27.7	8.6	0	0	0	13.4	0.2
832	Enguia frita	Peixes, mariscos, anfíbios, répteis e invertebrados	enguia frita	267	21.6	6.2	3.2	0.1	0.1	14.8	0.4
526	Ervilhas secas cozidas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	ervilhas secas cozidas	114	0.4	0.1	18.1	0.9	5.1	6.9	0.6
525	Ervilhas secas cruas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	ervilhas secas cruas	330	1.3	0.5	49.4	2.3	15	22.7	0.1
574	Ervilhas, grão, congeladas cozidas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	ervilhas, grao, congeladas cozidas	72	0.5	0.1	7.5	1.5	7.3	5.6	0.3
573	Ervilhas, grão, congeladas cruas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	ervilhas, grao, congeladas cruas	68	0.5	0.1	7	1.4	7	5.3	0
570	Ervilhas, grão, frescas cozidas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	ervilhas, grao, frescas cozidas	72	0.7	0.1	7.9	1.6	4.8	6.2	0.3
569	Ervilhas, grão, frescas cruas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	ervilhas, grao, frescas cruas	76	0.7	0.1	8.6	1.8	4.7	6.4	0
1133	Ervilhas, grão, frescas, estufadas	Pratos compostos	ervilhas, grao, frescas, estufadas	113	5.1	2.6	9.6	2.8	3.9	5.1	0.3
572	Ervilhas, vagens cozidas	Produtos hortícolas e derivados	ervilhas, vagens cozidas	30	0.2	0	3.5	2.6	1.4	2.8	0.2
571	Ervilhas, vagens cruas	Produtos hortícolas e derivados	ervilhas, vagens cruas	33	0.2	0	3.9	2.9	1.5	3.1	0
834	Espadarte cru	Peixes, mariscos, anfíbios, répteis e invertebrados	espadarte cru	97	2.9	0.7	0	0	0	17.8	0.2
835	Espadarte grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	espadarte grelhado	116	3.4	0.8	0	0	0	21.3	1
836	Espadarte, bife estufado com azeite e vinho	Peixes, mariscos, anfíbios, répteis e invertebrados	espadarte, bife estufado com azeite e vinho	152	8.1	1.4	0.4	0.2	0	17.1	0.9
607	Espargos cozidos	Produtos hortícolas e derivados	espargos cozidos	16	0	0	2.2	2.1	1.8	1	0.2
606	Espargos crus	Produtos hortícolas e derivados	espargos crus	22	0	0	2.7	2.6	1.5	2.1	0
419	Esparguete cozido	Cereais e produtos à base de cereais	esparguete cozido	102	0.6	0.1	19.9	0.9	1.5	3.4	0.6
417	Esparguete cru	Cereais e produtos à base de cereais	esparguete cru	360	1.9	0.4	71.1	3.1	5.1	12.1	0
420	Esparguete estufado com cenoura e azeite	Pratos compostos	esparguete estufado com cenoura e azeite	121	3.9	0.6	17.6	1.9	1.8	3	0.6
421	Esparguete estufado com cenoura e margarina	Pratos compostos	esparguete estufado com cenoura e margarina	115	3.2	1.5	17.6	1.9	1.8	3	0.7
608	Espinafres crus	Produtos hortícolas e derivados	espinafres crus	27	0.9	0.1	0.8	0.7	2.6	2.6	0.4
1200	Estragão fresco	Produtos hortícolas e derivados	estragao fresco	55	1.1	0.4	6.3	6.3	2.9	3.4	0
1201	Estragão seco	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	estragao seco	363	7.2	2.4	42.8	42.8	18.1	22.8	0.2
2120000015	Faneca crua	Peixes, mariscos, anfíbios, répteis e invertebrados	faneca crua	82	0.6	0.1	0.1	0	0	19	0.2
1900000075	Farelo de trigo	Cereais e produtos à base de cereais	farelo de trigo	293	5.3	0.9	24.9	2.4	40.2	16.2	0.1
409	Farinha de alfarroba	Frutos e produtos derivados de frutos	farinha de alfarroba	368	0.3	0	85.6	42	5	3.2	0.1
1900000071	Farinha de aveia	Cereais e produtos à base de cereais	farinha de aveia	363	7.3	0.7	57	1.3	5.7	14.5	0
60100015	Farinha de centeio	Cereais e produtos à base de cereais	farinha de centeio	370	1.2	0.2	77.3	0	9.4	7.8	0
410	Farinha de centeio tipo 70	Cereais e produtos à base de cereais	farinha de centeio tipo 70	364	1.1	0.1	78.5	0	7	6.6	0
411	Farinha de centeio tipo 85	Cereais e produtos à base de cereais	farinha de centeio tipo 85	375	1.3	0.2	76	0	11.7	9	0
1900000070	Farinha de cevada	Cereais e produtos à base de cereais	farinha de cevada	330	2.5	0.4	64.4	0.9	7.6	8.8	0
1900000077	Farinha de espelta	Cereais e produtos à base de cereais	farinha de espelta	339	2.3	0.4	61.8	1.9	7.4	14	0
413	Farinha de milho tipo 70	Cereais e produtos à base de cereais	farinha de milho tipo 70	359	2.2	0.3	75.3	0	2.6	8.3	0
471	Farinha de pau (mandioca)	Raízes amiláceas ou tubérculos e seus produtos, plantas sacarinas	farinha de pau (mandioca)	350	0.3	0.1	84.6	0	1.6	1.4	0.1
60100002	Farinha de trigo (valor médio tipo 150 e tipo 55)	Cereais e produtos à base de cereais	farinha de trigo (valor medio tipo 150 e tipo 55)	349	1.5	0.3	73.7	2.1	3.3	8.5	0
230002	Farinha de trigo com fermento	Cereais e produtos à base de cereais	farinha de trigo com fermento	343	1.1	0.5	72.5	1.8	2.3	9.7	1.4
416	Farinha de trigo integral	Cereais e produtos à base de cereais	farinha de trigo integral	338	2.4	0.3	65.2	2.3	8.6	9.6	0
414	Farinha de trigo tipo 150	Cereais e produtos à base de cereais	farinha de trigo tipo 150	352	1.8	0.3	73	2.6	3.7	9.1	0
415	Farinha de trigo tipo 55	Cereais e produtos à base de cereais	farinha de trigo tipo 55	344	1.1	0.2	74.3	1.5	2.9	7.8	0
230003	Farinha de trigo tipo 65	Cereais e produtos à base de cereais	farinha de trigo tipo 65	341	1	0.2	67.6	1.5	3.5	13.6	0
945	Farinha láctea 5 frutos tipo "Cerelac" (com farinha de trigo)	Produtos alimentares para a população jovem	farinha lactea 5 frutos tipo "cerelac" (com farinha de trigo)	408	9	4.1	65	40.3	3.6	15	0.3
946	Farinha láctea maçãs tipo "Cerelac" (com farinha de trigo)	Produtos alimentares para a população jovem	farinha lactea macas tipo "cerelac" (com farinha de trigo)	412	9	4.2	66	41	3.7	15	0.3
944	Farinha láctea tipo "Cerelac" (com farinha de trigo)	Produtos alimentares para a população jovem	farinha lactea tipo "cerelac" (com farinha de trigo)	416	9	3.9	68	35.8	1.6	15	0.4
348	Farinheira cozida	Carne e produtos cárneos	farinheira cozida	404	30.7	10.9	26.4	0.5	1.3	4.8	0.2
347	Farinheira crua	Carne e produtos cárneos	farinheira crua	497	41	14.5	26.7	0.5	1.2	4.8	2.4
1132	Favada à portuguesa	Pratos compostos	favada a portuguesa	130	5.9	1.9	8.4	1.8	5.6	8	0.6
576	Favas frescas cozidas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	favas frescas cozidas	82	0.5	0.1	7.7	1.4	7.9	7.7	0.3
575	Favas frescas cruas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	favas frescas cruas	80	0.5	0.1	8.5	1.6	6.1	7.4	0
527	Favas secas cruas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	favas secas cruas	301	1.3	0.2	32.8	6.2	27.6	25.8	0
528	Favas secas, demolhadas, cozidas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	favas secas, demolhadas, cozidas	90	0.6	0.1	10.7	1.2	5	7.9	0.6
578	Feijão-verde fresco cozido	Produtos hortícolas e derivados	feijao-verde fresco cozido	27	0.3	0.1	3.5	2.5	2.3	1.3	0.2
577	Feijão-verde fresco cru	Produtos hortícolas e derivados	feijao-verde fresco cru	32	0.3	0.1	3.8	2.8	3	1.9	0
532	Feijão branco, demolhado, cozido	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao branco, demolhado, cozido	102	0.6	0.1	14.6	0.7	6.5	6.5	0.6
531	Feijão branco, seco, cru	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao branco, seco, cru	308	0.1	0	43.9	2	22.9	21.3	0
220024	Feijão catarino, seco, cru	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao catarino, seco, cru	302	0.1	0	47.9	0.2	14	20.3	0
240003	Feijão catarino, seco, demolhado, cozido	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao catarino, seco, demolhado, cozido	88	0	0	14.1	0.1	4.1	6	0
1202	Feijão encarnado, seco, cru	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao encarnado, seco, cru	310	0.5	0.1	47.9	1.7	14	21.5	0
240002	Feijão encarnado, seco, demolhado, cozido	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao encarnado, seco, demolhado, cozido	90	0.1	0	13.8	0.5	4	6.2	0
529	Feijão frade, seco, cru	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao frade, seco, cru	339	1.5	0.5	55.3	1.7	9.4	21.4	0
530	Feijão frade, seco, demolhado, cozido	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao frade, seco, demolhado, cozido	123	0.7	0.2	18.1	1	4.7	8.8	0.6
534	Feijão manteiga, demolhado, cozido	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao manteiga, demolhado, cozido	99	0.6	0.1	14	0.8	6.2	6.4	0.6
533	Feijão manteiga, seco, cru	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao manteiga, seco, cru	313	0.1	0	42.6	1.7	22.9	24	0
220025	Feijão preto, seco, cru	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao preto, seco, cru	318	1	0.2	47.9	4.7	14	22.4	0
240001	Feijão preto, seco, demolhado, cozido	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	feijao preto, seco, demolhado, cozido	80	0.3	0.1	8.4	1.4	9	6.5	0
1900000011	Feijoa (polpa)	Frutos e produtos derivados de frutos	feijoa (polpa)	52	0.5	0.1	9.8	9.5	2.1	0.9	0
950	Feijoada com carne de porco	Pratos compostos	feijoada com carne de porco	187	7.2	2.1	13.3	2.1	6.8	13.6	1
951	Feijoada com carne de porco e de vaca	Pratos compostos	feijoada com carne de porco e de vaca	191	7.5	2.3	13.3	2.1	6.8	13.7	1
1023	Feijoada com enchidos e ovos	Pratos compostos	feijoada com enchidos e ovos	240	15.1	4.8	14.1	2.1	5.8	9	0.7
779	Fermento em pó	Ingredientes principais isolados, aditivos, aromas, fermentos e auxiliares tecnológicos	fermento em po	156	0	0	34.4	0	0	4.7	46
777	Fermento fresco de padeiro	Ingredientes principais isolados, aditivos, aromas, fermentos e auxiliares tecnológicos	fermento fresco de padeiro	78	0.9	0.1	1	0	7.3	12.9	0.1
778	Fermento seco de padeiro	Ingredientes principais isolados, aditivos, aromas, fermentos e auxiliares tecnológicos	fermento seco de padeiro	228	2.5	0.3	3.2	0	19.7	38.3	0.1
1232	Fiambre de aves	Carne e produtos cárneos	fiambre de aves	83	1.6	0.5	2.7	0.1	1.6	13.8	2.3
1231	Fiambre de porco	Carne e produtos cárneos	fiambre de porco	111	4.6	1.5	1.3	1.3	1.9	15.3	2.3
1168	Fiambre, pá	Carne e produtos cárneos	fiambre, pa	112	5.1	1.7	1.3	1.3	2.3	14	2.4
1167	Fiambre, peito de frango	Carne e produtos cárneos	fiambre, peito de frango	82	1.3	0.4	2.8	0.1	1.9	13.7	2.4
1166	Fiambre, peito de peru	Carne e produtos cárneos	fiambre, peito de peru	85	1.9	0.6	2.6	0.1	1.2	13.8	2.2
1169	Fiambre, perna	Carne e produtos cárneos	fiambre, perna	111	4.1	1.3	1.2	1.2	1.4	16.5	2.3
650	Figo (5 variedades)	Frutos e produtos derivados de frutos	figo (5 variedades)	79	0.5	0.1	16.3	16.3	2.3	0.9	0
651	Figo cristalizado	Frutos e produtos derivados de frutos	figo cristalizado	295	0.4	0.1	71.2	71.2	2.3	0.5	0.2
652	Figo seco	Frutos e produtos derivados de frutos	figo seco	276	1.5	0.1	58.2	44.6	9.5	2.8	0.2
1900000029	Fisális	Produtos hortícolas e derivados	fisalis	68	0.6	0.2	11.7	11.7	4.2	1.8	0
445	Flocos de arroz	Cereais e produtos à base de cereais	flocos de arroz	379	1.5	0.3	83.4	7	2.1	7	1.2
444	Flocos de aveia	Cereais e produtos à base de cereais	flocos de aveia	366	5.8	1.2	61.7	3	6.7	13.5	0
1900000072	Flocos de centeio	Cereais e produtos à base de cereais	flocos de centeio	352	2	0.3	69	1	5	12	0.1
447	Flocos de cereais e frutos secos tipo "Muesli"	Cereais e produtos à base de cereais	flocos de cereais e frutos secos tipo "muesli"	388	6.3	1.1	69.1	16.8	6.8	10.4	0.6
1900000073	Flocos de cevada	Cereais e produtos à base de cereais	flocos de cevada	324	2	0.3	64.4	0.9	7.6	8.3	0
443	Flocos de milho tipo "Corn Flakes"	Cereais e produtos à base de cereais	flocos de milho tipo "corn flakes"	374	1.1	0.3	81.1	6.2	3.9	7.9	1.8
446	Flocos de trigo	Cereais e produtos à base de cereais	flocos de trigo	373	2.5	0.6	69	6.8	9.3	14	0
947	Flocos de trigo com figos tipo "Nestum"	Produtos alimentares para a população jovem	flocos de trigo com figos tipo "nestum"	370	1.5	0.3	76.3	28	7.7	9	1
948	Flocos de trigo com mel tipo "Nestum"	Produtos alimentares para a população jovem	flocos de trigo com mel tipo "nestum"	385	1	0.2	84.6	29	2.4	8.2	0.1
448	Flocos de trigo e arroz enriquecidos com vitaminas, cálcio e ferro	Cereais e produtos à base de cereais	flocos de trigo e arroz enriquecidos com vitaminas, calcio e ferro	372	1.3	0.4	79.2	17.2	6.5	7.5	1.5
449	Flocos de trigo integral tipo "All-Bran Flakes"	Cereais e produtos à base de cereais	flocos de trigo integral tipo "all-bran flakes"	349	1.9	0.4	64.2	18.1	17.3	10.2	2.3
1900000114	Flor de sal	Temperos, molhos e condimentos	flor de sal	0	0	0	0	0	0	0	100
1900000027	Folhas de rabanete cruas	Produtos hortícolas e derivados	folhas de rabanete cruas	39	0.5	0.1	3.9	3.5	2.6	3.5	0.3
653	Framboesa	Frutos e produtos derivados de frutos	framboesa	49	0.6	0	5.1	5.1	6.7	0.9	0
1900000106	Framboesa desidratada	Frutos e produtos derivados de frutos	framboesa desidratada	293	3.6	0	30.9	30.9	40.5	5.4	0
1073	Francesinha, com molho	Pratos compostos	francesinha, com molho	249	17.7	6.3	6.5	1.1	0.4	13.3	3.2
251	Frango (1/4) peito e asa com pele, cozidos	Carne e produtos cárneos	frango (1/4) peito e asa com pele, cozidos	202	10.3	2.4	0	0	0	27.2	0.9
253	Frango (1/4) peito e asa com pele, estufados com azeite e margarina	Pratos compostos	frango (1/4) peito e asa com pele, estufados com azeite e margarina	204	13.5	3.3	1.7	1.5	0.7	18.5	1.1
252	Frango (1/4) peito e asa com pele, estufados com margarina	Pratos compostos	frango (1/4) peito e asa com pele, estufados com margarina	201	13.2	3.6	1.7	1.5	0.7	18.5	1.1
254	Frango (1/4) peito e asa com pele, estufados sem molho	Carne e produtos cárneos	frango (1/4) peito e asa com pele, estufados sem molho	223	11.8	2.8	0	0	0	29.2	0.6
255	Frango (1/4) peito e asa com pele, grelhados	Carne e produtos cárneos	frango (1/4) peito e asa com pele, grelhados	235	13.4	3.2	0	0	0	28.7	0.7
261	Frango (1/4) perna com costa e pele, assada sem molho	Carne e produtos cárneos	frango (1/4) perna com costa e pele, assada sem molho	231	13.7	3.2	0	0	0	26.9	0.7
256	Frango (1/4) perna com costa e pele, cozida	Carne e produtos cárneos	frango (1/4) perna com costa e pele, cozida	197	10.6	2.5	0	0	0	25.5	0.6
257	Frango (1/4) perna com costa e pele, estufada com azeite e margarina	Pratos compostos	frango (1/4) perna com costa e pele, estufada com azeite e margarina	203	13.8	3.4	1.7	1.5	0.7	17.3	1.1
258	Frango (1/4) perna com costa e pele, estufada com margarina	Pratos compostos	frango (1/4) perna com costa e pele, estufada com margarina	200	13.5	3.7	1.7	1.5	0.7	17.3	1.2
259	Frango (1/4) perna com costa e pele, estufada sem molho	Pratos compostos	frango (1/4) perna com costa e pele, estufada sem molho	215	11.9	2.8	0	0	0	26.9	0.7
14	Frango (1/4), peito e asa com pele, crus	Carne e produtos cárneos	frango (1/4), peito e asa com pele, crus	196	12.7	3	0	0	0	20.4	0.2
15	Frango (1/4), perna com costa e pele, crua	Carne e produtos cárneos	frango (1/4), perna com costa e pele, crua	195	13	3.1	0	0	0	19.1	0.2
260	Frango (1/4), perna com costa e pele, grelhada	Carne e produtos cárneos	frango (1/4), perna com costa e pele, grelhada	231	13.7	3.2	0	0	0	26.9	0.7
245	Frango inteiro com pele, assado sem molho	Carne e produtos cárneos	frango inteiro com pele, assado sem molho	239	14.3	3.4	0	0	0	27.6	0.7
240	Frango inteiro com pele, cozido	Carne e produtos cárneos	frango inteiro com pele, cozido	204	11.1	2.7	0	0	0	26.1	0.6
16	Frango inteiro com pele, cru	Carne e produtos cárneos	frango inteiro com pele, cru	201	13.6	3.2	0	0	0	19.6	0.2
242	Frango inteiro com pele, estufado com azeite e margarina	Pratos compostos	frango inteiro com pele, estufado com azeite e margarina	224	15.4	3.7	1.8	1.6	0.7	19.1	1.2
241	Frango inteiro com pele, estufado com margarina	Pratos compostos	frango inteiro com pele, estufado com margarina	221	15.1	4.1	1.8	1.6	0.7	19.1	1.2
243	Frango inteiro com pele, estufado sem molho	Carne e produtos cárneos	frango inteiro com pele, estufado sem molho	233	13.1	3.1	0	0	0	28.8	0.7
244	Frango inteiro com pele, grelhado	Carne e produtos cárneos	frango inteiro com pele, grelhado	239	14.3	3.4	0	0	0	27.6	0.7
246	Frango inteiro sem pele, cozido	Carne e produtos cárneos	frango inteiro sem pele, cozido	169	4.2	1.1	0	0	0	32.8	0.6
17	Frango inteiro sem pele, cru	Carne e produtos cárneos	frango inteiro sem pele, cru	110	2	0.5	0	0	0	22.9	0.2
248	Frango inteiro sem pele, estufado com azeite e margarina	Pratos compostos	frango inteiro sem pele, estufado com azeite e margarina	129	4.1	1.1	1.7	1.5	0.7	21	1.1
247	Frango inteiro sem pele, estufado com margarina	Pratos compostos	frango inteiro sem pele, estufado com margarina	126	3.8	1.4	1.7	1.5	0.7	21	1.2
249	Frango inteiro sem pele, estufado sem molho	Carne e produtos cárneos	frango inteiro sem pele, estufado sem molho	185	5.8	1.4	0	0	0	33.2	0.7
250	Frango inteiro sem pele, grelhado	Carne e produtos cárneos	frango inteiro sem pele, grelhado	168	4.9	1.3	0	0	0	31	0.7
268	Frango, peito com pele estufado com azeite e margarina	Pratos compostos	frango, peito com pele estufado com azeite e margarina	189	10.3	2.5	1.7	1.5	0.7	22.1	1
267	Frango, peito com pele estufado com margarina	Pratos compostos	frango, peito com pele estufado com margarina	187	10	2.9	1.7	1.5	0.7	22.1	1
266	Frango, peito com pele, cozido	Carne e produtos cárneos	frango, peito com pele, cozido	194	7.3	1.7	0	0	0	32.1	1.1
10	Frango, peito com pele, cru	Carne e produtos cárneos	frango, peito com pele, cru	177	8.9	2.1	0	0	0	24.1	0.2
269	Frango, peito com pele, estufado sem molho	Carne e produtos cárneos	frango, peito com pele, estufado sem molho	212	8.3	2	0	0	0	34.4	0.7
272	Frango, peito sem pele estufado com azeite e margarina	Pratos compostos	frango, peito sem pele estufado com azeite e margarina	124	3.3	0.9	1.7	1.5	0.7	21.4	1.1
271	Frango, peito sem pele estufado com margarina	Pratos compostos	frango, peito sem pele estufado com margarina	121	3	1.2	1.7	1.5	0.7	21.4	1.1
270	Frango, peito sem pele, cozido	Carne e produtos cárneos	frango, peito sem pele, cozido	148	1.1	0.3	0	0	0	34.5	0.6
11	Frango, peito sem pele, cru	Carne e produtos cárneos	frango, peito sem pele, cru	108	1.2	0.3	0	0	0	24.1	0.2
273	Frango, peito sem pele, estufado sem molho	Carne e produtos cárneos	frango, peito sem pele, estufado sem molho	169	2.5	0.7	0	0	0	36.6	0.6
13	Frango, pele crua	Carne e produtos cárneos	frango, pele crua	474	48.3	11.4	0	0	0	9.7	0.1
262	Frango, perna sem pele, cozida	Carne e produtos cárneos	frango, perna sem pele, cozida	147	2.3	0.6	0	0	0	31.5	0.6
12	Frango, perna sem pele, crua	Carne e produtos cárneos	frango, perna sem pele, crua	111	2.6	0.6	0	0	0	22	0.2
264	Frango, perna sem pele, estufada com azeite e margarina	Pratos compostos	frango, perna sem pele, estufada com azeite e margarina	124	4.4	1.1	1.6	1.4	0.7	19.1	1.1
263	Frango, perna sem pele, estufada com margarina	Pratos compostos	frango, perna sem pele, estufada com margarina	121	4.1	1.4	1.6	1.4	0.7	19.1	1.1
265	Frango, perna sem pele, estufada sem molho	Carne e produtos cárneos	frango, perna sem pele, estufada sem molho	180	5.4	1.3	0	0	0	32.9	0.7
1203	Funcho fresco	Produtos hortícolas e derivados	funcho fresco	32	0.4	0.1	2.6	2.6	3.3	2.8	0
1900000002	Galinha de angola com pele, crua	Carne e produtos cárneos	galinha de angola com pele, crua	152	6.5	1.8	0	0	0	23.4	0.2
1900000007	Galinha, coração cru	Carne e produtos cárneos	galinha, coracao cru	149	9.3	2.7	0.7	0	0	15.6	0.2
1900000001	Galinha, fígado cru	Carne e produtos cárneos	galinha, figado cru	92	2.3	0.7	0	0	0	17.7	0.2
1920000020	Gamba crua	Peixes, mariscos, anfíbios, répteis e invertebrados	gamba crua	88	0.2	0	0	0	0	21.5	0.5
900	Garoupa cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	garoupa cozida	101	2	0.4	0	0	0	20.8	1
899	Garoupa crua	Peixes, mariscos, anfíbios, répteis e invertebrados	garoupa crua	95	1.4	0.3	0	0	0	20.5	0.3
901	Garoupa grelhada	Peixes, mariscos, anfíbios, répteis e invertebrados	garoupa grelhada	121	1.9	0.4	0	0	0	25.9	1.2
518	Gelado caseiro com bolachas e natas	Leite e produtos lácteos	gelado caseiro com bolachas e natas	358	21.2	12.2	36.5	28.2	0.6	5.1	0.2
519	Gelado caseiro com palitos la Reine	Leite e produtos lácteos	gelado caseiro com palitos la reine	263	12.4	2.4	28.7	23	2	7.9	0.1
513	Gelado de água (sorvete)	Açúcar e similares, confeitaria e sobremesas doces à base de água	gelado de agua (sorvete)	132	0	0	32.6	32.6	0	0.4	0
514	Gelado de leite	Leite e produtos lácteos	gelado de leite	199	10.9	6.1	21.7	21.7	0	3.6	0.1
515	Gelatina desidratada (pó ou folha)	Ingredientes principais isolados, aditivos, aromas, fermentos e auxiliares tecnológicos	gelatina desidratada (po ou folha)	349	0.1	0	0	0	0	87	0.1
516	Gelatina preparada com ananás em conserva	Açúcar e similares, confeitaria e sobremesas doces à base de água	gelatina preparada com ananas em conserva	97	0	0	21.6	21.6	0.4	2.2	0
517	Gelatina preparada com laranja e sumo de laranja	Açúcar e similares, confeitaria e sobremesas doces à base de água	gelatina preparada com laranja e sumo de laranja	84	0.1	0	17.4	17.4	0.7	2.6	0
660	Geleia de casca de laranja	Frutos e produtos derivados de frutos	geleia de casca de laranja	275	0	0	68	68	0.7	0.3	0
84	Gema de ovo de galinha, crua	Ovos e ovoprodutos	gema de ovo de galinha, crua	342	30.9	8.3	0	0	0	16	0.1
1900000056	Gema de ovo de galinha, pasteurizada	Ovos e ovoprodutos	gema de ovo de galinha, pasteurizada	294	25.2	7.9	1.3	0.2	0	15.3	0.2
1204	Gengibre fresco	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	gengibre fresco	82	0.8	0.2	15.8	15.8	2	1.8	0
1900000076	Gérmen de trigo	Cereais e produtos à base de cereais	germen de trigo	391	9.6	1.4	41.8	15.7	12.3	28.1	0
731	Gin - Rum- Whisky	Bebidas alcoólicas	gin - rum- whisky	222	0	0	0	0	0	0	0
655	Ginja	Frutos e produtos derivados de frutos	ginja	57	0.3	0.1	11.5	11.5	1.6	0.9	0
1900000095	Goiaba crua, polpa	Frutos e produtos derivados de frutos	goiaba crua, polpa	41	0.5	0	5	4.9	5.3	0.8	0
840	Goraz assado com cebola, tomate, azeite e óleo alimentar	Pratos compostos	goraz assado com cebola, tomate, azeite e oleo alimentar	117	5.1	0.9	1.5	1.3	0.5	14.8	0.9
838	Goraz cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	goraz cozido	108	3.5	0.9	0	0	0	19.2	0.9
837	Goraz cru	Peixes, mariscos, anfíbios, répteis e invertebrados	goraz cru	100	2.7	0.7	0	0	0	18.8	0.3
839	Goraz grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	goraz grelhado	118	3.2	0.8	0	0	0	22.4	1
1126	Goraz no forno	Peixes, mariscos, anfíbios, répteis e invertebrados	goraz no forno	110	2.7	0.7	0.7	0.6	0.3	18.7	1.1
536	Grão-de-bico, demolhado, cozido	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	grao-de-bico, demolhado, cozido	119	2.1	0.2	15.1	0.6	6.2	6.8	0.6
535	Grão-de-bico, seco, cru	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	grao-de-bico, seco, cru	327	6.8	0.5	33.5	4.5	27.2	19.4	0
566	Grelos de couve cozidos	Produtos hortícolas e derivados	grelos de couve cozidos	22	0.4	0.1	1.5	1.3	2.3	1.9	0.3
565	Grelos de couve crus	Produtos hortícolas e derivados	grelos de couve crus	28	0.4	0.1	2.5	2.1	2.6	2.4	0
568	Grelos de nabo cozidos	Produtos hortícolas e derivados	grelos de nabo cozidos	20	0.4	0.1	1.3	1.1	2.2	1.8	0.3
567	Grelos de nabo crus	Produtos hortícolas e derivados	grelos de nabo crus	29	0.5	0.1	2.3	1.9	2.6	2.4	0
439	Gressino	Cereais e produtos à base de cereais	gressino	396	8.7	2.5	67	4.3	3.5	10.7	0.8
260002	Grilo doméstico, pó	Anfíbios, répteis, e invertebrados terrestres	grilo domestico, po	506	28.9	11.9	0.1	0.1	6.2	58.3	0.9
1900000099	Groselha	Frutos e produtos derivados de frutos	groselha	52	0.5	0	5	5	8.2	1.1	0
291	Hambúrguer de feijão manteiga frito com azeite	Pratos compostos	hamburguer de feijao manteiga frito com azeite	169	5.3	0.9	19.8	1.2	4.9	8	1.1
292	Hambúrguer de feijão manteiga frito com óleo de milho	Pratos compostos	hamburguer de feijao manteiga frito com oleo de milho	169	5.3	0.9	19.8	1.2	4.9	8	1.1
1900000031	Hortelã fresca	Produtos hortícolas e derivados	hortela fresca	51	0.7	0.1	5.3	5.1	3.9	3.8	0
844	Imperador assado com cebola, tomate, azeite e óleo alimentar	Pratos compostos	imperador assado com cebola, tomate, azeite e oleo alimentar	94	3.1	0.4	1.4	1.2	0.5	13.7	0.8
842	Imperador cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	imperador cozido	84	0.5	0.1	0	0	0	19.9	0.9
841	Imperador cru	Peixes, mariscos, anfíbios, répteis e invertebrados	imperador cru	80	0.4	0.1	0	0	0	19	0.2
843	Imperador grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	imperador grelhado	97	0.5	0.1	0	0	0	23	1
1900000059	Inhame cru	Raízes amiláceas ou tubérculos e seus produtos, plantas sacarinas	inhame cru	114	0.3	0.1	25.7	0.7	1.3	1.5	0
82	Iogurte gordo, aromatizado, açucarado	Leite e produtos lácteos	iogurte gordo, aromatizado, acucarado	83	3.6	2	8.5	8.5	0	3.9	0.1
81	Iogurte gordo, com polpa e/ou pedaços de fruta e cereais açucarado	Leite e produtos lácteos	iogurte gordo, com polpa e/ou pedacos de fruta e cereais acucarado	114	3.2	1.8	15.8	15.8	0.8	4.2	0.1
80	Iogurte gordo, com polpa e/ou pedaços de fruta, açucarado	Leite e produtos lácteos	iogurte gordo, com polpa e/ou pedacos de fruta, acucarado	96	3.2	1.8	12.4	12.4	0	4.2	0.1
2122000009	Iogurte grego com fruta açucarado	Leite e produtos lácteos	iogurte grego com fruta acucarado	113	5	3.2	13.7	13.7	0.8	2.7	0.1
2122000015	Iogurte grego magro natural	Leite e produtos lácteos	iogurte grego magro natural	56	2	1.4	3.9	3.9	0	5.3	0
2122000008	Iogurte grego natural	Leite e produtos lácteos	iogurte grego natural	85	6.6	4.2	4.8	4.8	0	1.4	0.1
77	Iogurte líquido magro, aromatizado, açucarado	Leite e produtos lácteos	iogurte liquido magro, aromatizado, acucarado	62	0.3	0.2	11.6	11.6	0	3.2	0.2
73	Iogurte líquido meio gordo, aromatizado, açucarado	Leite e produtos lácteos	iogurte liquido meio gordo, aromatizado, acucarado	70	1.3	0.7	11.5	11.5	0	3	0.1
71	Iogurte líquido meio gordo, natural, açucarado	Leite e produtos lácteos	iogurte liquido meio gordo, natural, acucarado	70	1.4	0.8	11.2	11.2	0	3.1	0.1
78	Iogurte magro, aromatizado, açucarado	Leite e produtos lácteos	iogurte magro, aromatizado, acucarado	69	0.1	0.1	11.8	11.8	0	5	0.2
69	Iogurte magro, com cereais e edulcorantes	Leite e produtos lácteos	iogurte magro, com cereais e edulcorantes	50	0.4	0.2	5.7	5.7	1	4.3	0.2
79	Iogurte magro, natural	Leite e produtos lácteos	iogurte magro, natural	42	0.2	0.1	5.2	5.2	0	4.6	0.2
68	Iogurte magro, natural, com edulcorantes	Leite e produtos lácteos	iogurte magro, natural, com edulcorantes	47	0.1	0.1	6.3	6.3	0	5	0.2
1900000102	Iogurte meio gordo, aromatizado, açucarado	Leite e produtos lácteos	iogurte meio gordo, aromatizado, acucarado	79	1.8	1	11.3	11.3	0	4.3	0.2
75	Iogurte meio gordo, com polpa e/ou pedaços de fruta, açucarado	Leite e produtos lácteos	iogurte meio gordo, com polpa e/ou pedacos de fruta, acucarado	92	1.7	1	14.6	14.6	0	4.3	0.2
76	Iogurte meio gordo, natural	Leite e produtos lácteos	iogurte meio gordo, natural	54	1.8	1	5	5	0	4.2	0.2
70	Iogurte meio gordo, natural, açucarado	Leite e produtos lácteos	iogurte meio gordo, natural, acucarado	91	2.1	1.2	13.1	13.1	0	4.7	0.2
1920000013	Iogurte sem lactose enriquecido em proteína, magro, aromatizado, com pedaços e/ou polpa de fruta, açucarado	Leite e produtos lácteos	iogurte sem lactose enriquecido em proteina, magro, aromatizado, com pedacos e/ou polpa de fruta, acucarado	76	0	0	9.7	8.9	0	9	0.2
1920000004	Iogurte sem lactose líquido, magro, aromatizado, com polpa de fruta, açucarado	Leite e produtos lácteos	iogurte sem lactose liquido, magro, aromatizado, com polpa de fruta, acucarado	78	0.2	0.1	16	16	0	3.1	0.2
1920000005	Iogurte sem lactose líquido, magro, aromatizado, com polpa de fruta, com edulcorantes	Leite e produtos lácteos	iogurte sem lactose liquido, magro, aromatizado, com polpa de fruta, com edulcorantes	34	0.1	0	5	4.7	0.1	3.3	0.2
1920000003	Iogurte sem lactose líquido, meio gordo, aromatizado, açucarado	Leite e produtos lácteos	iogurte sem lactose liquido, meio gordo, aromatizado, acucarado	71	1.4	0.9	11.8	11.8	0	2.8	0.1
1920000001	Iogurte sem lactose líquido, meio gordo, aromatizado, com polpa de fruta, açucarado	Leite e produtos lácteos	iogurte sem lactose liquido, meio gordo, aromatizado, com polpa de fruta, acucarado	73	1.3	0.9	12.5	12.4	0	2.6	0.1
1920000002	Iogurte sem lactose líquido, meio gordo, natural, açucarado	Leite e produtos lácteos	iogurte sem lactose liquido, meio gordo, natural, acucarado	70	1.4	0.9	11.7	11.7	0	2.7	0.1
1920000012	Iogurte sem lactose magro, aromatizado, com pedaços e/ou polpa de fruta, com edulcorantes	Leite e produtos lácteos	iogurte sem lactose magro, aromatizado, com pedacos e/ou polpa de fruta, com edulcorantes	42	0.1	0.1	4.8	4.7	0.4	4.8	0.2
1920000011	Iogurte sem lactose magro, natural	Leite e produtos lácteos	iogurte sem lactose magro, natural	41	0.2	0.1	5	5	0	4.9	0.2
1920000007	Iogurte sem lactose meio gordo, aromatizado, açucarado	Leite e produtos lácteos	iogurte sem lactose meio gordo, aromatizado, acucarado	76	1.5	1	12	11.3	0	3.5	0.2
1920000009	Iogurte sem lactose meio gordo, aromatizado, com frutos secos e cereais, açucarado	Leite e produtos lácteos	iogurte sem lactose meio gordo, aromatizado, com frutos secos e cereais, acucarado	98	1.6	1	16.1	16.1	0.1	3.7	0.2
1920000008	Iogurte sem lactose meio gordo, aromatizado, com pedaços e/ou polpa de fruta, açucarado	Leite e produtos lácteos	iogurte sem lactose meio gordo, aromatizado, com pedacos e/ou polpa de fruta, acucarado	83	1.3	0.8	13.6	13.5	0.2	3.7	0.2
1920000010	Iogurte sem lactose meio gordo, natural	Leite e produtos lácteos	iogurte sem lactose meio gordo, natural	48	1.5	1	4.5	4.5	0	3.8	0.2
1920000006	Iogurte sem lactose meio gordo, natural, açucarado	Leite e produtos lácteos	iogurte sem lactose meio gordo, natural, acucarado	78	1.5	1	12.2	11.5	0	3.5	0.2
1900000006	Javali cru	Carne e produtos cárneos	javali cru	108	3.4	1.5	0	0	0	19.5	0.2
484	Jesuíta	Cereais e produtos à base de cereais	jesuita	518	31.2	11.4	54	26.1	2.5	4.1	0.9
250011	Kefir de cabra, magro, natural, sólido	Leite e produtos lácteos	kefir de cabra, magro, natural, solido	36	0.4	0.1	3.9	3.6	0	4.3	0.2
250010	Kefir de cabra, natural, sólido	Leite e produtos lácteos	kefir de cabra, natural, solido	68	4.3	2.8	3.9	3.1	0	3.3	0.1
250006	Kefir, magro, natural, sólido	Leite e produtos lácteos	kefir, magro, natural, solido	30	0.1	0.1	3.6	3.6	0	3.4	0.1
250005	Kefir, natural, liquido	Leite e produtos lácteos	kefir, natural, liquido	62	3.3	2.2	4.4	3.8	0	3.3	0.1
250009	Kefir, natural, sólido	Leite e produtos lácteos	kefir, natural, solido	65	3.5	2.4	3.9	3.9	0	4.1	0.1
250008	Kefir, parcialmente desnatado, açucarado, aromatizado, liquido	Leite e produtos lácteos	kefir, parcialmente desnatado, acucarado, aromatizado, liquido	69	1.6	1.1	10	9.8	0	3.3	0.1
250007	Kefir, parcialmente desnatado, aromatizado, liquido	Leite e produtos lácteos	kefir, parcialmente desnatado, aromatizado, liquido	46	1.4	1	4.6	4.1	0	3.5	0.1
250004	Kefir, parcialmente desnatado, natural, liquido	Leite e produtos lácteos	kefir, parcialmente desnatado, natural, liquido	45	1.5	1	4.1	3.7	0	3.5	0.1
921	Lagosta cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	lagosta cozida	90	0.8	0.2	0.2	0	0	20.6	0.8
2120000016	Lagosta crua	Peixes, mariscos, anfíbios, répteis e invertebrados	lagosta crua	79	0.7	0.2	0.1	0	0	18.2	0.2
923	Lagostim cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	lagostim cozido	90	0.5	0.1	0.2	0	0	21.2	1.4
922	Lagostim cru	Peixes, mariscos, anfíbios, répteis e invertebrados	lagostim cru	89	0.5	0.1	0.2	0	0	20.9	0.8
1900000101	Lampreia crua	Peixes, mariscos, anfíbios, répteis e invertebrados	lampreia crua	314	27.4	5.8	0.1	0	0	16.7	0.9
2120000019	Lapas cruas	Peixes, mariscos, anfíbios, répteis e invertebrados	lapas cruas	66	0.7	0.1	0.6	0	0	14.3	1.1
658	Laranja (3 variedades)	Frutos e produtos derivados de frutos	laranja (3 variedades)	52	0.1	0	10.5	9.8	1.6	0.9	0
260003	Larvas de Tenebrio molitor, desidratadas	Anfíbios, répteis, e invertebrados terrestres	larvas de tenebrio molitor, desidratadas	500	29.3	8.2	3.1	0.1	6.7	52.7	0.2
1153	Lasanha à bolonhesa	Pratos compostos	lasanha a bolonhesa	183	12.4	5.8	9.2	2.5	0.7	7.7	0.8
1900000004	Lebre crua	Carne e produtos cárneos	lebre crua	113	3	1	0	0	0	21.6	0.2
230004	Leite achocolatado, sem lactose	Leite e produtos lácteos	leite achocolatado, sem lactose	58	1.4	1	7.5	7.4	0.6	3.5	0.1
29	Leite achocolatado, UHT	Leite e produtos lácteos	leite achocolatado, uht	65	1.3	0.8	9.7	9.3	0.4	3.4	0.1
34	Leite condensado	Leite e produtos lácteos	leite condensado	338	9	5.4	56.4	56.4	0	7.8	0.4
500	Leite creme	Leite e produtos lácteos	leite creme	163	6.8	2.3	19.5	18.5	0	5.9	0.1
19	Leite de cabra cru	Leite e produtos lácteos	leite de cabra cru	70	4	2.6	4.6	4.6	0	3.8	0.1
1205	Leite de coco, enlatado	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	leite de coco, enlatado	185	18.4	14	2.8	1.1	0	2	0
20	Leite de ovelha cru	Leite e produtos lácteos	leite de ovelha cru	93	6.2	3.3	4.2	4.2	0	5.1	0.1
35	Leite evaporado	Leite e produtos lácteos	leite evaporado	136	7.8	4.4	9.8	9.8	0	6.6	0.4
1900000067	Leite fermentado (Bifidus) gordo, natural	Leite e produtos lácteos	leite fermentado (bifidus) gordo, natural	67	3.6	2.2	4.5	4.5	0	4	0.1
1920000016	Leite fermentado (Bifidus) sem lactose enriquecido com fibra, magro, aromatizado, com pedaços e/ou polpa de fruta, com sementes e/ou cereais, com frutos secos e/ou de casca rija, com edulcor	Leite e produtos lácteos	leite fermentado (bifidus) sem lactose enriquecido com fibra, magro, aromatizado, com pedacos e/ou polpa de fruta, com sementes e/ou cereais, com frutos secos e/ou de casca rija, com edulcor	57	0.8	0.2	6.6	5.4	1.6	4.2	0.2
1920000017	Leite fermentado (Bifidus) sem lactose líquido, meio gordo, aromatizado, com pedaços e/ou polpa de fruta, açucarado	Leite e produtos lácteos	leite fermentado (bifidus) sem lactose liquido, meio gordo, aromatizado, com pedacos e/ou polpa de fruta, acucarado	71	1.7	1	11	10.7	0	2.7	0.1
1920000018	Leite fermentado (Bifidus) sem lactose magro, natural, com edulcorantes	Leite e produtos lácteos	leite fermentado (bifidus) sem lactose magro, natural, com edulcorantes	51	0.4	0.2	6.2	6.1	0	5.3	0.2
1920000014	Leite fermentado (Bifidus) sem lactose, gordo, natural	Leite e produtos lácteos	leite fermentado (bifidus) sem lactose, gordo, natural	70	3.7	2.4	4.8	4.8	0	4.2	0.1
1920000015	Leite fermentado (Bifidus) sem lactose, magro, aromatizado, com pedaços e/ou polpa de fruta e/ou hortícolas, açucarado, com edulcorantes	Leite e produtos lácteos	leite fermentado (bifidus) sem lactose, magro, aromatizado, com pedacos e/ou polpa de fruta e/ou horticolas, acucarado, com edulcorantes	57	0.4	0.2	8.2	7.9	0	4.9	0.2
30	Leite gordo especial, pasteurizado	Leite e produtos lácteos	leite gordo especial, pasteurizado	62	3.4	1.9	4.8	4.8	0	3.1	0.1
1900000064	Leite gordo sem lactose, enriquecido com vitaminas A, D, E e B9 (ácido fólico), UHT	Leite e produtos lácteos	leite gordo sem lactose, enriquecido com vitaminas a, d, e e b9 (acido folico), uht	62	3.5	2.2	4.6	4.6	0	3	0.1
22	Leite gordo, pasteurizado	Leite e produtos lácteos	leite gordo, pasteurizado	62	3.5	2	4.7	4.7	0	3	0.1
31	Leite gordo, pó	Leite e produtos lácteos	leite gordo, po	495	25.9	14.5	38.7	38.7	0	26.8	0.9
23	Leite gordo, UHT	Leite e produtos lácteos	leite gordo, uht	62	3.5	2	4.7	4.7	0	3	0.1
38	Leite humano	Leite e produtos lácteos	leite humano	66	3.4	1.5	7.5	7.5	0	1.4	0
36	Leite humano, colostro	Leite e produtos lácteos	leite humano, colostro	60	2.8	1.2	6.3	6.3	0	2.3	0.1
37	Leite humano, transição	Leite e produtos lácteos	leite humano, transicao	66	3.7	1.5	6.6	6.6	0	1.6	0.1
1233	Leite magro de pastagem, UHT	Leite e produtos lácteos	leite magro de pastagem, uht	33	0.1	0.1	4.9	4.8	0	3.1	0.1
230005	Leite magro sem lactose, enriquecido com proteína, aromatizado, UHT	Leite e produtos lácteos	leite magro sem lactose, enriquecido com proteina, aromatizado, uht	55	0.2	0.2	5	4.8	0.6	8	0.1
1900000062	Leite magro sem lactose, UHT	Leite e produtos lácteos	leite magro sem lactose, uht	36	0.2	0.1	5.1	4.9	0	3.4	0.1
33	Leite magro, pó	Leite e produtos lácteos	leite magro, po	359	0.9	0.5	52.7	52.7	0	35.1	1.3
27	Leite magro, UHT	Leite e produtos lácteos	leite magro, uht	35	0.2	0.1	4.9	4.9	0	3.4	0.1
1234	Leite meio gordo de pastagem, UHT	Leite e produtos lácteos	leite meio gordo de pastagem, uht	46	1.5	1	5	4.9	0	3	0.1
1900000063	Leite meio gordo sem lactose, UHT	Leite e produtos lácteos	leite meio gordo sem lactose, uht	48	1.6	0.9	5.1	4.9	0	3.3	0.1
32	Leite meio gordo, pó	Leite e produtos lácteos	leite meio gordo, po	427	13.5	7.6	45.6	45.6	0	30.7	1.1
25	Leite meio gordo, UHT	Leite e produtos lácteos	leite meio gordo, uht	47	1.6	0.9	4.9	4.9	0	3.3	0.1
220028	Lentilhas vermelhas, secas, cruas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	lentilhas vermelhas, secas, cruas	327	0.3	0.1	46.6	3.6	17.4	25.7	0
537	Lentilhas, secas, cruas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	lentilhas, secas, cruas	321	0.7	0.1	47.6	1.2	11.8	25.2	0
538	Lentilhas, secas, demolhadas, cozidas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	lentilhas, secas, demolhadas, cozidas	115	0.3	0	16.7	0.4	4.4	9.1	0.4
1900000091	Lichia fresca	Frutos e produtos derivados de frutos	lichia fresca	70	0.4	0.1	14.8	14.3	1.3	0.9	0
734	Licor beneditino	Bebidas alcoólicas	licor beneditino	352	0	0	34.8	34.8	0	0	0
733	Licor de anis	Bebidas alcoólicas	licor de anis	385	0	0	36	36	0	0	0
732	Licor de ginja	Bebidas alcoólicas	licor de ginja	239	0	0	19	19	0	0.1	0
735	Licor simples	Bebidas alcoólicas	licor simples	294	0	0	24.4	24.4	0	0	0
1900000096	Lima	Frutos e produtos derivados de frutos	lima	31	0.2	0	1.7	1.7	2.8	0.7	0
661	Limão	Frutos e produtos derivados de frutos	limao	31	0.3	0.1	1.9	1.9	2.1	0.5	0
845	Linguado cru	Peixes, mariscos, anfíbios, répteis e invertebrados	linguado cru	82	0.2	0	0	0	0	20.1	0.2
847	Linguado frito	Peixes, mariscos, anfíbios, répteis e invertebrados	linguado frito	164	6.2	0.7	2.7	0.1	0.1	24.3	1
846	Linguado grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	linguado grelhado	94	0.2	0	0	0	0	23.1	1
349	Linguiça	Carne e produtos cárneos	linguica	437	39	13.4	0	0	0	21.5	7.3
914	Lula crua	Peixes, mariscos, anfíbios, répteis e invertebrados	lula crua	71	0.9	0.2	0	0	0	15.8	0.5
916	Lula estufada com cebola, tomate e azeite	Pratos compostos	lula estufada com cebola, tomate e azeite	135	6.3	0.9	2.9	2.5	1.2	16.1	1.6
915	Lula grelhada	Peixes, mariscos, anfíbios, répteis e invertebrados	lula grelhada	144	1.6	0.5	0	0	0	32.5	2
40200010	Maçã (média com e sem casca)	Frutos e produtos derivados de frutos	maca (media com e sem casca)	57	0.5	0.1	12.2	11.4	1.4	0	0
668	Maçã assada com açúcar	Frutos e produtos derivados de frutos	maca assada com acucar	106	0.5	0.1	23.9	23.9	2.2	0.2	0
669	Maçã assada sem açúcar	Frutos e produtos derivados de frutos	maca assada sem acucar	75	0.5	0.1	15.7	15.7	2.6	0.3	0
662	Maçã com casca	Frutos e produtos derivados de frutos	maca com casca	64	0.5	0.1	13.4	13.4	2.1	0.2	0
666	Maçã cozida com açúcar	Frutos e produtos derivados de frutos	maca cozida com acucar	77	0.5	0.1	17	17	1.4	0.2	0
667	Maçã cozida sem açúcar	Frutos e produtos derivados de frutos	maca cozida sem acucar	51	0.5	0.1	10.5	10.5	1.6	0.2	0
1900000112	Maçã desidratada	Frutos e produtos derivados de frutos	maca desidratada	354	2.9	0.6	74.5	74.5	11.4	1.1	0.1
665	Maçã seca	Frutos e produtos derivados de frutos	maca seca	257	0.3	0.1	57.1	57.1	9.5	0.8	0.1
663	Maçã sem casca	Frutos e produtos derivados de frutos	maca sem casca	61	0.5	0.1	12.7	12.7	1.9	0.2	0
487	Madalena	Cereais e produtos à base de cereais	madalena	443	22.6	3	54.7	36.2	0.7	4.9	0.3
926	Maionese caseira, com ovo e azeite	Temperos, molhos e condimentos	maionese caseira, com ovo e azeite	657	71.2	10.6	0	0	0	4	0.3
927	Maionese caseira, com ovo e óleo de soja	Temperos, molhos e condimentos	maionese caseira, com ovo e oleo de soja	644	69.8	11.3	0	0	0	3.9	0.3
1900000013	Malagueta vermelha fresca	Produtos hortícolas e derivados	malagueta vermelha fresca	31	0.3	0	4.3	4.2	2	1.8	0
260001	Malagueta vermelha, desidratada	Leguminosas, nozes, oleaginosas e especiarias.	malagueta vermelha, desidratada	317	5.8	0.8	41.2	41.1	28.7	10.6	0.2
1900000058	Mandioca crua	Raízes amiláceas ou tubérculos e seus produtos, plantas sacarinas	mandioca crua	145	0.3	0.1	33.8	1.4	1.8	1	0
670	Manga	Frutos e produtos derivados de frutos	manga	59	0.3	0.1	11.7	11.5	2.9	0.5	0
1900000107	Manga desidratada	Frutos e produtos derivados de frutos	manga desidratada	340	1.7	0.6	67.4	66.2	16.7	2.9	0.2
1900000030	Manjericão fresco	Produtos hortícolas e derivados	manjericao fresco	48	0.8	0.1	5.1	5.1	3.9	3.1	0
1206	Manjericão seco	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	manjericao seco	244	4.1	2.2	10	1.7	37.7	23	0.2
1208	Manjerona seca	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	manjerona seca	320	7	1.2	42.5	42.5	18.1	12.7	0.2
385	Manteiga com sal	Óleos e gorduras de origem animal e vegetal e seus derivados	manteiga com sal	739	81.8	46.3	0.7	0.7	0	0.1	1.9
386	Manteiga sem sal	Óleos e gorduras de origem animal e vegetal e seus derivados	manteiga sem sal	750	83	47	0.7	0.7	0	0.1	0
1900000009	Maracujá	Frutos e produtos derivados de frutos	maracuja	52	0.4	0.1	5.7	5.7	3.3	2.6	0
100300002	Margarina	Óleos e gorduras de origem animal e vegetal e seus derivados	margarina	740	82	35.4	0.4	0.4	0	0.1	2.8
384	Margarina 3/4, de girassol	Óleos e gorduras de origem animal e vegetal e seus derivados	margarina 3/4, de girassol	524	58	13.7	0.3	0.3	0	0.1	0.6
380	Margarina culinária para folhados, com sal	Óleos e gorduras de origem animal e vegetal e seus derivados	margarina culinaria para folhados, com sal	772	85.5	31.4	0.4	0.4	0	0.1	2.4
379	Margarina industrial para pastelaria, com sal	Óleos e gorduras de origem animal e vegetal e seus derivados	margarina industrial para pastelaria, com sal	727	80.5	34.7	0.4	0.4	0	0.1	3
381	Margarina vegetal culinária, 80% gordura, com sal	Óleos e gorduras de origem animal e vegetal e seus derivados	margarina vegetal culinaria, 80% gordura, com sal	722	80	40.2	0.4	0.4	0	0.1	3
382	Margarina vegetal culinária, com alho e sal	Óleos e gorduras de origem animal e vegetal e seus derivados	margarina vegetal culinaria, com alho e sal	692	74.3	29.7	4.4	0.9	0.7	1	3
672	Marmelada	Açúcar e similares, confeitaria e sobremesas doces à base de água	marmelada	261	0.2	0	61.4	58	2	2.3	0
671	Marmelo	Frutos e produtos derivados de frutos	marmelo	53	0.2	0	9.3	9.3	6	0.3	0
849	Maruca cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	maruca cozida	73	0.1	0	0	0	0	17.9	1
848	Maruca crua	Peixes, mariscos, anfíbios, répteis e invertebrados	maruca crua	70	0.1	0	0	0	0	17.2	0.3
423	Massa com ovo cozida	Cereais e produtos à base de cereais	massa com ovo cozida	71	0.6	0.2	13.3	0.3	0.6	2.8	0.4
422	Massa com ovo crua	Cereais e produtos à base de cereais	massa com ovo crua	360	3.1	0.9	67.6	1.8	3	13.9	0
1165	Massa de pimentão	Temperos, molhos e condimentos	massa de pimentao	44	1	0.2	4.4	4.1	3.3	2.6	3.3
1209	Massa folhada, congelada	Cereais e produtos à base de cereais	massa folhada, congelada	398	27.5	10.3	31.8	0.2	1.4	5	0
418	Massa miúda crua	Cereais e produtos à base de cereais	massa miuda crua	356	1.8	0.4	70	2.2	5.1	12.4	0
425	Massa para lasanha cozida	Cereais e produtos à base de cereais	massa para lasanha cozida	115	0.7	0.1	22.6	0.8	1	4	0.6
424	Massa para lasanha crua	Cereais e produtos à base de cereais	massa para lasanha crua	359	2.1	0.4	71.4	2.6	3.1	12	0
1215	Massa para pizza	Cereais e produtos à base de cereais	massa para pizza	289	4.8	0.7	52.5	3.3	2.1	7.8	0.7
956	Massa quebrada para quiche	Cereais e produtos à base de cereais	massa quebrada para quiche	498	29.2	15.3	52.4	1.3	2	5.5	1.2
250012	Medronho	Frutos e produtos derivados de frutos	medronho	150	0.6	0.1	31.4	16.3	6.4	1.2	0.2
1037	Meia-desfeita de bacalhau	Pratos compostos	meia-desfeita de bacalhau	156	4.2	0.6	14.8	1.5	4.2	12.7	1.5
504	Mel	Açúcar e similares, confeitaria e sobremesas doces à base de água	mel	314	0	0	78	78	0	0.5	0
1900000069	Mel de cana	Açúcar e similares, confeitaria e sobremesas doces à base de água	mel de cana	311	0	0	77.4	77.4	0	0.3	0.7
1900000068	Melaço	Açúcar e similares, confeitaria e sobremesas doces à base de água	melaco	269	0.1	0	66.6	57.8	0	0.6	0.2
673	Melancia	Produtos hortícolas e derivados	melancia	32	0	0	7.3	7.3	0.4	0.6	0
674	Melão (3 variedades)	Produtos hortícolas e derivados	melao (3 variedades)	39	0.3	0.1	7.9	6.7	0.7	0.8	0
675	Meloa	Produtos hortícolas e derivados	meloa	39	0	0	8.2	7.6	0.7	1	0
485	Merengue	Cereais e produtos à base de cereais	merengue	353	0.5	0.2	83	83	0	4.1	0.2
910	Mexilhão cozido sem sal	Peixes, mariscos, anfíbios, répteis e invertebrados	mexilhao cozido sem sal	97	2.1	0.4	2.8	0	0	16.8	0.9
909	Mexilhão cru	Peixes, mariscos, anfíbios, répteis e invertebrados	mexilhao cru	70	1.5	0.3	2	0	0	12.1	0.7
1900000083	Milho doce em conserva	Produtos hortícolas e derivados	milho doce em conserva	110	1.9	0.3	18.4	5.2	3.7	2.9	0.6
452	Milho, amido (pó)	Ingredientes principais isolados, aditivos, aromas, fermentos e auxiliares tecnológicos	milho, amido (po)	364	0.2	0	90.2	0	0.1	0.4	0.1
412	Milho, grão seco cru	Cereais e produtos à base de cereais	milho, grao seco cru	368	4.9	0.8	70.3	0	2.9	9.3	0
220026	Millet, cru, seco	Cereais e produtos à base de cereais	millet, cru, seco	362	3.2	0.4	71.2	0.7	2	11.1	0
387	Minarina (meia margarina)	Óleos e gorduras de origem animal e vegetal e seus derivados	minarina (meia margarina)	380	41.6	14	0.4	0.4	0	0.9	0.4
1900000090	Mirtilo	Frutos e produtos derivados de frutos	mirtilo	43	0.6	0.1	6.4	6.4	3.1	0.5	0
1900000113	Mirtilo desidratado	Frutos e produtos derivados de frutos	mirtilo desidratado	317	4.4	0.7	46.8	46.8	22.7	3.7	0
220027	Miso, pasta de soja fermentada com arroz integral e cevada	Temperos, molhos e condimentos	miso, pasta de soja fermentada com arroz integral e cevada	177	6.5	1	15.1	13.7	5.2	11.9	9.9
928	Molho "Béchamel" com manteiga	Temperos, molhos e condimentos	molho "bechamel" com manteiga	130	8.4	4.7	9.6	5.3	0.2	4	0.6
929	Molho "Béchamel" com margarina	Temperos, molhos e condimentos	molho "bechamel" com margarina	140	9.5	4.8	9.9	5.4	0.2	3.6	0.7
930	Molho branco com caldo de carne de vaca	Temperos, molhos e condimentos	molho branco com caldo de carne de vaca	115	9.2	4.6	6.8	0.3	0.3	1.1	1.9
931	Molho branco com margarina	Temperos, molhos e condimentos	molho branco com margarina	244	16.8	8.8	18.5	4.2	0.8	4.4	1.4
934	Molho de bife frito com manteiga	Temperos, molhos e condimentos	molho de bife frito com manteiga	379	41	23.2	0.4	0.4	0	2	1.2
940	Molho de carne de vaca assada com azeite e margarina	Temperos, molhos e condimentos	molho de carne de vaca assada com azeite e margarina	586	64	19.5	0.3	0.3	0.1	2.1	1.2
941	Molho de carne de vaca assada com margarina	Temperos, molhos e condimentos	molho de carne de vaca assada com margarina	513	56	28	0.4	0.4	0.1	1.9	1.9
942	Molho de carne de vaca estufada com azeite e margarina	Temperos, molhos e condimentos	molho de carne de vaca estufada com azeite e margarina	260	27.9	7	0.4	0.3	0.1	1.7	0.6
943	Molho de carne de vaca estufada com vegetais, azeite e margarina	Temperos, molhos e condimentos	molho de carne de vaca estufada com vegetais, azeite e margarina	267	28.5	7.1	1.3	0.4	0.2	1.3	0.6
937	Molho de lombo de porco frito com banha	Temperos, molhos e condimentos	molho de lombo de porco frito com banha	551	60.2	15.9	0	0	0	2.2	0.2
938	Molho de lombo de porco frito com banha e margarina	Temperos, molhos e condimentos	molho de lombo de porco frito com banha e margarina	498	54.3	20.1	0.1	0.1	0	2.3	1.1
939	Molho de lombo de porco frito com margarina	Temperos, molhos e condimentos	molho de lombo de porco frito com margarina	447	48.5	24.3	0.2	0.2	0	2.3	1.6
936	Molho de lombo de vaca frito com creme vegetal sem sal	Temperos, molhos e condimentos	molho de lombo de vaca frito com creme vegetal sem sal	350	37.8	9.1	0.2	0.2	0	2.2	0.2
935	Molho de lombo de vaca frito com margarina	Temperos, molhos e condimentos	molho de lombo de vaca frito com margarina	372	40.3	20.2	0.2	0.2	0	2.2	1.7
1211	Molho de mostarda	Temperos, molhos e condimentos	molho de mostarda	444	40.2	0	18	16.3	0	2.6	0.8
2120000007	Molho de soja	Temperos, molhos e condimentos	molho de soja	89	0	0	17.3	15.9	0.8	4.7	14
932	Molho de tomate	Temperos, molhos e condimentos	molho de tomate	107	8.8	1.9	4.9	4.5	2	1.1	0.5
960	Molho de tomate, "ketchup"	Temperos, molhos e condimentos	molho de tomate, "ketchup"	119	0.3	0	26.9	25.8	1.1	1.7	3.1
1229	Molho de vinagrete	Temperos, molhos e condimentos	molho de vinagrete	648	71.8	10.1	0.2	0.2	0	0.2	1.8
1164	Molho para francesinha	Temperos, molhos e condimentos	molho para francesinha	74	2.6	1.2	4.8	2.5	0.2	1.1	0.7
933	Molho verde	Temperos, molhos e condimentos	molho verde	246	25.6	3.7	2.3	1.6	1.6	0.7	0.8
676	Morango	Frutos e produtos derivados de frutos	morango	32	0.2	0	6	5.3	0.6	0.6	0
1900000079	Morango desidratado	Frutos e produtos derivados de frutos	morango desidratado	322	3.8	0	50.9	50.9	19.2	5.8	0
350	Morcela crua	Carne e produtos cárneos	morcela crua	363	29.5	9.7	12	0.4	0.6	12	1.3
351	Morcela grelhada	Pratos compostos	morcela grelhada	339	25.9	8.6	13.1	0.4	0.7	12.9	1.3
352	Mortadela	Carne e produtos cárneos	mortadela	379	33.2	12.4	1.7	0	0	18.3	3.9
501	Mousse de chocolate	Pratos compostos	mousse de chocolate	285	13.1	5.7	31	30	2.3	9.5	0.2
2120000001	Múcua (fruto do embondeiro, baobab)	Frutos e produtos derivados de frutos	mucua (fruto do embondeiro, baobab)	212	0.1	0	16.3	12.6	67.3	2.8	0
1900000032	Nabiça crua	Produtos hortícolas e derivados	nabica crua	17	0	0	1.2	0	2.3	2	0.1
240004	Nabiças cozidas	Produtos hortícolas e derivados	nabicas cozidas	16	0	0	0.7	0	2.1	2.1	0.1
610	Nabo (raiz) cozido	Produtos hortícolas e derivados	nabo (raiz) cozido	19	0.4	0	2.3	2.2	2.2	0.4	0.3
609	Nabo (raiz) cru	Produtos hortícolas e derivados	nabo (raiz) cru	21	0.4	0	3	2.9	2	0.4	0.1
62	Nata maturada pasteurizada 30% gordura	Leite e produtos lácteos	nata maturada pasteurizada 30% gordura	306	32	18	2.7	2.7	0	1.9	0.1
66	Nata para bater pasteurizada 34% gordura	Leite e produtos lácteos	nata para bater pasteurizada 34% gordura	323	34	19	2.1	2.1	0	2.2	0.1
65	Nata pasteurizada 33% gordura	Leite e produtos lácteos	nata pasteurizada 33% gordura	317	33	18.5	2.9	2.9	0	2	0.1
63	Nata pasteurizada 36% gordura	Leite e produtos lácteos	nata pasteurizada 36% gordura	340	36	20.2	1.9	1.9	0	2	0.1
64	Nata pasteurizada para café, 15% gordura	Leite e produtos lácteos	nata pasteurizada para cafe, 15% gordura	153	15	8.4	2.4	2.4	0	2	0.1
67	Nata UHT 35% gordura	Leite e produtos lácteos	nata uht 35% gordura	335	35	20	3.1	3.1	0	1.8	0.1
754	Néctar de "tutti - frutti"	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	nectar de "tutti - frutti"	46	0.1	0	10.8	10.8	0.2	0.1	0
748	Néctar de alperce	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	nectar de alperce	56	0.1	0	12.9	12.9	0.4	0.2	0
749	Néctar de ananás	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	nectar de ananas	46	0.1	0	10.5	10.5	0.2	0.2	0
750	Néctar de laranja	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	nectar de laranja	43	0.1	0	9.6	9.6	0.4	0.2	0
751	Néctar de maçã	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	nectar de maca	48	0.1	0	11.3	11.3	0.5	0.1	0
757	Néctar de maçã, "light"	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	nectar de maca, "light"	22	0.2	0	4.6	4.6	0.1	0.1	0
752	Néctar de pera	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	nectar de pera	48	0.1	0	11	11	0.6	0.2	0
753	Néctar de pêssego	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	nectar de pessego	51	0.1	0	11.7	11.7	0.5	0.2	0
762	Néctar de pêssego, "light"	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	nectar de pessego, "light"	18	0.1	0	3.5	3.5	0	0.1	0
688	Nectarina	Frutos e produtos derivados de frutos	nectarina	49	0.1	0	8.7	8.7	2.2	1.4	0
678	Nêspera	Frutos e produtos derivados de frutos	nespera	51	0.4	0.1	10.2	10.2	2.1	0.4	0
1212	Noz-moscada	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	noz-moscada	506	36.3	12.1	28.5	24.5	20.8	5.8	0
1900000050	Noz macadâmia	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	noz macadamia	752	76	12	5.1	4	8	8	0
1900000049	Noz pecan	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	noz pecan	729	72.6	6.6	5.4	3.9	8.3	9.4	0
708	Noz, miolo	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	noz, miolo	699	67.5	5.4	3.6	2.6	5.2	16.7	0
389	Óleo "Becel"	Óleos e gorduras de origem animal e vegetal e seus derivados	oleo "becel"	887	98.5	11.1	0	0	0	0	0
392	Óleo alimentar	Óleos e gorduras de origem animal e vegetal e seus derivados	oleo alimentar	896	99.5	11.3	0	0	0	0	0
388	Óleo de amendoim	Óleos e gorduras de origem animal e vegetal e seus derivados	oleo de amendoim	887	98.5	17.5	0	0	0	0	0
1900000092	Óleo de coco	Óleos e gorduras de origem animal e vegetal e seus derivados	oleo de coco	900	100	86.5	0	0	0	0	0
390	Óleo de girassol	Óleos e gorduras de origem animal e vegetal e seus derivados	oleo de girassol	896	99.5	11.6	0	0	0	0	0
2120000009	Óleo de linhaça	Óleos e gorduras de origem animal e vegetal e seus derivados	oleo de linhaca	900	100	7.9	0	0	0	0	0
391	Óleo de milho	Óleos e gorduras de origem animal e vegetal e seus derivados	oleo de milho	896	99.5	13.3	0	0	0	0	0
394	Óleo de palma	Óleos e gorduras de origem animal e vegetal e seus derivados	oleo de palma	900	100	47.8	0	0	0	0	0
393	Óleo de soja	Óleos e gorduras de origem animal e vegetal e seus derivados	oleo de soja	887	98.5	15.5	0	0	0	0	0
1072	Omelete	Pratos compostos	omelete	136	9.5	2.4	0.2	0.2	0.6	12	1
93	Omelete com manteiga	Pratos compostos	omelete com manteiga	199	16.3	5.8	0	0	0	13	1.3
94	Omelete com margarina	Pratos compostos	omelete com margarina	198	16.2	5.4	0	0	0	13	1.4
1213	Orégão seco	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	oregao seco	265	4.3	1.6	26.4	4.1	42.5	9	0.1
911	Ostra, crua	Peixes, mariscos, anfíbios, répteis e invertebrados	ostra, crua	65	1.7	0.3	3.9	0	0	8.6	0.9
1900000057	Ovo de codorniz, cru	Ovos e ovoprodutos	ovo de codorniz, cru	150	10.7	3	0.4	0.4	0	12.9	0.3
83	Ovo de galinha inteiro, cru	Ovos e ovoprodutos	ovo de galinha inteiro, cru	143	10.1	2.7	0.5	0.5	0	12.6	0
95	Ovo de galinha líquido, pasteurizado	Ovos e ovoprodutos	ovo de galinha liquido, pasteurizado	131	9.3	2.3	0	0	0	11.9	0.3
86	Ovo de galinha, cozido	Ovos e ovoprodutos	ovo de galinha, cozido	149	10.8	2.7	0	0	0	13	0.4
87	Ovo de galinha, escalfado	Ovos e ovoprodutos	ovo de galinha, escalfado	150	10.9	2.7	0	0	0	13	0.4
90000015	Ovo de galinha, estrelado	Ovos e ovoprodutos	ovo de galinha, estrelado	193	15.4	2.7	0	0	0	13.7	0.6
90	Ovo de galinha, estrelado com azeite	Ovos e ovoprodutos	ovo de galinha, estrelado com azeite	191	15.1	3.4	0	0	0	13.8	0.6
88	Ovo de galinha, estrelado com manteiga	Ovos e ovoprodutos	ovo de galinha, estrelado com manteiga	194	15.5	5.2	0	0	0	13.7	0.7
89	Ovo de galinha, estrelado com margarina	Ovos e ovoprodutos	ovo de galinha, estrelado com margarina	194	15.5	4.9	0	0	0	13.7	0.7
91	Ovo de galinha, mexido com manteiga	Pratos compostos	ovo de galinha, mexido com manteiga	197	16.1	5.7	0	0	0	13	0.8
92	Ovo de galinha, mexido com margarina	Pratos compostos	ovo de galinha, mexido com margarina	196	16	5.3	0	0	0	13	0.9
1123	Ovo mexido com leite e margarina	Pratos compostos	ovo mexido com leite e margarina	213	18.3	7	0.9	0.9	0.2	11	1.3
353	Paio de lombo	Carne e produtos cárneos	paio de lombo	288	19	6.5	0	0	0	29.2	8.8
354	Paio de lombo entremeado	Carne e produtos cárneos	paio de lombo entremeado	361	30	13.7	0	0	0	22.8	4.4
426	Pão de centeio	Cereais e produtos à base de cereais	pao de centeio	268	0.8	0.1	56.4	2.2	5.8	5.9	1.3
427	Pão de centeio integral	Cereais e produtos à base de cereais	pao de centeio integral	229	2.1	0.3	41.3	1.6	7.1	7.7	0.6
432	Pão de forma, de trigo com passas	Cereais e produtos à base de cereais	pao de forma, de trigo com passas	291	2	0.4	58.3	5.3	3.5	8.3	0.7
431	Pão de forma, de trigo enriquecido	Cereais e produtos à base de cereais	pao de forma, de trigo enriquecido	284	2.7	0.6	54.5	2	3.2	8.7	1
438	Pão de leite (trigo)	Cereais e produtos à base de cereais	pao de leite (trigo)	259	1.9	0.5	51.4	3.1	2.5	7.7	1.1
486	Pão de ló	Cereais e produtos à base de cereais	pao de lo	361	8	2.5	62.2	36.1	1	9.6	0.3
428	Pão de milho	Cereais e produtos à base de cereais	pao de milho	188	1.2	0.2	37.2	0	3.7	5.3	0.7
430	Pão de mistura de trigo e centeio	Cereais e produtos à base de cereais	pao de mistura de trigo e centeio	272	1.4	0.3	53.8	2	4.3	9	1.5
429	Pão de trigo	Cereais e produtos à base de cereais	pao de trigo	290	2.2	0.5	57.3	2.1	3.8	8.4	1.5
437	Pão de trigo com redução de sal	Cereais e produtos à base de cereais	pao de trigo com reducao de sal	248	1.2	0.3	51	1.9	2.8	7	0.2
433	Pão de trigo integral	Cereais e produtos à base de cereais	pao de trigo integral	232	3	0.7	39.9	2.2	7.4	7.6	1.2
436	Pão de trigo integral com passas	Cereais e produtos à base de cereais	pao de trigo integral com passas	247	2.6	0.6	44	8.5	9.1	7.4	0.2
434	Pão de trigo integral com sementes de sésamo	Cereais e produtos à base de cereais	pao de trigo integral com sementes de sesamo	256	4	0.9	43.2	2.3	8.2	7.7	0.1
435	Pão de trigo integral com soja	Cereais e produtos à base de cereais	pao de trigo integral com soja	233	2.8	0.5	38.2	2.4	8.6	9.4	0.5
1214	Pão pita	Cereais e produtos à base de cereais	pao pita	218	1.1	0.1	42.7	1.8	3.1	7.7	1.1
18	Pão ralado	Cereais e produtos à base de cereais	pao ralado	359	2.3	0.6	71.6	2.6	3.4	11.2	1.1
679	Papaia	Frutos e produtos derivados de frutos	papaia	45	0.1	0	9.1	6	2.3	0.6	0.1
1900000103	Papaia desidratada	Frutos e produtos derivados de frutos	papaia desidratada	361	0.8	0	73.3	48.3	18.5	4.8	0.4
852	Pargo legítimo assado com cebola, tomate e azeite	Pratos compostos	pargo legitimo assado com cebola, tomate e azeite	136	6.7	0.9	1.4	1.2	0.5	15.9	0.9
851	Pargo legítimo cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	pargo legitimo cozido	82	0.3	0	0	0	0	19.8	0.8
850	Pargo legítimo cru	Peixes, mariscos, anfíbios, répteis e invertebrados	pargo legitimo cru	79	0.2	0	0	0	0	19.4	0.2
855	Pargo mulato assado com cebola, tomate e azeite	Pratos compostos	pargo mulato assado com cebola, tomate e azeite	137	7.1	1	1.4	1.2	0.5	15.2	1
854	Pargo mulato cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	pargo mulato cozido	85	1	0.1	0	0	0	19	0.9
853	Pargo mulato cru	Peixes, mariscos, anfíbios, répteis e invertebrados	pargo mulato cru	80	0.7	0.1	0	0	0	18.5	0.2
356	Pasta de aves (paté), caseira	Carne e produtos cárneos	pasta de aves (pate), caseira	288	17.5	5.5	4.7	0.5	0.3	26.9	1.8
355	Pasta de fígado de porco (paté)	Carne e produtos cárneos	pasta de figado de porco (pate)	363	34.5	10	3.2	2.6	0	10	2
953	Pastel de bacalhau	Pratos compostos	pastel de bacalhau	227	13.4	1.8	12.3	0.9	1.2	13.8	1.2
488	Pastel de feijão	Cereais e produtos à base de cereais	pastel de feijao	322	9.4	3.6	52	33.7	1.3	6.8	0.2
489	Pastel de nata	Cereais e produtos à base de cereais	pastel de nata	275	10.6	4.6	38.3	27.3	3.8	4.7	0.3
370	Pastel folhado	Pratos compostos	pastel folhado	415	26	11.1	37.4	2.1	1.5	7.1	1.5
521	Pastilha elástica	Açúcar e similares, confeitaria e sobremesas doces à base de água	pastilha elastica	328	0	0	75.1	73.4	0	6.9	0.1
280	Pato com pele, assado sem molho	Carne e produtos cárneos	pato com pele, assado sem molho	347	30.3	7.7	0	0	0	18.5	0.8
277	Pato com pele, cru	Carne e produtos cárneos	pato com pele, cru	394	38.3	9.7	0	0	0	12.3	0.2
281	Pato sem pele, assado com margarina	Carne e produtos cárneos	pato sem pele, assado com margarina	276	14.6	4.5	0	0	0	36.2	1.7
278	Pato sem pele, cru	Carne e produtos cárneos	pato sem pele, cru	133	6.2	1.6	0	0	0	19.3	0.2
279	Pato sem pele, estufado com margarina	Pratos compostos	pato sem pele, estufado com margarina	232	13.7	4.8	0	0	0	27.2	1.5
856	Peixe-espada-branco cru	Peixes, mariscos, anfíbios, répteis e invertebrados	peixe-espada-branco cru	117	4	1	0	0	0	20.3	0.2
858	Peixe-espada-branco frito	Peixes, mariscos, anfíbios, répteis e invertebrados	peixe-espada-branco frito	159	6.3	1	2.9	0.1	0.1	22.7	0.8
857	Peixe-espada-branco grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	peixe-espada-branco grelhado	123	4.7	1.2	0	0	0	20.2	2
859	Peixe-espada-preto cru	Peixes, mariscos, anfíbios, répteis e invertebrados	peixe-espada-preto cru	88	2.8	0.5	0	0	0	15.7	0.4
861	Peixe-espada-preto frito	Peixes, mariscos, anfíbios, répteis e invertebrados	peixe-espada-preto frito	259	16.6	1.8	3.2	0.1	0.1	24.2	1.1
860	Peixe-espada-preto grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	peixe-espada-preto grelhado	111	3.2	0.6	0	0	0	20.5	1.2
1082	Peixinhos da horta	Pratos compostos	peixinhos da horta	94	1.4	0.4	14.9	2.5	2.9	4	0.7
611	Pepino cru	Produtos hortícolas e derivados	pepino cru	19	0.6	0.2	1.7	1.6	0.7	1.4	0
680	Pera (5 variedades)	Frutos e produtos derivados de frutos	pera (5 variedades)	57	0.4	0	12.2	9.2	1.9	0.1	0
683	Pera conserva em calda de açúcar	Frutos e produtos derivados de frutos	pera conserva em calda de acucar	121	0.3	0	28.9	28.9	1	0.2	0
681	Pera cozida com açúcar	Frutos e produtos derivados de frutos	pera cozida com acucar	67	0.4	0	14.5	14.5	1.7	0.3	0
682	Pera cozida sem açúcar	Frutos e produtos derivados de frutos	pera cozida sem acucar	40	0.4	0	7.8	7.8	1.8	0.3	0
684	Pera cristalizada	Frutos e produtos derivados de frutos	pera cristalizada	285	0.1	0	69.8	69.8	2.2	0.2	0.2
1900000109	Pera desidratada	Frutos e produtos derivados de frutos	pera desidratada	300	2.6	0	59.9	59.9	14	1.9	0.1
2120000018	Percebes crus	Peixes, mariscos, anfíbios, répteis e invertebrados	percebes crus	59	0.5	0	0	0	0	13.6	0
305	Perdiz crua	Carne e produtos cárneos	perdiz crua	104	1.3	0.4	0	0	0	23	0.2
306	Perdiz estufada com margarina	Pratos compostos	perdiz estufada com margarina	212	11.4	5.2	0.7	0.4	0.2	24.7	1.5
285	Peru inteiro com pele, cru	Carne e produtos cárneos	peru inteiro com pele, cru	137	6.1	2	0	0	0	20.5	0.1
1034	Peru, hambúrguer frito	Pratos compostos	peru, hamburguer frito	56	0.7	0.1	3	2.2	1.4	8.8	1.1
282	Peru, peito com pele, cru	Carne e produtos cárneos	peru, peito com pele, cru	134	4.7	1.5	0	0	0	23	0.2
287	Peru, peito sem pele estufado com margarina	Pratos compostos	peru, peito sem pele estufado com margarina	163	7.1	2.7	1.3	1.1	0.5	23.1	1.2
290	Peru, peito sem pele panado	Pratos compostos	peru, peito sem pele panado	226	9.9	1.5	8.4	0.3	0.4	25.5	0.6
288	Peru, peito sem pele, assado com margarina	Carne e produtos cárneos	peru, peito sem pele, assado com margarina	175	6.4	2.8	0.1	0.1	0	28.9	1.1
284	Peru, peito sem pele, cru	Carne e produtos cárneos	peru, peito sem pele, cru	105	1.3	0.3	0	0	0	23.4	0.2
289	Peru, perna com pele, assada com margarina	Carne e produtos cárneos	peru, perna com pele, assada com margarina	212	12.5	4.4	0	0	0	24.4	1.2
283	Peru, perna com pele, crua	Carne e produtos cárneos	peru, perna com pele, crua	149	8.1	2.6	0	0	0	18.9	0.2
286	Peru, perna com pele, estufada com margarina	Pratos compostos	peru, perna com pele, estufada com margarina	170	9.7	3.4	1.3	1.1	0.5	19.1	1.2
967	Pescada cozida (valor médio)	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada cozida (valor medio)	109	3.6	0.8	0	0	0	19.2	0.5
966	Pescada crua (valor médio)	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada crua (valor medio)	83	1.4	0.2	0	0	0	17.6	0.3
863	Pescada da África do Sul cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada da africa do sul cozida	110	3.8	0.8	0	0	0	18.9	0.6
862	Pescada da África do Sul crua	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada da africa do sul crua	81	1.3	0.2	0	0	0	17.2	0.3
864	Pescada da África do Sul frita	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada da africa do sul frita	175	8.4	1	1.7	0	0	23.2	2.4
866	Pescada do Chile cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada do chile cozida	108	3.3	0.7	0	0	0	19.5	0.4
865	Pescada do Chile crua	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada do chile crua	86	1.5	0.3	0	0	0	18	0.2
867	Pescada do Chile frita	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada do chile frita	171	8.8	1	2.6	0	0	20.3	2.2
869	Pescada europeia cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada europeia cozida	114	3.7	0.9	0	0	0	20.1	0.4
868	Pescada europeia crua	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada europeia crua	75	0.8	0.1	0	0	0	17	0.2
965	Pescada europeia frita	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada europeia frita	164	7.9	0.8	1.4	0	0	21.7	2
968	Pescada frita (valor médio)	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada frita (valor medio)	173	8.6	1	2.1	0	0	21.7	2.3
2120000017	Pescada, ovas cruas	Peixes, mariscos, anfíbios, répteis e invertebrados	pescada, ovas cruas	83	2.9	0.5	0	0	0	14.3	0
685	Pêssego (2 variedades)	Frutos e produtos derivados de frutos	pessego (2 variedades)	50	0	0	10.6	10.6	1.2	0.8	0
686	Pêssego, conserva em calda de açúcar	Frutos e produtos derivados de frutos	pessego, conserva em calda de acucar	85	0	0	20.6	20.6	0.5	0.5	0
1900000081	Picles de pepino	Produtos hortícolas e derivados	picles de pepino	74	0.5	0.2	16.5	12.5	0.5	0.5	0.7
1900000046	Pimenta branca	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	pimenta branca	306	2.1	0.6	48.3	0.6	26.2	10.4	0
961	Pimenta moída	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	pimenta moida	273	2.7	0.9	38.3	38.3	26.5	10.7	0.1
1900000047	Pimenta preta	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	pimenta preta	302	3.3	1.4	44.5	0.6	25.9	10.7	0.1
612	Pimento cru	Produtos hortícolas e derivados	pimento cru	27	0.6	0.1	2.7	2.5	2	1.6	0
613	Pimento grelhado	Produtos hortícolas e derivados	pimento grelhado	32	0.6	0.1	4.9	3.5	1.5	1	0
709	Pinhão, miolo	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	pinhao, miolo	622	51.7	3.5	5	2.4	1.9	33.2	0
710	Pistácio torrado e salgado	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	pistacio torrado e salgado	616	53	6.7	12.6	8.8	8.5	18	1.6
1900000051	Pistácio torrado, sem sal	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	pistacio torrado, sem sal	616	53	6.7	12.6	8.8	8.5	18	0
954	Pizza de queijo e tomate	Pratos compostos	pizza de queijo e tomate	271	10.1	3.3	33.2	2.2	2.3	10.5	1
955	Pizza de queijo, tomate e fiambre	Pratos compostos	pizza de queijo, tomate e fiambre	281	12.5	4.2	29.2	2	2	11.7	1.5
918	Polvo cozido sem sal	Peixes, mariscos, anfíbios, répteis e invertebrados	polvo cozido sem sal	103	1.3	0.3	0	0	0	22.7	0.4
917	Polvo cru	Peixes, mariscos, anfíbios, répteis e invertebrados	polvo cru	73	1.2	0.3	0	0	0	15.6	0.7
1900000005	Pombo cru	Carne e produtos cárneos	pombo cru	232	16.7	7.5	0	0	0	20.3	0.1
1216	Porco, baço	Carne e produtos cárneos	porco, baco	107	3.8	1.2	0.4	0.4	0	17.8	0.3
1145	Porco, bife grelhado	Carne e produtos cárneos	porco, bife grelhado	203	14.2	6.8	0.7	0.6	0.9	16.7	0.6
1217	Porco, cabeça	Carne e produtos cárneos	porco, cabeca	355	32.9	9.3	0.3	0.3	0	14.3	0.3
2120000010	Porco, chispe	Carne e produtos cárneos	porco, chispe	369	33.8	14.6	0.2	0	0	16.1	0.2
315	Porco, coração cru	Carne e produtos cárneos	porco, coracao cru	113	4.4	1.5	0	0	0	18.4	0.3
316	Porco, coração estufado com banha e margarina	Pratos compostos	porco, coracao estufado com banha e margarina	193	10.5	3.8	1	0.7	0.4	20.9	1.4
151	Porco, costeleta gorda crua	Carne e produtos cárneos	porco, costeleta gorda crua	355	31.8	10.9	0	0	0	17.3	0.2
177	Porco, costeleta gorda grelhada	Carne e produtos cárneos	porco, costeleta gorda grelhada	305	23.1	7.9	0	0	0	24.3	0.5
1146	Porco, costeleta grelhada	Carne e produtos cárneos	porco, costeleta grelhada	212	14.4	4.9	0.8	0.8	0.8	18.1	1
152	Porco, costeleta meio gorda crua	Carne e produtos cárneos	porco, costeleta meio gorda crua	221	15.8	5.4	0	0	0	19.8	0.3
70204038	Porco, costeleta meio gorda estufada	Pratos compostos	porco, costeleta meio gorda estufada	277	20.5	3.9	0.7	0.5	0.2	21.1	1.3
166	Porco, costeleta meio gorda estufada com azeite e banha	Pratos compostos	porco, costeleta meio gorda estufada com azeite e banha	280	20.7	6.5	0.7	0.5	0.2	21.1	1.1
168	Porco, costeleta meio gorda estufada com azeite e margarina	Pratos compostos	porco, costeleta meio gorda estufada com azeite e margarina	277	20.4	6.7	0.7	0.5	0.2	21.1	1.2
167	Porco, costeleta meio gorda estufada com margarina	Pratos compostos	porco, costeleta meio gorda estufada com margarina	272	19.9	7.3	0.7	0.5	0.2	21.1	1.2
165	Porco, costeleta meio gorda estufada com óleo alimentar e banha	Pratos compostos	porco, costeleta meio gorda estufada com oleo alimentar e banha	280	20.7	6.4	0.7	0.5	0.2	21.1	1.1
158	Porco, costeleta meio gorda estufada, sem molho	Carne e produtos cárneos	porco, costeleta meio gorda estufada, sem molho	284	19.6	6.7	0	0	0	26.9	0.7
191	Porco, costeleta meio gorda frita panada	Pratos compostos	porco, costeleta meio gorda frita panada	341	24.1	6.5	8.6	0.3	0.4	22.1	1
178	Porco, costeleta meio gorda grelhada	Carne e produtos cárneos	porco, costeleta meio gorda grelhada	261	17	5.9	0	0	0	27	0.6
157	Porco, entrecosto cozido	Carne e produtos cárneos	porco, entrecosto cozido	235	14.2	4.8	0	0	0	26.9	0.5
156	Porco, entrecosto cru	Carne e produtos cárneos	porco, entrecosto cru	190	12.4	4.2	0	0	0	19.6	0.2
162	Porco, entrecosto estufado com azeite e banha	Pratos compostos	porco, entrecosto estufado com azeite e banha	246	17.1	5.2	0.7	0.5	0.2	20.9	1.1
164	Porco, entrecosto estufado com azeite e margarina	Pratos compostos	porco, entrecosto estufado com azeite e margarina	244	16.8	5.4	0.7	0.5	0.2	20.9	1.1
163	Porco, entrecosto estufado com margarina	Pratos compostos	porco, entrecosto estufado com margarina	239	16.3	6	0.7	0.5	0.2	20.9	1.2
161	Porco, entrecosto estufado com óleo alimentar e banha	Pratos compostos	porco, entrecosto estufado com oleo alimentar e banha	246	17.1	5.1	0.7	0.5	0.2	20.9	1.1
159	Porco, entrecosto estufado sem molho	Carne e produtos cárneos	porco, entrecosto estufado sem molho	245	15.4	5.2	0	0	0	26.6	0.3
173	Porco, entrecosto grelhado	Carne e produtos cárneos	porco, entrecosto grelhado	243	15.1	5.1	0	0	0	26.8	0.5
1144	Porco, espetada grelhada	Carne e produtos cárneos	porco, espetada grelhada	285	24.8	8.4	1.3	1.2	1	13.6	1.1
321	Porco, fígado cru	Carne e produtos cárneos	porco, figado cru	129	5	1.7	0	0	0	20.9	0.3
323	Porco, fígado frito com margarina e banha	Carne e produtos cárneos	porco, figado frito com margarina e banha	211	13.1	4.7	0	0	0	23.2	1.3
337	Porco, fígado frito sem molho	Carne e produtos cárneos	porco, figado frito sem molho	180	8.8	3.1	0	0	0	25.2	0.7
322	Porco, fígado grelhado	Carne e produtos cárneos	porco, figado grelhado	162	6.3	2.2	0	0	0	26.3	0.7
295	Porco, hambúrguer frito, sem molho	Pratos compostos	porco, hamburguer frito, sem molho	264	17.1	5.8	0	0	0	27.5	0.6
296	Porco, hambúrguer grelhado	Pratos compostos	porco, hamburguer grelhado	261	16.6	5.7	0	0	0	27.8	0.6
2120000011	Porco, jarrete	Carne e produtos cárneos	porco, jarrete	140	6	2.1	0.1	0	0	21.4	0.3
1900000008	Porco, língua crua	Carne e produtos cárneos	porco, lingua crua	220	17.2	6	0	0	0	16.3	0.3
70204048	Porco, lombo assado	Carne e produtos cárneos	porco, lombo assado	220	11.3	2.8	0.2	0.2	0	27.5	1.2
187	Porco, lombo assado com azeite e margarina	Carne e produtos cárneos	porco, lombo assado com azeite e margarina	219	11.1	3.6	0.2	0.2	0	27.5	1.2
185	Porco, lombo assado com margarina	Carne e produtos cárneos	porco, lombo assado com margarina	208	10.6	4.2	0	0	0	28.2	1.1
186	Porco, lombo assado com óleo alimentar e margarina	Carne e produtos cárneos	porco, lombo assado com oleo alimentar e margarina	219	11.1	3.5	0.2	0.2	0	27.5	1.2
180	Porco, lombo assado, sem molho	Carne e produtos cárneos	porco, lombo assado, sem molho	210	8.8	3	0	0	0	32.7	0.5
153	Porco, lombo cru	Carne e produtos cárneos	porco, lombo cru	131	4.7	1.6	0	0	0	22.2	0.1
70204054	Porco, lombo frito	Carne e produtos cárneos	porco, lombo frito	182	7.4	2.6	0	0	0	28.8	0.4
193	Porco, lombo frito com manteiga	Carne e produtos cárneos	porco, lombo frito com manteiga	180	7.2	2.6	0	0	0	28.8	0.4
194	Porco, lombo frito com margarina	Carne e produtos cárneos	porco, lombo frito com margarina	184	7.6	2.6	0	0	0	28.8	0.4
192	Porco, lombo frito panado	Pratos compostos	porco, lombo frito panado	249	12.5	2.7	8.5	0.3	0.4	25.3	0.9
176	Porco, lombo grelhado	Carne e produtos cárneos	porco, lombo grelhado	189	8.1	2.8	0	0	0	29.1	0.4
1219	Porco, orelha crua	Carne e produtos cárneos	porco, orelha crua	128	2.5	0.8	0.3	0.3	0	26	0.3
1221	Porco, pé cru	Carne e produtos cárneos	porco, pe cru	335	20.4	8.8	0	0	0	38	1.6
182	Porco, perna gorda assada com azeite e margarina	Carne e produtos cárneos	porco, perna gorda assada com azeite e margarina	353	28.2	9.4	0.2	0.2	0	22.4	1.2
184	Porco, perna gorda assada com margarina	Carne e produtos cárneos	porco, perna gorda assada com margarina	347	27.6	10.2	0.2	0.2	0	22.4	1.3
183	Porco, perna gorda assada com óleo alimentar e margarina	Carne e produtos cárneos	porco, perna gorda assada com oleo alimentar e margarina	353	28.2	9.3	0.2	0.2	0	22.4	1.2
181	Porco, perna gorda assada, sem molho	Carne e produtos cárneos	porco, perna gorda assada, sem molho	283	19.2	7.6	0	0	0	27.6	0.5
154	Porco, perna gorda crua	Carne e produtos cárneos	porco, perna gorda crua	239	18.5	6.3	0	0	0	18.1	0.1
175	Porco, perna gorda grelhada	Carne e produtos cárneos	porco, perna gorda grelhada	287	20.6	7	0	0	0	25.5	0.5
188	Porco, perna magra assada com azeite e margarina	Carne e produtos cárneos	porco, perna magra assada com azeite e margarina	245	14.6	4.8	0.2	0.2	0	26	1.3
190	Porco, perna magra assada com margarina	Carne e produtos cárneos	porco, perna magra assada com margarina	239	14	5.6	0.2	0.2	0	26	1.4
189	Porco, perna magra assada com óleo alimentar e margarina	Carne e produtos cárneos	porco, perna magra assada com oleo alimentar e margarina	244	14.5	4.7	0.2	0.2	0	26	1.3
179	Porco, perna magra assada, sem molho	Carne e produtos cárneos	porco, perna magra assada, sem molho	213	9.9	3.4	0	0	0	31	0.6
155	Porco, perna magra crua	Carne e produtos cárneos	porco, perna magra crua	152	7.5	2.6	0	0	0	21	0.2
170	Porco, perna magra estufada com azeite e banha	Pratos compostos	porco, perna magra estufada com azeite e banha	206	11.9	3.5	0.7	0.5	0.2	22.4	1.1
169	Porco, perna magra estufada com azeite e margarina	Pratos compostos	porco, perna magra estufada com azeite e margarina	203	11.6	3.7	0.7	0.5	0.2	22.4	1.1
171	Porco, perna magra estufada com margarina	Pratos compostos	porco, perna magra estufada com margarina	198	11.1	4.3	0.7	0.5	0.2	22.4	1.2
172	Porco, perna magra estufada com óleo alimentar e banha	Pratos compostos	porco, perna magra estufada com oleo alimentar e banha	206	11.9	3.4	0.7	0.5	0.2	22.4	1.1
160	Porco, perna magra estufada, sem molho	Carne e produtos cárneos	porco, perna magra estufada, sem molho	213	11	3.8	0	0	0	28.6	0.7
174	Porco, perna magra grelhada	Carne e produtos cárneos	porco, perna magra grelhada	215	11.7	4.1	0	0	0	27.5	0.5
1222	Porco, pulmões crus	Carne e produtos cárneos	porco, pulmoes crus	101	5	0.9	0.2	0.2	0	13.9	0.4
334	Porco, rim cru	Carne e produtos cárneos	porco, rim cru	95	3	1	0	0	0	17	0.7
335	Porco, rim frito com margarina	Carne e produtos cárneos	porco, rim frito com margarina	206	12.4	5.6	0	0	0	23.6	1.4
1032	Porco, rojões de carne gorda	Pratos compostos	porco, rojoes de carne gorda	244	19	6.1	0.8	0.1	0.3	14.9	0.8
1031	Porco, rojões de carne magra	Pratos compostos	porco, rojoes de carne magra	140	5.6	1.6	8.7	0.6	0.8	11.1	0.7
1223	Porco, sangue cru	Carne e produtos cárneos	porco, sangue cru	72	0.4	0.1	0.4	0.1	0	16.6	0.5
307	Porco, toucinho entremeado fresco, cru	Carne e produtos cárneos	porco, toucinho entremeado fresco, cru	682	72	24.1	0	0	0	8.4	0.2
310	Porco, toucinho entremeado fresco, grelhado sem adição de sal	Carne e produtos cárneos	porco, toucinho entremeado fresco, grelhado sem adicao de sal	676	67.9	22.7	0	0	0	16.1	0.4
309	Porco, toucinho entremeado ligeiramente salgado, cozido sem adição de sal	Carne e produtos cárneos	porco, toucinho entremeado ligeiramente salgado, cozido sem adicao de sal	372	33.9	11.4	0	0	0	16.7	2.2
308	Porco, toucinho entremeado ligeiramente salgado, cru	Carne e produtos cárneos	porco, toucinho entremeado ligeiramente salgado, cru	506	50.1	16.8	0	0	0	13.7	3.6
2120000012	Porco, toucinho entremeado magro	Carne e produtos cárneos	porco, toucinho entremeado magro	333	29.1	10	0.5	0	0	17.4	0.5
1900000060	Pota crua	Peixes, mariscos, anfíbios, répteis e invertebrados	pota crua	75	1.1	0.2	0	0	0	16.3	0.5
357	Presunto	Carne e produtos cárneos	presunto	215	12.8	4.1	0	0	0	25	6.4
2122000005	Proteína texturizada de soja	Ingredientes principais isolados, aditivos, aromas, fermentos e auxiliares tecnológicos	proteina texturizada de soja	327	1.4	0.2	17.2	13.1	16.6	53	0
490	Pudim de leite e ovos	Leite e produtos lácteos	pudim de leite e ovos	246	4.7	1.3	44.8	44.8	0	6.1	0.2
491	Pudim flan caseiro	Leite e produtos lácteos	pudim flan caseiro	211	4.5	1.4	36.3	36.3	0	6.2	0.2
492	Pudim instantâneo em pó	Leite e produtos lácteos	pudim instantaneo em po	412	9.4	8.6	79.4	54.6	1	2	1.8
494	Pudim instantâneo preparado com leite magro	Leite e produtos lácteos	pudim instantaneo preparado com leite magro	104	1.9	1.6	18.3	13.9	0.2	3.2	0.4
493	Pudim instantâneo preparado com leite meio gordo	Leite e produtos lácteos	pudim instantaneo preparado com leite meio gordo	113	3	2.3	18.3	13.9	0.2	3.1	0.4
589	Puré de batata	Pratos compostos	pure de batata	126	5.2	2.9	16.8	1.3	1.4	2.3	0.3
523	Queijada de queijo fresco	Cereais e produtos à base de cereais	queijada de queijo fresco	301	4.7	1.8	56.7	35.2	0.9	7.5	0.1
522	Queijada de queijo magro	Cereais e produtos à base de cereais	queijada de queijo magro	292	4.7	1.9	55.4	36.4	0.7	6.7	0.1
524	Queijada de requeijão	Cereais e produtos à base de cereais	queijada de requeijao	311	13.1	6	40.8	31.8	0.4	7.2	0.5
220006	Queijo Amarelo da Beira Baixa	Leite e produtos lácteos	queijo amarelo da beira baixa	361	30	21.1	1.5	1.5	0	20.5	1.5
1900000087	Queijo Brie	Leite e produtos lácteos	queijo brie	321	27.3	17.3	0	0	0	18.8	1.4
48	Queijo Camembert	Leite e produtos lácteos	queijo camembert	254	19.6	10.5	0.2	0.2	0	19.2	1.5
50800016	Queijo Cheddar	Leite e produtos lácteos	queijo cheddar	419	34.9	21.7	0.1	0.1	0	25.4	1.8
1230	Queijo creme para barrar	Leite e produtos lácteos	queijo creme para barrar	263	22	11.8	6.9	6.9	0	9.3	2.5
56	Queijo creme para barrar, alto teor polinsaturados	Leite e produtos lácteos	queijo creme para barrar, alto teor polinsaturados	263	22	4.9	6.9	6.9	0	9.3	2.5
47	Queijo de Azeitão	Leite e produtos lácteos	queijo de azeitao	339	27.5	18.7	2.6	2.6	0	19.5	1.5
220022	Queijo de cabra "Pure chèvre"	Leite e produtos lácteos	queijo de cabra "pure chevre"	286	25	17	2	2	0	13	1
220015	Queijo de cabra atabafado, curado	Leite e produtos lácteos	queijo de cabra atabafado, curado	313	24	18.6	2.7	2.7	0	18.2	2.8
220004	Queijo de cabra atabafado, fresco	Leite e produtos lácteos	queijo de cabra atabafado, fresco	202	15.4	10.6	2.5	2.5	0	13	1
220014	Queijo de cabra curado	Leite e produtos lácteos	queijo de cabra curado	382	30.5	23.4	2.5	2.5	0	21	1.5
220007	Queijo de Castelo Branco	Leite e produtos lácteos	queijo de castelo branco	356	29.2	19.4	1.8	1.8	0	20.8	1.6
49	Queijo de Évora	Leite e produtos lácteos	queijo de evora	405	32.9	22.6	2.1	2.1	0	23.8	1.3
220021	Queijo de mistura (vaca, cabra e ovelha)	Leite e produtos lácteos	queijo de mistura (vaca, cabra e ovelha)	329	26.7	18.3	2.4	2.4	0	19.6	1.5
220009	Queijo de Nisa	Leite e produtos lácteos	queijo de nisa	451	38	19.9	2.6	2.6	0	23.4	1.5
220008	Queijo de ovelha curado	Leite e produtos lácteos	queijo de ovelha curado	401	33	22	2.4	2.4	0	22.8	1.5
220019	Queijo de ovelha, amanteigado	Leite e produtos lácteos	queijo de ovelha, amanteigado	361	30.3	20.8	1.6	1.6	0	19.7	1.5
220016	Queijo de vaca curado	Leite e produtos lácteos	queijo de vaca curado	355	29	19.5	1.2	1.2	0	22.3	1.3
220018	Queijo de vaca curado, magro	Leite e produtos lácteos	queijo de vaca curado, magro	208	10	6.8	2.4	2.4	0	27.1	1.3
220017	Queijo de vaca curado, meio gordo	Leite e produtos lácteos	queijo de vaca curado, meio gordo	280	20.1	13.5	1.7	1.7	0	23	1.5
220020	Queijo de vaca, amanteigado	Leite e produtos lácteos	queijo de vaca, amanteigado	343	28.3	19.4	1.7	1.7	0	20.2	1.5
39	Queijo Emmental	Leite e produtos lácteos	queijo emmental	384	29.7	18.6	0	0	0	28.9	1
50800032	Queijo flamengo	Leite e produtos lácteos	queijo flamengo	349	28.3	18.5	0.8	0.3	0	22.7	1.3
220005	Queijo flamengo light (-50% gordura)	Leite e produtos lácteos	queijo flamengo light (-50% gordura)	228	13.3	9.3	0	0	0	26.8	1.4
58	Queijo fresco açucarado com sabor a fruta	Leite e produtos lácteos	queijo fresco acucarado com sabor a fruta	110	3.6	1.9	11.6	11.6	0	7.3	0.1
2122000010	Queijo fresco de cabra	Leite e produtos lácteos	queijo fresco de cabra	182	13.8	9.4	2.1	2.1	0	12	1
1900000086	Queijo fresco de ovelha	Leite e produtos lácteos	queijo fresco de ovelha	204	15.6	10.7	3.9	3.6	0	11.3	0.8
2122000011	Queijo fresco magro	Leite e produtos lácteos	queijo fresco magro	96	1.8	1.2	6.9	6.9	0	13	0.8
2122000012	Queijo fresco meio gordo	Leite e produtos lácteos	queijo fresco meio gordo	156	11.9	7.6	2.7	2.7	0	9.2	0.7
41	Queijo fundido 40% gordura	Leite e produtos lácteos	queijo fundido 40% gordura	326	25.7	13.8	0.2	0.2	0	22.5	3.5
50800020	Queijo Gouda	Leite e produtos lácteos	queijo gouda	380	30.6	20.3	0	0	0	25.3	2.3
50800022	Queijo Gruyère	Leite e produtos lácteos	queijo gruyere	415	33.3	20.8	1.4	1.4	0	27.2	1.7
50800024	Queijo Mascarpone	Leite e produtos lácteos	queijo mascarpone	458	47	29	0.3	0.3	0	7.6	0.2
220010	Queijo Mestiço de Tolosa	Leite e produtos lácteos	queijo mestico de tolosa	407	33	22	1.8	1.8	0	24.5	2.1
1224	Queijo Mozzarella fresco	Leite e produtos lácteos	queijo mozzarella fresco	256	19.5	11.4	1.3	0.7	0	18.7	0.4
51	Queijo Parmesão	Leite e produtos lácteos	queijo parmesao	406	27.8	14.7	0.1	0.1	0	37.7	1.9
61	Queijo Quark açucarado magro com sabor a fruta	Leite e produtos lácteos	queijo quark acucarado magro com sabor a fruta	78	0.1	0.1	10.8	10.8	0	8.4	0.1
60	Queijo Quark natural magro	Leite e produtos lácteos	queijo quark natural magro	60	0.3	0.2	4	4	0	10.3	0.1
59	Queijo Quark natural meio gordo	Leite e produtos lácteos	queijo quark natural meio gordo	125	8.5	4.6	3.9	3.9	0	8.1	0.1
1900000088	Queijo Raclette	Leite e produtos lácteos	queijo raclette	354	27.8	18	0.4	0	0	25.5	1.7
52	Queijo Roquefort	Leite e produtos lácteos	queijo roquefort	372	31.5	16.6	0.2	0.2	0	22	3.9
40	Queijo São Jorge	Leite e produtos lácteos	queijo sao jorge	409	32.5	21.4	2.5	2.5	0	26.6	1.8
55	Queijo Serpa	Leite e produtos lácteos	queijo serpa	375	30.5	20.5	2.4	2.4	0	22	2
53	Queijo Serra da Estrela	Leite e produtos lácteos	queijo serra da estrela	324	24	15.8	2	2	0	23.8	1.5
54	Queijo Serra da Estrela, velho	Leite e produtos lácteos	queijo serra da estrela, velho	389	31.5	16.6	0.2	0.2	0	25.5	2
495	Queque	Cereais e produtos à base de cereais	queque	443	23.3	11.8	51.7	27.6	1	6.1	0.7
1900000014	Quiabo cru	Produtos hortícolas e derivados	quiabo cru	37	1	0.3	3.1	2.5	2	2.8	0
1071	Quiche de espinafres	Pratos compostos	quiche de espinafres	275	19.1	9.6	12.4	1.2	1.4	12.6	1.1
1066	Quiche de vegetais	Pratos compostos	quiche de vegetais	302	22.2	10.4	12.9	1.8	1.4	11.9	1.6
957	Quiche lorraine	Pratos compostos	quiche lorraine	374	24.5	11.9	23.5	2.5	0.8	14.4	1.4
657	Quivi, "Kiwi"	Frutos e produtos derivados de frutos	quivi, "kiwi"	54	0.5	0.1	9.5	8.3	2.2	0.9	0
1900000108	Quivi, "Kiwi" desidratado	Frutos e produtos derivados de frutos	quivi, "kiwi" desidratado	333	2.8	0.6	60.6	60.6	10.6	6.1	0.1
511	Rabanada	Cereais e produtos à base de cereais	rabanada	294	16.6	3.4	31.3	23.6	0.5	4.7	0.2
614	Rabanete cru	Produtos hortícolas e derivados	rabanete cru	15	0.2	0.1	1.9	1.9	0.9	1	0
1900000015	Rábano cru	Produtos hortícolas e derivados	rabano cru	88	0.7	0.1	10.7	7	7.5	6	0
870	Raia crua	Peixes, mariscos, anfíbios, répteis e invertebrados	raia crua	58	0.2	0	0	0	0	14.1	0.6
1025	Rancho com carne de galinha, porco e vaca	Pratos compostos	rancho com carne de galinha, porco e vaca	84	3.9	1.3	6.5	1.1	1.3	5.1	0.4
1026	Rancho com carne de porco	Pratos compostos	rancho com carne de porco	107	6.2	1.7	6.8	0.8	1.5	4.8	0.4
1900000020	Rebentos de alfalfa crus	Produtos hortícolas e derivados	rebentos de alfalfa crus	29	0.7	0.1	0.3	0.3	3	4	0
1900000019	Rebentos de bambu crus	Produtos hortícolas e derivados	rebentos de bambu crus	14	0.2	0.1	1.2	0.5	1.8	0.9	0
250027	Rebentos de feijão mungo	Produtos hortícolas e derivados	rebentos de feijao mungo	21	0.2	0	2.1	1.9	1.4	2	0.1
1900000022	Rebentos de soja crus	Produtos hortícolas e derivados	rebentos de soja crus	98	3.9	0.5	5.8	3.3	1.7	9.2	0.1
520	Rebuçados	Açúcar e similares, confeitaria e sobremesas doces à base de água	rebucados	381	0	0	95	95	0	0.3	0.1
220003	Requeijão de cabra	Leite e produtos lácteos	requeijao de cabra	197	15.5	10.5	3.4	2.5	0	10.7	0
220012	Requeijão de mistura (ovelha e cabra)	Leite e produtos lácteos	requeijao de mistura (ovelha e cabra)	136	10	7.1	3.7	3.7	0	7.8	1
220011	Requeijão de mistura (vaca, ovelha e cabra)	Leite e produtos lácteos	requeijao de mistura (vaca, ovelha e cabra)	179	11.7	8.1	4.9	2.2	0	13.6	1
220013	Requeijão de ovelha	Leite e produtos lácteos	requeijao de ovelha	246	20.6	13.7	3.8	2.6	0	11	1
42	Requeijão de vaca	Leite e produtos lácteos	requeijao de vaca	149	10.4	6.9	5.8	2.8	0	8	0.5
368	Rissol	Pratos compostos	rissol	280	13.4	3.4	31.8	1.1	1.3	7.3	1.6
952	Rissol de camarão	Pratos compostos	rissol de camarao	211	8.6	1.1	26.6	1.3	1.4	6.1	1
874	Robalo assado com cebola, azeite, banha e manteiga	Pratos compostos	robalo assado com cebola, azeite, banha e manteiga	192	11.8	3.2	0.6	0.2	0.1	20.4	1
872	Robalo cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	robalo cozido	182	10.9	2.2	0	0	0	21	0.6
871	Robalo cru	Peixes, mariscos, anfíbios, répteis e invertebrados	robalo cru	106	3.5	0.8	0	0	0	18.5	0.2
873	Robalo grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	robalo grelhado	209	13	2.6	0	0	0	23	1.4
696	Romã	Frutos e produtos derivados de frutos	roma	60	0.4	0.1	12	12	3.4	0.4	0
1225	Rúcula crua	Produtos hortícolas e derivados	rucula crua	29	0.7	0.1	2.2	2.1	1.6	2.6	0.1
875	Safio cru	Peixes, mariscos, anfíbios, répteis e invertebrados	safio cru	109	4.2	1.2	0	0	0	17.7	0.2
972	Sal	Temperos, molhos e condimentos	sal	0	0	0	0	0	0	0	100
1122	Salada de alface e tomate temperada com azeite e vinagre	Pratos compostos	salada de alface e tomate temperada com azeite e vinagre	30	1.4	0.2	2.6	2.6	1.3	1.1	0.5
1043	Salada de atum	Pratos compostos	salada de atum	104	4.3	0.6	8.4	0.9	1.3	6.9	0.2
1042	Salada de bacalhau com grão	Pratos compostos	salada de bacalhau com grao	115	4.9	0.7	7.6	0.9	2.8	8.7	1.8
260004	Salada de fruta	Pratos compostos	salada de fruta	57	0.1	0	12.5	10.8	1.3	0.6	0
1154	Salada russa	Pratos compostos	salada russa	116	9.3	1.4	5.6	2.4	1.9	1.4	0.1
359	Salame	Carne e produtos cárneos	salame	422	37.6	12.9	1.3	0	0	19.5	5.8
220023	Salicórnia fresca	Produtos hortícolas e derivados	salicornia fresca	14	0.2	0	1.1	1.1	2.5	0.7	3.2
877	Salmão cozido	Peixes, mariscos, anfíbios, répteis e invertebrados	salmao cozido	273	21.1	4	0	0	0	20.7	0.4
876	Salmão cru	Peixes, mariscos, anfíbios, répteis e invertebrados	salmao cru	262	21.9	4.2	0	0	0	16.2	0.1
878	Salmão grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	salmao grelhado	309	23.7	4.5	0	0	0	23.8	2
2120000013	Salmonete cru	Peixes, mariscos, anfíbios, répteis e invertebrados	salmonete cru	136	5.5	0.7	0.1	0	0	21.7	0.2
360	Salpicão	Carne e produtos cárneos	salpicao	412	36.7	12.6	0	0	0	20.5	11
6	Salsa fresca	Produtos hortícolas e derivados	salsa fresca	20	0	0	0.4	0.4	2.9	3.1	0.1
1226	Salsa seca	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	salsa seca	244	7	2.4	14.5	12.4	29.7	15.8	0.5
2122000007	Salsicha de soja	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	salsicha de soja	252	20.9	2.5	0.6	0.6	3.6	13.5	1.6
361	Salsicha fresca crua	Carne e produtos cárneos	salsicha fresca crua	210	16.4	5.4	0	0	0	15.5	1.8
362	Salsicha fresca estufada com couve e azeite	Pratos compostos	salsicha fresca estufada com couve e azeite	140	11.6	3.6	1.1	0.9	1.3	7.2	1
363	Salsicha fresca estufada com legumes e azeite	Pratos compostos	salsicha fresca estufada com legumes e azeite	121	8.9	2.8	3.7	1.2	1.4	5.9	0.8
364	Salsicha tipo Frankfurt	Carne e produtos cárneos	salsicha tipo frankfurt	178	14.7	4.8	2.4	1.2	0.1	9	2.5
366	Salsicha tipo Frankfurt frita (escorrido o óleo)	Pratos compostos	salsicha tipo frankfurt frita (escorrido o oleo)	201	16.5	4.9	2.8	1.4	0.1	10.2	2.6
365	Salsicha tipo Frankfurt grelhada	Pratos compostos	salsicha tipo frankfurt grelhada	211	16.7	5.4	3.2	1.6	0.1	12	3
1900000065	Sapateira crua	Peixes, mariscos, anfíbios, répteis e invertebrados	sapateira crua	104	2.9	0.5	0	0	0	19.5	0.7
880	Sarda cozida	Peixes, mariscos, anfíbios, répteis e invertebrados	sarda cozida	174	10.6	2.8	0	0	0	19.7	0.8
879	Sarda crua	Peixes, mariscos, anfíbios, répteis e invertebrados	sarda crua	181	11.7	3.1	0	0	0	19	0.2
881	Sarda grelhada	Peixes, mariscos, anfíbios, répteis e invertebrados	sarda grelhada	191	11.2	3	0	0	0	22.5	1
1130	Sardinha frita	Peixes, mariscos, anfíbios, répteis e invertebrados	sardinha frita	300	19.4	5.5	8.7	0.2	0.3	22.5	1
882	Sardinha gorda crua	Peixes, mariscos, anfíbios, répteis e invertebrados	sardinha gorda crua	221	16.4	4.7	0	0	0	18.4	0.2
884	Sardinha gorda frita	Peixes, mariscos, anfíbios, répteis e invertebrados	sardinha gorda frita	247	15.6	4.5	3.5	0	0.1	23	0.9
883	Sardinha gorda grelhada	Peixes, mariscos, anfíbios, répteis e invertebrados	sardinha gorda grelhada	211	12.3	4.4	0	0	0	25	1
890	Sardinha meio gorda conserva em água, sem espinha e sem pele	Peixes, mariscos, anfíbios, répteis e invertebrados	sardinha meio gorda conserva em agua, sem espinha e sem pele	174	9.6	2.8	0	0	0	22	0.1
888	Sardinha meio gorda conserva em azeite	Peixes, mariscos, anfíbios, répteis e invertebrados	sardinha meio gorda conserva em azeite	202	12	3	0.8	0	0	22.7	0.5
889	Sardinha meio gorda conserva em azeite (escorrido)	Peixes, mariscos, anfíbios, répteis e invertebrados	sardinha meio gorda conserva em azeite (escorrido)	189	9	1.5	0.8	0	0	26.3	0.4
885	Sardinha meio gorda crua	Peixes, mariscos, anfíbios, répteis e invertebrados	sardinha meio gorda crua	158	9.1	2.5	0	0	0	18.9	0.2
887	Sardinha meio gorda frita	Peixes, mariscos, anfíbios, répteis e invertebrados	sardinha meio gorda frita	174	10.2	2.3	0.5	0	0	20	0.8
886	Sardinha meio gorda grelhada	Peixes, mariscos, anfíbios, répteis e invertebrados	sardinha meio gorda grelhada	168	7.2	2.2	0	0	0	25.9	1
2122000004	Seitan	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	seitan	139	1.7	0.3	5.4	0.3	0.7	25	0.5
1900000036	Sementes de abóbora, cruas, secas, miolo	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	sementes de abobora, cruas, secas, miolo	567	46.4	8.5	10	2.3	10.8	22	0
1900000041	Sementes de cânhamo secas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	sementes de canhamo secas	424	27.9	2.9	2.4	2.2	22.7	29.5	0
1900000040	Sementes de chia	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	sementes de chia	456	34.4	3.6	4.6	2.2	35.1	14.4	0
1900000043	Sementes de coentro	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	sementes de coentro	358	17.8	1	16.2	0	41.9	12.4	0.1
1900000038	Sementes de girassol, cruas, secas, miolo	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	sementes de girassol, cruas, secas, miolo	585	48.5	5.3	8.3	4.3	13.5	22.1	0
1900000034	Sementes de linhaça cruas	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	sementes de linhaca cruas	487	31	2.7	18.1	5.2	18	25	0
1900000035	Sementes de melão	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	sementes de melao	590	47.7	12	9	0.4	10.8	28.5	0.2
1900000042	Sementes de mostarda	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	sementes de mostarda	449	28.8	1.5	15.9	5.2	12.2	25.5	0
1900000039	Sementes de papoila	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	sementes de papoila	565	45.9	5.8	13.7	3	10	19.3	0.1
1900000037	Sementes de sésamo	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	sementes de sesamo	620	55	8.1	6.4	0.4	5.5	22.1	0.1
1900000074	Sêmola de milho	Cereais e produtos à base de cereais	semola de milho	350	1.1	0.1	73.8	1.5	5	8.8	0
396	Shortening para pastelaria	Óleos e gorduras de origem animal e vegetal e seus derivados	shortening para pastelaria	878	97.5	86.9	0	0	0	0	0
397	Shortening para restaurante	Óleos e gorduras de origem animal e vegetal e seus derivados	shortening para restaurante	900	100	16.1	0	0	0	0	0
711	Sidra (vinho de maçã)	Bebidas alcoólicas	sidra (vinho de maca)	48	0	0	2.3	2.3	0	0	0
2122000003	Sobremesa à base de soja	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	sobremesa a base de soja	95	1.8	0.5	15.8	13.6	1	3.5	0.1
540	Soja cozida sem sal	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	soja cozida sem sal	151	7.5	1	5.6	2.4	5.6	12.5	0
541	Soja, farinha com baixo teor de gordura	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	soja, farinha com baixo teor de gordura	314	2.6	0.3	21.8	10.9	13.5	44	0
539	Soja, grão seco, cru	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	soja, grao seco, cru	407	19.3	2.5	18.3	6.6	14.3	32.8	0
891	Solha crua	Peixes, mariscos, anfíbios, répteis e invertebrados	solha crua	90	1.6	0.3	0	0	0	19	0.3
1155	Solha frita	Peixes, mariscos, anfíbios, répteis e invertebrados	solha frita	147	2	0.4	8.9	0.3	0.5	23	1.1
892	Solha grelhada	Peixes, mariscos, anfíbios, répteis e invertebrados	solha grelhada	104	1.8	0.4	0	0	0	21.9	1
512	Sonhos	Cereais e produtos à base de cereais	sonhos	389	26.2	3.7	29.2	10.6	0.7	8.7	0.2
795	Sopa à lavrador	Pratos compostos	sopa a lavrador	51	1.5	0.2	7.6	1	1.1	1.2	0.6
780	Sopa de abóbora	Pratos compostos	sopa de abobora	33	1.5	0.2	4	0.6	0.5	0.6	0.6
781	Sopa de agrião	Pratos compostos	sopa de agriao	37	1.6	0.2	4.2	0.5	0.9	1	0.6
1110	Sopa de agrião com leite	Pratos compostos	sopa de agriao com leite	33	0.5	0.2	5.3	0.5	1	1.3	0.6
1111	Sopa de agrião com requeijão	Pratos compostos	sopa de agriao com requeijao	28	1.6	0.8	2	0.7	0.8	1.1	0.7
1024	Sopa de carne de porco	Pratos compostos	sopa de carne de porco	60	0.9	0.2	7.3	0.9	3.4	4	0.6
784	Sopa de cebola	Pratos compostos	sopa de cebola	40	1.5	0.2	5.4	0.7	0.6	0.8	0.6
1112	Sopa de cenoura	Pratos compostos	sopa de cenoura	29	0.6	0.3	4.4	1.9	1.3	0.9	0.3
785	Sopa de couve-branca	Pratos compostos	sopa de couve-branca	40	1.5	0.2	5.4	1.3	1	0.8	0.6
786	Sopa de couve-lombarda	Pratos compostos	sopa de couve-lombarda	41	1.5	0.2	5.3	1.1	1.1	0.9	0.6
787	Sopa de cozido	Pratos compostos	sopa de cozido	36	1.4	0.5	2.9	0.6	0.7	2.6	0.6
789	Sopa de ervilhas	Pratos compostos	sopa de ervilhas	48	1.5	0.2	6.4	0.9	1.3	1.6	0.6
790	Sopa de espinafres	Pratos compostos	sopa de espinafres	39	1.6	0.2	4.8	0.4	0.8	1	0.6
1113	Sopa de espinafres com ovos	Pratos compostos	sopa de espinafres com ovos	93	6.9	1.1	4.7	0.4	1.2	2.5	0.5
791	Sopa de favas	Pratos compostos	sopa de favas	49	1.5	0.2	6.4	0.8	1.5	1.8	0.6
1105	Sopa de feijão	Pratos compostos	sopa de feijao	51	2.1	0.3	4.1	0.9	2.8	2.5	0.4
1103	Sopa de feijão-branco com couve-portuguesa, sem adição de sal	Pratos compostos	sopa de feijao-branco com couve-portuguesa, sem adicao de sal	47	1.3	0.2	4.9	1.3	2.7	2.5	0
1121	Sopa de feijão-manteiga	Pratos compostos	sopa de feijao-manteiga	46	0.4	0.1	8.7	1.9	1.6	1.2	0.6
1102	Sopa de feijão-manteiga com couve-lombarda	Pratos compostos	sopa de feijao-manteiga com couve-lombarda	43	1.8	0.3	3.5	0.8	2.4	2.1	0.6
1114	Sopa de feijão-verde	Pratos compostos	sopa de feijao-verde	32	1.5	0.6	3.5	0.8	0.7	0.7	0.6
792	Sopa de feijão-verde e cenoura	Pratos compostos	sopa de feijao-verde e cenoura	42	1.5	0.2	5.8	1.1	1	0.9	0.6
1115	Sopa de feijão-verde e nabo	Pratos compostos	sopa de feijao-verde e nabo	36	1.9	0.9	3.4	1.3	1	0.7	0.7
1106	Sopa de grão à moda da avó	Pratos compostos	sopa de grao a moda da avo	107	2.3	0.3	15.1	1.2	3.3	4.7	0.2
793	Sopa de grão com arroz e espinafres	Pratos compostos	sopa de grao com arroz e espinafres	60	2.1	0.3	7	0.6	1.8	2.4	0.6
1108	Sopa de grão com arroz, espinafres e coentros	Pratos compostos	sopa de grao com arroz, espinafres e coentros	45	1.3	0.2	5.3	0.6	1.7	2.1	0.7
1107	Sopa de grão com espinafres	Pratos compostos	sopa de grao com espinafres	55	2.3	0.6	5.1	0.6	1.9	2.6	0.7
796	Sopa de nabiças (ou de grelos de nabo)	Pratos compostos	sopa de nabicas (ou de grelos de nabo)	40	1.2	0.2	5.8	1.2	1.1	1	0.6
1120	Sopa de peixe	Pratos compostos	sopa de peixe	17	0.6	0.2	1.3	0.9	0.4	1.3	0.6
799	Sopa de peixe com massa	Pratos compostos	sopa de peixe com massa	46	1.1	0.2	5.8	0.9	0.7	2.8	0.6
1101	Sopa de tomate	Pratos compostos	sopa de tomate	31	0.8	0.3	4.4	2.3	0.7	1.1	0.6
1109	Sopa de vegetais	Pratos compostos	sopa de vegetais	11	0.2	0	1.2	1.1	0.8	0.8	0.5
794	Sopa juliana	Pratos compostos	sopa juliana	31	0.9	0.1	4.3	0.9	1	0.9	0.6
782	Sopa, caldo verde	Pratos compostos	sopa, caldo verde	43	1.7	0.3	5.3	0.7	0.8	1.3	0.7
783	Sopa, canja de galinha	Pratos compostos	sopa, canja de galinha	40	0.9	0.2	5.8	0.1	0.2	2	0.6
788	Sopa, creme de cenoura	Pratos compostos	sopa, creme de cenoura	34	1.4	0.2	4.4	1	0.8	0.6	0.6
797	Sopa, puré de feijão	Pratos compostos	sopa, pure de feijao	43	1.6	0.2	4.5	0.9	1.9	1.6	0.6
798	Sopa, puré de vegetais	Pratos compostos	sopa, pure de vegetais	42	1.5	0.2	5.5	1	1	1	0.6
776	Sucedâneo de café, 20% de café, pó	Café, cacau, chá e tisanas	sucedaneo de cafe, 20% de cafe, po	359	2.8	0.5	77	0	0	6.5	0.1
775	Sucedâneo de café, pó	Café, cacau, chá e tisanas	sucedaneo de cafe, po	375	3.4	0.6	81	0	0	5	0.2
1900000078	Sultanas	Frutos e produtos derivados de frutos	sultanas	304	0.4	0.2	69.4	69.4	4.2	2.7	0
736	Sumo de ananás, 100%	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	sumo de ananas, 100%	45	0	0	10.3	9.3	0	0.5	0
739	Sumo de ananás, concentrado	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	sumo de ananas, concentrado	265	0	0	64.7	64.7	0	0	0
740	Sumo de laranja, 100%	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	sumo de laranja, 100%	45	0	0	10.3	9.5	0	0.5	0
742	Sumo de laranja, concentrado	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	sumo de laranja, concentrado	272	0.7	0.1	64.9	64.9	0	0.1	0.1
744	Sumo de limão, fresco (espremido)	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	sumo de limao, fresco (espremido)	25	0	0	1.5	1.5	0	0.3	0
745	Sumo de maçã, 100%	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	sumo de maca, 100%	44	0	0	10.3	9.9	0	0.5	0
747	Sumo de pêssego, 100%	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	sumo de pessego, 100%	50	0	0	11.5	11.5	0	0.5	0
617	Sumo de tomate, 100%	Sumos e néctares de frutos e produtos hortícolas (incluindo concentrados)	sumo de tomate, 100%	21	0	0	3.5	3.5	0.6	1.1	0.6
2120000008	Tahini	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	tahini	661	58.9	8.4	11.6	5.8	5.5	18.5	0.1
1900000097	Tâmara fresca	Frutos e produtos derivados de frutos	tamara fresca	147	0.1	0	33.2	33.2	3.8	1.2	0
689	Tâmara seca	Frutos e produtos derivados de frutos	tamara seca	298	0.3	0.1	67.3	67.3	7.8	2.5	0
1900000012	Tamarilho sem pele	Frutos e produtos derivados de frutos	tamarilho sem pele	34	0.3	0.1	4.6	4.6	2.3	2	0
1900000053	Tamarindo cru	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	tamarindo cru	242	0.3	0.1	54.9	38.8	5.1	2.3	0
893	Tamboril cru	Peixes, mariscos, anfíbios, répteis e invertebrados	tamboril cru	73	0.2	0	0	0	0	17.9	0.2
894	Tamboril grelhado	Peixes, mariscos, anfíbios, répteis e invertebrados	tamboril grelhado	88	0.3	0.1	0	0	0	21.4	1
690	Tângera	Frutos e produtos derivados de frutos	tangera	41	0.1	0	7.8	7.8	1.7	0.7	0
691	Tangerina	Frutos e produtos derivados de frutos	tangerina	44	0.1	0	8.7	8.7	1.7	0.7	0
454	Tapioca	Ingredientes principais isolados, aditivos, aromas, fermentos e auxiliares tecnológicos	tapioca	356	0.2	0.1	87.5	0.9	1.7	0.3	0
496	Tarte de maçã	Cereais e produtos à base de cereais	tarte de maca	200	8	3.5	29.3	17.1	2	1.8	0.3
497	Tarte de maçã e pêssego	Cereais e produtos à base de cereais	tarte de maca e pessego	224	6.2	2.4	36.7	21.8	1.9	4.4	0.1
964	Tisana, infusão de ervas	Café, cacau, chá e tisanas	tisana, infusao de ervas	1	0	0	0.2	0.2	0	0	0
546	Tofu frito com azeite	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	tofu frito com azeite	108	7.6	1.1	1.1	0.4	0.4	8.7	0.7
547	Tofu frito com óleo de milho	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	tofu frito com oleo de milho	108	7.6	1	1.1	0.4	0.4	8.7	0.7
545	Tofu simples	Produtos para dietas não padronizadas, substitutos de alimentos e suplementos alimentares	tofu simples	77	4.4	0.6	0.7	0.3	0.3	8.5	0
1900000017	Tomate cherry cru	Produtos hortícolas e derivados	tomate cherry cru	30	0.8	0.1	4	4	1.6	1	0
1900000080	Tomate concentrado	Produtos hortícolas e derivados	tomate concentrado	82	0.3	0	14.3	10	3.9	3.7	0.3
615	Tomate cru	Produtos hortícolas e derivados	tomate cru	21	0.3	0	3.1	3.1	1.5	0.8	0
616	Tomate em conserva ao natural	Produtos hortícolas e derivados	tomate em conserva ao natural	21	0.3	0.1	3.2	3	0.9	1	0.1
230001	Tomate seco	Produtos hortícolas e derivados	tomate seco	296	3.9	0	46	46	17.1	10.5	0.4
1227	Tomilho fresco	Produtos hortícolas e derivados	tomilho fresco	52	1.2	0.6	7.4	7.3	3	1.5	0
1228	Tomilho seco	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	tomilho seco	321	7.4	2.7	45.3	45.3	18.6	9.1	0.1
692	Toranja	Frutos e produtos derivados de frutos	toranja	36	0.1	0	6	6	1.6	0.9	0
498	Torta de chocolate e chantilly	Cereais e produtos à base de cereais	torta de chocolate e chantilly	369	23.9	12.3	29.6	28.3	1.5	8	0.2
60302002	Tosta de trigo	Cereais e produtos à base de cereais	tosta de trigo	377	4.2	0.9	69.7	2.9	5.4	12.5	1
442	Tosta de trigo integral	Cereais e produtos à base de cereais	tosta de trigo integral	373	5.1	1	62.6	3.5	7.4	15.4	1.1
441	Tosta de trigo sem sal	Cereais e produtos à base de cereais	tosta de trigo sem sal	379	3.8	0.9	72.7	2.6	4.5	11.3	0.1
440	Tosta de trigo simples	Cereais e produtos à base de cereais	tosta de trigo simples	379	3.8	0.9	72.7	2.6	4.5	11.3	1.1
1900000048	Tremoço cozido, sem sal	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	tremoco cozido, sem sal	124	2.4	0.3	7.2	0.5	4.8	16	0
548	Tremoço, cozido e salgado	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	tremoco, cozido e salgado	115	2.4	0.3	3.7	0	7.9	15.7	2.3
2122000002	Trigo Sarraceno (grão) cru	Cereais e produtos à base de cereais	trigo sarraceno (grao) cru	337	2.5	0.5	61.3	1.6	9.7	12.4	0
1218	Tripa de porco fresca	Carne e produtos cárneos	tripa de porco fresca	180	16.6	7.6	0	0	0	7.6	0.1
2120000002	Tripa de vaca crua	Carne e produtos cárneos	tripa de vaca crua	160	10.5	4.8	0.1	0	0	16.3	0.1
905	Truta arco-íris crua	Peixes, mariscos, anfíbios, répteis e invertebrados	truta arco-iris crua	92	2.3	0.5	0	0	0	17.8	0.1
906	Truta arco-íris grelhada	Peixes, mariscos, anfíbios, répteis e invertebrados	truta arco-iris grelhada	119	3.7	0.8	0	0	0	21.3	0.9
618	Túbera (trufa) crua	Produtos hortícolas e derivados	tubera (trufa) crua	77	0.3	0.1	14.5	8.7	1.5	3.3	0
693	Uva branca (5 variedades)	Frutos e produtos derivados de frutos	uva branca (5 variedades)	78	0.5	0.1	17.3	17.3	0.8	0.3	0
40200041	Uva de mesa (branca e tinta)	Frutos e produtos derivados de frutos	uva de mesa (branca e tinta)	73	0.5	0.1	15.7	15.3	1	0.6	0
695	Uva seca (passas)	Frutos e produtos derivados de frutos	uva seca (passas)	300	0.8	0.2	68.2	38.6	4.2	3	0.1
694	Uva tinta (5 variedades)	Frutos e produtos derivados de frutos	uva tinta (5 variedades)	83	0.5	0.1	18.6	18.6	0.9	0.3	0
215	Vaca assada com azeite e margarina	Carne e produtos cárneos	vaca assada com azeite e margarina	280	20.4	7.2	0	0	0	24.2	1.2
70202039	Vaca assada com azeite, margarina e óleo alimentar	Carne e produtos cárneos	vaca assada com azeite, margarina e oleo alimentar	280	20.4	2.7	0	0	0	24.2	1.2
214	Vaca assada com margarina	Carne e produtos cárneos	vaca assada com margarina	273	19.6	8.2	0	0	0	24.2	1.3
216	Vaca assada com óleo alimentar e margarina	Carne e produtos cárneos	vaca assada com oleo alimentar e margarina	280	20.4	7.1	0	0	0	24.2	1.2
209	Vaca assada, sem molho	Carne e produtos cárneos	vaca assada, sem molho	192	9.4	4	0	0	0	26.9	0.7
199	Vaca magra cozida	Carne e produtos cárneos	vaca magra cozida	259	13.8	5.4	0	0	0	33.7	0.5
70202033	Vaca magra estufada	Pratos compostos	vaca magra estufada	226	14.2	1.8	1.2	1	0.4	21.8	1.2
221	Vaca magra estufada à jardineira	Pratos compostos	vaca magra estufada a jardineira	111	4.4	1.1	11.4	1.8	1.8	5.5	0.9
206	Vaca magra estufada com azeite e margarina	Pratos compostos	vaca magra estufada com azeite e margarina	226	14.2	4.9	1.2	1	0.4	21.8	1.1
207	Vaca magra estufada com margarina	Pratos compostos	vaca magra estufada com margarina	220	13.6	5.7	1.2	1	0.4	21.8	1.1
205	Vaca magra estufada com óleo alimentar e margarina	Pratos compostos	vaca magra estufada com oleo alimentar e margarina	226	14.2	4.8	1.2	1	0.4	21.8	1.1
200	Vaca magra estufada, sem molho	Carne e produtos cárneos	vaca magra estufada, sem molho	234	12	4.7	0	0	0	31.5	0.7
70202028	Vaca meio gorda estufada	Pratos compostos	vaca meio gorda estufada	278	20.2	2	1.2	1	0.4	21.4	1.1
202	Vaca meio gorda estufada com azeite e margarina	Pratos compostos	vaca meio gorda estufada com azeite e margarina	278	20.2	7.2	1.2	1	0.4	21.4	1
204	Vaca meio gorda estufada com margarina	Pratos compostos	vaca meio gorda estufada com margarina	273	19.6	8	1.2	1	0.4	21.4	1.1
203	Vaca meio gorda estufada com óleo alimentar e margarina	Pratos compostos	vaca meio gorda estufada com oleo alimentar e margarina	278	20.2	7.1	1.2	1	0.4	21.4	1
201	Vaca meio gorda estufada, sem molho	Carne e produtos cárneos	vaca meio gorda estufada, sem molho	280	17	6.5	0	0	0	31.8	0.6
196	Vaca para assar crua	Carne e produtos cárneos	vaca para assar crua	174	10.7	4.1	0	0	0	19.4	0.2
197	Vaca para cozer ou estufar magra crua	Carne e produtos cárneos	vaca para cozer ou estufar magra crua	175	9.8	3.8	0	0	0	21.7	0.2
198	Vaca para cozer ou estufar meio gorda crua	Carne e produtos cárneos	vaca para cozer ou estufar meio gorda crua	227	15.8	6.1	0	0	0	21.3	0.1
1139	Vaca, bife à café	Pratos compostos	vaca, bife a cafe	226	16.5	8.8	1.6	1	0.5	16.9	0.7
1138	Vaca, bife à Marrare com manteiga	Pratos compostos	vaca, bife a marrare com manteiga	368	33.3	18.4	0.9	0.9	0.1	16	1.5
1137	Vaca, bife à Marrare com margarina	Pratos compostos	vaca, bife a marrare com margarina	363	32.8	16.6	0.8	0.8	0.1	16	1.8
1135	Vaca, bife com ovo a cavalo, frito com banha	Pratos compostos	vaca, bife com ovo a cavalo, frito com banha	172	11.2	3.4	0.4	0.3	0.2	17.2	0.6
1136	Vaca, bife com ovo a cavalo, frito com manteiga	Pratos compostos	vaca, bife com ovo a cavalo, frito com manteiga	155	9.2	4	0.5	0.4	0.2	17.4	0.7
217	Vaca, bife cru (valor médio de acém, alcatra e lombo)	Carne e produtos cárneos	vaca, bife cru (valor medio de acem, alcatra e lombo)	122	4.3	1.8	0	0	0	20.9	0.2
219	Vaca, bife frito com manteiga (valor médio de acém, alcatra e lombo)	Carne e produtos cárneos	vaca, bife frito com manteiga (valor medio de acem, alcatra e lombo)	201	11.5	5.8	0.1	0.1	0	24.2	1.3
220	Vaca, bife frito, sem molho (valor médio de acém, alcatra e lombo)	Carne e produtos cárneos	vaca, bife frito, sem molho (valor medio de acem, alcatra e lombo)	183	7.5	3.5	0	0	0	28.8	0.5
218	Vaca, bife grelhado (valor médio de acém, alcatra e lombo)	Carne e produtos cárneos	vaca, bife grelhado (valor medio de acem, alcatra e lombo)	163	6.4	2.7	0	0	0	26.4	0.5
2120000003	Vaca, cachaço cru	Carne e produtos cárneos	vaca, cachaco cru	137	5.6	2.3	0.3	0	0	21.3	0.2
318	Vaca, coração cozido	Carne e produtos cárneos	vaca, coracao cozido	123	3.3	1.4	0	0	0	23.4	0.5
317	Vaca, coração cru	Carne e produtos cárneos	vaca, coracao cru	92	2.7	1.1	0	0	0	17	0.3
319	Vaca, coração estufado com banha e margarina	Pratos compostos	vaca, coracao estufado com banha e margarina	154	7.8	3	0.9	0.7	0.4	17.7	1.3
1134	Vaca, espetada grelhada	Carne e produtos cárneos	vaca, espetada grelhada	213	12.8	4.9	0.8	0.1	0.3	23.5	0.2
324	Vaca, fígado cru	Carne e produtos cárneos	vaca, figado cru	132	4.4	1.7	2.1	0	0	20.9	0.3
325	Vaca, fígado frito sem molho	Carne e produtos cárneos	vaca, figado frito sem molho	171	7	2.9	2.5	0	0	24.5	0.7
293	Vaca, hambúrguer cru	Carne e produtos cárneos	vaca, hamburguer cru	142	6.8	2.7	0	0	0	20.2	0.2
1033	Vaca, hambúrguer frito	Pratos compostos	vaca, hamburguer frito	207	13.8	5.3	1.2	0.9	0.8	19.1	0.9
294	Vaca, hambúrguer grelhado	Pratos compostos	vaca, hamburguer grelhado	183	8.2	3.2	0	0	0	27.3	0.5
330	Vaca, língua crua	Carne e produtos cárneos	vaca, lingua crua	199	15	5.7	0	0	0	15.9	0.2
331	Vaca, língua estufada, sem molho	Pratos compostos	vaca, lingua estufada, sem molho	267	20.9	8	0	0	0	19.8	0.6
211	Vaca, lombo magro assado com azeite e margarina	Carne e produtos cárneos	vaca, lombo magro assado com azeite e margarina	205	11.1	3.9	0	0	0	26.2	1.1
213	Vaca, lombo magro assado com azeite, manteiga e óleo alimentar	Carne e produtos cárneos	vaca, lombo magro assado com azeite, manteiga e oleo alimentar	207	11.4	3.6	0	0	0	26.2	1
210	Vaca, lombo magro assado com margarina	Carne e produtos cárneos	vaca, lombo magro assado com margarina	198	10.4	4.9	0	0	0	26.2	1.2
212	Vaca, lombo magro assado com óleo alimentar e margarina	Carne e produtos cárneos	vaca, lombo magro assado com oleo alimentar e margarina	205	11.1	3.8	0	0	0	26.2	1.1
208	Vaca, lombo magro assado, sem molho	Carne e produtos cárneos	vaca, lombo magro assado, sem molho	172	6.1	2.6	0	0	0	29.2	0.7
195	Vaca, lombo magro cru	Carne e produtos cárneos	vaca, lombo magro cru	114	3.3	1.4	0	0	0	21	0.2
1140	Vaca, lombo magro no forno, com tomate, cebola, cenoura e alho	Carne e produtos cárneos	vaca, lombo magro no forno, com tomate, cebola, cenoura e alho	128	6.8	1.5	2.5	2.2	1.1	11.9	0.9
1141	Vaca, picanha grelhada	Carne e produtos cárneos	vaca, picanha grelhada	194	11.9	4.6	0	0	0	21.7	14
336	Vaca, rim cru	Carne e produtos cárneos	vaca, rim cru	92	2.2	0.9	0	0	0	18	0.7
1900000003	Veado cru	Carne e produtos cárneos	veado cru	112	3.3	1.5	0	0	0	20.6	0.2
1900000098	Vieira, crua	Peixes, mariscos, anfíbios, répteis e invertebrados	vieira, crua	83	1	0.2	0	0	0	18.5	0.4
314	Vinagre	Temperos, molhos e condimentos	vinagre	22	0	0	0.6	0.6	0	0.3	0
250023	Vinho branco de uvas sobreamadurecidas	Bebidas alcoólicas	vinho branco de uvas sobreamadurecidas	110	0	0	10.3	9.6	0	0	0
722	Vinho da Madeira	Bebidas alcoólicas	vinho da madeira	147	0	0	7.5	6.8	0	0	0
723	Vinho do Porto, doce	Bebidas alcoólicas	vinho do porto, doce	167	0	0	14	14	0	0.1	0
724	Vinho do Porto, meio seco	Bebidas alcoólicas	vinho do porto, meio seco	141	0	0	6.5	6.5	0	0.1	0
725	Vinho do Porto, seco	Bebidas alcoólicas	vinho do porto, seco	138	0	0	4	4	0	0.1	0
250017	Vinho espumante, Bruto	Bebidas alcoólicas	vinho espumante, bruto	74	0	0	1.1	0.1	0	0	0
719	Vinho espumante, Doce	Bebidas alcoólicas	vinho espumante, doce	110	0	0	12	12	0	0.1	0
718	Vinho espumante, Extra bruto	Bebidas alcoólicas	vinho espumante, extra bruto	71	0	0	0.7	0.1	0	0	0
250018	Vinho espumante, Extra seco	Bebidas alcoólicas	vinho espumante, extra seco	76	0	0	2.2	1.5	0	0	0
720	Vinho espumante, Meio seco	Bebidas alcoólicas	vinho espumante, meio seco	80	0	0	4.1	3.3	0	0	0
721	Vinho espumante, Seco	Bebidas alcoólicas	vinho espumante, seco	77	0	0	3.1	2.6	0	0	0
250019	Vinho frisante	Bebidas alcoólicas	vinho frisante	68	0	0	2	0.1	0	0	0
250021	Vinho licoroso, teor alcoólico  ≥17 e <20%vol.	Bebidas alcoólicas	vinho licoroso, teor alcoolico  ≥17 e <20%vol.	126	0	0	6.1	5.4	0	0	0
250020	Vinho licoroso, teor alcoólico <17%vol.	Bebidas alcoólicas	vinho licoroso, teor alcoolico <17%vol.	123	0	0	7.8	7.1	0	0	0
250022	Vinho licoroso, teor alcoólico ≥20% vol.	Bebidas alcoólicas	vinho licoroso, teor alcoolico ≥20% vol.	147	0	0	7.5	6.8	0	0	0
712	Vinho maduro branco, teor alcoólico <12,5% vol.	Bebidas alcoólicas	vinho maduro branco, teor alcoolico <12,5% vol.	74	0	0	1.1	0.4	0	0	0
250014	Vinho maduro branco, teor alcoólico ≥12,5% vol.	Bebidas alcoólicas	vinho maduro branco, teor alcoolico ≥12,5% vol.	98	0	0	1.1	0.4	0	0	0
713	Vinho maduro palhete	Bebidas alcoólicas	vinho maduro palhete	65	0	0	0.1	0.1	0	0.1	0
714	Vinho maduro tinto, teor alcoólico <12,5% vol.	Bebidas alcoólicas	vinho maduro tinto, teor alcoolico <12,5% vol.	72	0	0	0.9	0.2	0	0	0
250015	Vinho maduro tinto, teor alcoólico ≥12,5% vol.	Bebidas alcoólicas	vinho maduro tinto, teor alcoolico ≥12,5% vol.	96	0	0	0.9	0.2	0	0	0
250024	Vinho rosé de uvas sobreamadurecidas	Bebidas alcoólicas	vinho rose de uvas sobreamadurecidas	107	0	0	9.3	8.6	0	0	0
715	Vinho rosé, teor alcoólico <12,5% vol.	Bebidas alcoólicas	vinho rose, teor alcoolico <12,5% vol.	71	0	0	1.3	0.6	0	0	0
250016	Vinho rosé, teor alcoólico ≥12,5% vol.	Bebidas alcoólicas	vinho rose, teor alcoolico ≥12,5% vol.	103	0	0	0.9	0.2	0	0	0
716	Vinho verde branco	Bebidas alcoólicas	vinho verde branco	60	0	0	0.1	0.1	0	0	0
717	Vinho verde tinto	Bebidas alcoólicas	vinho verde tinto	59	0	0	0.3	0.3	0	0	0
2120000005	Vitela, bife cru	Carne e produtos cárneos	vitela, bife cru	149	7.6	3.2	0.2	0	0	19.9	0.1
1142	Vitela, bife frito	Carne e produtos cárneos	vitela, bife frito	229	16.4	4.3	0.4	0.3	0.7	19	1.1
2120000004	Vitela, chambão cru	Carne e produtos cárneos	vitela, chambao cru	195	12.6	3.2	0.2	0	0	20.3	0.1
320	Vitela, coração cru	Carne e produtos cárneos	vitela, coracao cru	100	3.6	1.5	0	0	0	16.8	0.3
223	Vitela, costeleta crua	Carne e produtos cárneos	vitela, costeleta crua	121	4.5	1.9	0	0	0	20	0.1
238	Vitela, costeleta frita com margarina	Carne e produtos cárneos	vitela, costeleta frita com margarina	183	9.9	4.6	0	0	0	23.4	1.1
1143	Vitela, costeleta frita panada	Pratos compostos	vitela, costeleta frita panada	148	5.3	2	3.4	0.4	0.5	19.7	0.2
239	Vitela, costeleta frita sem molho	Carne e produtos cárneos	vitela, costeleta frita sem molho	159	6.9	3.1	0	0	0	24.3	0.5
235	Vitela, costeleta grelhada	Carne e produtos cárneos	vitela, costeleta grelhada	131	3.3	1.4	0	0	0	25.2	0.5
326	Vitela, fígado cru	Carne e produtos cárneos	vitela, figado cru	119	3.5	1.4	1.5	0	0	20.3	0.3
328	Vitela, fígado frito com margarina e banha	Carne e produtos cárneos	vitela, figado frito com margarina e banha	201	11.5	4.6	1.7	0	0	22.6	1.3
329	Vitela, fígado frito sem molho	Carne e produtos cárneos	vitela, figado frito sem molho	179	8.3	3.2	1.5	0	0	24.6	0.3
327	Vitela, fígado grelhado	Carne e produtos cárneos	vitela, figado grelhado	153	4.7	1.8	1.9	0	0	25.7	0.4
230	Vitela, lombo assado com azeite e margarina	Carne e produtos cárneos	vitela, lombo assado com azeite e margarina	225	14.4	5.3	0.2	0.1	0	23	1
232	Vitela, lombo assado com azeite, margarina e óleo alimentar	Carne e produtos cárneos	vitela, lombo assado com azeite, margarina e oleo alimentar	225	14.4	5.2	0.2	0.1	0	23	1
231	Vitela, lombo assado com margarina e óleo alimentar	Carne e produtos cárneos	vitela, lombo assado com margarina e oleo alimentar	225	14.4	5.2	0.2	0.1	0	23	1
233	Vitela, lombo assado, sem molho	Carne e produtos cárneos	vitela, lombo assado, sem molho	151	5.6	2.3	0	0	0	25.1	0.4
222	Vitela, lombo cru	Carne e produtos cárneos	vitela, lombo cru	148	7.6	3.2	0	0	0	19.9	0.1
236	Vitela, lombo frito com margarina	Carne e produtos cárneos	vitela, lombo frito com margarina	217	13.7	6.2	0	0	0	23.5	1.1
237	Vitela, lombo frito, sem molho	Carne e produtos cárneos	vitela, lombo frito, sem molho	195	10.6	4.7	0	0	0	24.9	0.5
234	Vitela, lombo grelhado	Carne e produtos cárneos	vitela, lombo grelhado	150	5.6	2.3	0	0	0	25	0.6
2120000006	Vitela, pá crua	Carne e produtos cárneos	vitela, pa crua	138	4.9	2.1	0.3	0	0	23.3	0.1
225	Vitela, peito magro cozido	Carne e produtos cárneos	vitela, peito magro cozido	171	8	3.4	0	0	0	24.8	0.4
224	Vitela, peito magro cru	Carne e produtos cárneos	vitela, peito magro cru	147	7.6	3.2	0	0	0	19.6	0.1
70203037	Vitela, peito magro estufado	Pratos compostos	vitela, peito magro estufado	208	12.6	1.6	0.6	0.4	0.2	22.9	1
228	Vitela, peito magro estufado com azeite e margarina	Pratos compostos	vitela, peito magro estufado com azeite e margarina	208	12.6	4.8	0.6	0.4	0.2	22.9	0.9
229	Vitela, peito magro estufado com azeite, margarina e óleo alimentar	Pratos compostos	vitela, peito magro estufado com azeite, margarina e oleo alimentar	208	12.6	4.7	0.6	0.4	0.2	22.9	0.9
227	Vitela, peito magro estufado com margarina e óleo alimentar	Pratos compostos	vitela, peito magro estufado com margarina e oleo alimentar	208	12.6	4.7	0.6	0.4	0.2	22.9	0.9
226	Vitela, peito magro estufado, sem molho	Carne e produtos cárneos	vitela, peito magro estufado, sem molho	179	8.3	3.5	0	0	0	26	0.5
1900000066	Wasabi, raiz crua	Leguminosas, frutos de casca rija, sementes oleaginosas e especiarias	wasabi, raiz crua	100	0.6	0.2	15.8	15.8	6.1	4.8	0.1`;

    const linhas = DATA.split(NL);
    app.runInTransaction((tx) => {
      const col = tx.findCollectionByNameOrId("ingredientes_referencia");
      for (let i = 0; i < linhas.length; i++) {
        const c = linhas[i].split(TAB);
        if (c.length < 12 || !c[1]) continue;
        const r = new Record(col);
        r.set("codigo", c[0]);
        r.set("nome", c[1]);
        r.set("grupo", c[2]);
        r.set("sinonimos", c[3]);
        r.set("nutri_energia_kcal", Number(c[4]) || 0);
        r.set("nutri_lipidos_g", Number(c[5]) || 0);
        r.set("nutri_saturados_g", Number(c[6]) || 0);
        r.set("nutri_hidratos_g", Number(c[7]) || 0);
        r.set("nutri_acucares_g", Number(c[8]) || 0);
        r.set("nutri_fibra_g", Number(c[9]) || 0);
        r.set("nutri_proteina_g", Number(c[10]) || 0);
        r.set("nutri_sal_g", Number(c[11]) || 0);
        r.set("fonte", FONTE);
        tx.save(r);
      }
    });
  },
  (app) => {
    const rows = app.findRecordsByFilter(
      "ingredientes_referencia", "fonte ~ 'INSA'", "", 0, 0, {},
    );
    for (const r of rows) app.delete(r);
  },
);
