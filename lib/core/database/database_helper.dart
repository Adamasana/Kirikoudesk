
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_migrations.dart';

class DatabaseHelper {
  static const String nomBase = 'kirikoubf.db';

  // Version 3 :
  // - v2 : ajout de encaisse_par
  // - v3 : ajout de date_validation
  static const int versionBase = 3;

  static Database? _base;

  const DatabaseHelper._();

  static Future<Database> obtenirBase() async {
    if (_base != null) {
      return _base!;
    }

    // Ancien emplacement : utilisé par la version précédente.
    final ancienDossier = await getDatabasesPath();
    final ancienChemin = p.join(
      ancienDossier,
      nomBase,
    );

    // Nouvel emplacement accessible en écriture sous Windows.
    final dossierApplication =
        await getApplicationSupportDirectory();

    final dossierBase = Directory(
      p.join(dossierApplication.path, 'KirikouBF'),
    );

    await dossierBase.create(recursive: true);

    final cheminBase = p.join(
      dossierBase.path,
      nomBase,
    );

    // Préserver l'ancienne base si la nouvelle n'existe pas.
    if (p.normalize(ancienChemin) !=
            p.normalize(cheminBase) &&
        !await File(cheminBase).exists() &&
        await File(ancienChemin).exists()) {
      await File(ancienChemin).copy(cheminBase);

      // Préserver également le journal SQLite éventuel.
      final ancienWal = File('$ancienChemin-wal');
      if (await ancienWal.exists()) {
        await ancienWal.copy('$cheminBase-wal');
      }

      debugPrint(
        'Ancienne base SQLite copiée vers : $cheminBase',
      );
    }

    debugPrint('CHEMIN BASE SQLITE : $cheminBase');

    _base = await openDatabase(
      cheminBase,
      version: versionBase,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await DatabaseMigrations.onCreate(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await DatabaseMigrations.onUpgrade(
          db,
          oldVersion,
          newVersion,
        );
      },
    );

    return _base!;
  }

  static Future<void> fermerBase() async {
    if (_base != null) {
      await _base!.close();
      _base = null;
    }
  }
}
