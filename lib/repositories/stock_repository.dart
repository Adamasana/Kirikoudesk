import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/stock.dart';

class StockRepository {
  const StockRepository();

  Future<Database> get _db async {
    return DatabaseHelper.obtenirBase();
  }

  /// Récupère tous les stocks locaux.
  Future<List<Stock>> obtenirTous() async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.stock,
      orderBy: 'id ASC',
    );

    return resultats
        .map((map) => Stock.fromMap(map))
        .toList();
  }

  /// Récupère un stock grâce à son identifiant.
  Future<Stock?> obtenirParId(int id) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.stock,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Stock.fromMap(resultats.first);
  }

  /// Récupère le stock d'un sous-produit dans un point de vente.
  Future<Stock?> obtenirParPointVenteEtSousProduit({
    required int pointDeVenteId,
    required int sousProduitId,
  }) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.stock,
      where: '''
        point_de_vente_id = ?
        AND sous_produit_id = ?
      ''',
      whereArgs: [
        pointDeVenteId,
        sousProduitId,
      ],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Stock.fromMap(resultats.first);
  }

  /// Retourne directement la quantité disponible.
  Future<int> obtenirQuantite({
    required int pointDeVenteId,
    required int sousProduitId,
  }) async {
    final stock = await obtenirParPointVenteEtSousProduit(
      pointDeVenteId: pointDeVenteId,
      sousProduitId: sousProduitId,
    );

    return stock?.quantite ?? 0;
  }

  /// Enregistre un stock.
  Future<void> enregistrer(Stock stock) async {
    final db = await _db;

    await db.insert(
      DatabaseTables.stock,
      stock.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Enregistre plusieurs stocks.
  Future<void> enregistrerPlusieurs(
    List<Stock> stocks,
  ) async {
    if (stocks.isEmpty) {
      return;
    }

    final db = await _db;

    final batch = db.batch();

    for (final stock in stocks) {
      batch.insert(
        DatabaseTables.stock,
        stock.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Met à jour un stock existant.
  Future<int> mettreAJour(Stock stock) async {
    final db = await _db;

    return db.update(
      DatabaseTables.stock,
      stock.toMap(),
      where: 'id = ?',
      whereArgs: [stock.id],
    );
  }

  /// Modifie uniquement la quantité d'un stock.
  Future<int> modifierQuantite({
    required int id,
    required int quantite,
  }) async {
    final db = await _db;

    return db.update(
      DatabaseTables.stock,
      {
        'quantite': quantite,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Met directement le stock à zéro.
  Future<int> mettreAZero({
    required int id,
  }) async {
    return modifierQuantite(
      id: id,
      quantite: 0,
    );
  }

  /// Met à zéro le stock d'un sous-produit
  /// pour un point de vente précis.
  Future<int> mettreAZeroParPointVenteEtSousProduit({
    required int pointDeVenteId,
    required int sousProduitId,
  }) async {
    final db = await _db;

    return db.update(
      DatabaseTables.stock,
      {
        'quantite': 0,
      },
      where: '''
        point_de_vente_id = ?
        AND sous_produit_id = ?
      ''',
      whereArgs: [
        pointDeVenteId,
        sousProduitId,
      ],
    );
  }

  /// Ajoute une quantité au stock existant.
  Future<int> ajouterQuantite({
    required int pointDeVenteId,
    required int sousProduitId,
    required int quantite,
  }) async {
    final db = await _db;

    return db.rawUpdate(
      '''
      UPDATE ${DatabaseTables.stock}
      SET quantite = quantite + ?
      WHERE point_de_vente_id = ?
        AND sous_produit_id = ?
      ''',
      [
        quantite,
        pointDeVenteId,
        sousProduitId,
      ],
    );
  }

  /// Retire une quantité du stock.
  ///
  /// La quantité ne peut pas devenir négative.
  Future<int> retirerQuantite({
    required int pointDeVenteId,
    required int sousProduitId,
    required int quantite,
  }) async {
    if (quantite <= 0) {
      return 0;
    }

    final db = await _db;

    return db.rawUpdate(
      '''
      UPDATE ${DatabaseTables.stock}
      SET quantite = quantite - ?
      WHERE point_de_vente_id = ?
        AND sous_produit_id = ?
        AND quantite >= ?
      ''',
      [
        quantite,
        pointDeVenteId,
        sousProduitId,
        quantite,
      ],
    );
  }

  /// Supprime un stock.
  Future<int> supprimer(int id) async {
    final db = await _db;

    return db.delete(
      DatabaseTables.stock,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Compte les lignes de stock d'un point de vente.
  Future<int> compterParPointVente(
    int pointDeVenteId,
  ) async {
    final db = await _db;

    final resultats = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseTables.stock}
      WHERE point_de_vente_id = ?
      ''',
      [pointDeVenteId],
    );

    return Sqflite.firstIntValue(resultats) ?? 0;
  }
}