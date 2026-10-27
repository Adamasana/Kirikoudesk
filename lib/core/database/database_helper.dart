import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
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

    final dossierBase = await getDatabasesPath();

    final cheminBase = join(
      dossierBase,
      nomBase,
    );

    debugPrint(
      'CHEMIN BASE SQLITE : $cheminBase',
    );

    _base = await openDatabase(
      cheminBase,
      version: versionBase,

      onConfigure: (db) async {
        await db.execute(
          'PRAGMA foreign_keys = ON',
        );
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