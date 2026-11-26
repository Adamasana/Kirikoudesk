
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_migrations.dart';

class DatabaseHelper {
  static const String nomBase = 'kirikoubf.db';
  static const int versionBase = 4;

  static Database? _base;

  const DatabaseHelper._();

  // ============================================================
  // CHEMIN UNIQUE DE LA BASE SQLITE
  // ============================================================

  static Future<String> obtenirCheminBase() async {
    final dossierApplication =
        await getApplicationSupportDirectory();

    final dossierBase = Directory(
      p.join(dossierApplication.path, 'KirikouBF'),
    );

    await dossierBase.create(recursive: true);

    return p.join(dossierBase.path, nomBase);
  }

  // ============================================================
  // OUVERTURE DE LA BASE
  // ============================================================

  static Future<Database> obtenirBase() async {
    if (_base != null && _base!.isOpen) {
      return _base!;
    }

    final cheminBase = await obtenirCheminBase();

    debugPrint('BASE SQLITE ACTIVE : $cheminBase');

    _base = await openDatabase(
      cheminBase,
      version: versionBase,

      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: (db, version) async {
        debugPrint('Création de la nouvelle base SQLite');

        await DatabaseMigrations.onCreate(db);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint(
          'Migration SQLite : $oldVersion vers $newVersion',
        );

        await DatabaseMigrations.onUpgrade(
          db,
          oldVersion,
          newVersion,
        );
      },
    );

    // ========================================================
    // VERIFICATION DE LA TABLE DE SYNCHRONISATION
    // ========================================================

    // Cette méthode est exécutée à chaque ouverture.
    // CREATE TABLE IF NOT EXISTS évite de recréer une table
    // qui existe déjà et préserve ses curseurs.

    await DatabaseMigrations.creerTableSynchronisationIncrementale(
      _base!,
    );

    debugPrint(
      'Table synchronisation_incrementale vérifiée.',
    );

    return _base!;
  }

  // ============================================================
  // FERMETURE DE LA BASE
  // ============================================================

  static Future<void> fermerBase() async {
    if (_base != null && _base!.isOpen) {
      await _base!.close();
    }

    _base = null;
  }
}
