import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/point_vente.dart';

class PointVenteRepository {
  const PointVenteRepository();

  Future<Database> get _db async {
    return DatabaseHelper.obtenirBase();
  }

  /// Récupère tous les points de vente locaux.
  Future<List<PointVente>> obtenirTous() async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.pointVente,
      orderBy: 'ville ASC',
    );

    return resultats
        .map((map) => PointVente.fromMap(map))
        .toList();
  }

  /// Récupère un point de vente par son ID.
  Future<PointVente?> obtenirParId(int id) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.pointVente,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return PointVente.fromMap(resultats.first);
  }

  /// Recherche un point de vente par sa ville.
  Future<PointVente?> obtenirParVille(String ville) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.pointVente,
      where: 'ville = ?',
      whereArgs: [ville],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return PointVente.fromMap(resultats.first);
  }

  /// Recherche un point de vente par son quartier.
  Future<PointVente?> obtenirParQuartier(String quartier) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.pointVente,
      where: 'quartier = ?',
      whereArgs: [quartier],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return PointVente.fromMap(resultats.first);
  }

  /// Enregistre un point de vente.
  Future<void> enregistrer(PointVente pointVente) async {
    final db = await _db;

    await db.insert(
      DatabaseTables.pointVente,
      pointVente.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Enregistre plusieurs points de vente.
  Future<void> enregistrerPlusieurs(
    List<PointVente> pointsDeVente,
  ) async {
    if (pointsDeVente.isEmpty) {
      return;
    }

    final db = await _db;

    final batch = db.batch();

    for (final pointVente in pointsDeVente) {
      batch.insert(
        DatabaseTables.pointVente,
        pointVente.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Met à jour un point de vente.
  Future<int> mettreAJour(
    PointVente pointVente,
  ) async {
    final db = await _db;

    return db.update(
      DatabaseTables.pointVente,
      pointVente.toMap(),
      where: 'id = ?',
      whereArgs: [pointVente.id],
    );
  }

  /// Supprime un point de vente.
  Future<int> supprimer(int id) async {
    final db = await _db;

    return db.delete(
      DatabaseTables.pointVente,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Compte les points de vente locaux.
  Future<int> compter() async {
    final db = await _db;

    final resultats = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseTables.pointVente}
      ''',
    );

    return Sqflite.firstIntValue(resultats) ?? 0;
  }
}