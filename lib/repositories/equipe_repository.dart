import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/equipe.dart';

class EquipeRepository {
  const EquipeRepository();

  Future<Database> get _db async {
    return DatabaseHelper.obtenirBase();
  }

  /// Récupère toutes les équipes locales.
  Future<List<Equipe>> obtenirToutes() async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.equipe,
      orderBy: 'nom ASC',
    );

    return resultats
        .map((map) => Equipe.fromMap(map))
        .toList();
  }

  /// Récupère une équipe par son ID.
  Future<Equipe?> obtenirParId(int id) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.equipe,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Equipe.fromMap(resultats.first);
  }

  /// Récupère une équipe grâce à son identifiant Django.
  Future<Equipe?> obtenirParIdentifiant(
    String identifiant,
  ) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.equipe,
      where: 'identifiant = ?',
      whereArgs: [identifiant],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Equipe.fromMap(resultats.first);
  }

  /// Récupère les équipes d'un point de vente.
  Future<List<Equipe>> obtenirParPointVente(
    int pointDeVenteId,
  ) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.equipe,
      where: 'point_de_vente_id = ?',
      whereArgs: [pointDeVenteId],
      orderBy: 'nom ASC',
    );

    return resultats
        .map((map) => Equipe.fromMap(map))
        .toList();
  }

  /// Enregistre une équipe.
  Future<void> enregistrer(Equipe equipe) async {
    final db = await _db;

    await db.insert(
      DatabaseTables.equipe,
      equipe.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Enregistre plusieurs équipes.
  Future<void> enregistrerPlusieurs(
    List<Equipe> equipes,
  ) async {
    if (equipes.isEmpty) {
      return;
    }

    final db = await _db;

    final batch = db.batch();

    for (final equipe in equipes) {
      batch.insert(
        DatabaseTables.equipe,
        equipe.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Met à jour une équipe.
  Future<int> mettreAJour(Equipe equipe) async {
    final db = await _db;

    return db.update(
      DatabaseTables.equipe,
      equipe.toMap(),
      where: 'id = ?',
      whereArgs: [equipe.id],
    );
  }

  /// Supprime une équipe.
  Future<int> supprimer(int id) async {
    final db = await _db;

    return db.delete(
      DatabaseTables.equipe,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Compte les équipes d'un point de vente.
  Future<int> compterParPointVente(
    int pointDeVenteId,
  ) async {
    final db = await _db;

    final resultats = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseTables.equipe}
      WHERE point_de_vente_id = ?
      ''',
      [pointDeVenteId],
    );

    return Sqflite.firstIntValue(resultats) ?? 0;
  }
}