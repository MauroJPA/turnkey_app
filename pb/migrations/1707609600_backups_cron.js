/// <reference path="../pb_data/types.d.ts" />

// Backups automáticos do próprio PocketBase: todas as noites às 03:00 cria um
// .zip completo de `pb_data` (base de dados + ficheiros) em `pb_data/backups/`
// e guarda só os 7 mais recentes. A cópia para fora da máquina (Google Drive,
// cifrada) e para o USB é feita pelos scripts de `pb/backup/`.

migrate(
  (app) => {
    const settings = app.settings();
    settings.backups.cron = '0 3 * * *';
    settings.backups.cronMaxKeep = 7;
    app.save(settings);
  },
  (app) => {
    const settings = app.settings();
    settings.backups.cron = '';
    app.save(settings);
  },
);
