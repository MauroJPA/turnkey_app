import 'package:flutter/material.dart';

import '../domain/haccp.dart';

/// O ícone de cada tipo de controlo.
IconData iconeDoControlo(TipoControlo t) => switch (t) {
  TipoControlo.temperatura => Icons.thermostat_outlined,
  TipoControlo.limpeza => Icons.cleaning_services_outlined,
  TipoControlo.praga => Icons.pest_control_outlined,
  TipoControlo.manutencao => Icons.fire_extinguisher_outlined,
  TipoControlo.outro => Icons.fact_check_outlined,
};
