import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/produit.dart';

class ProduitRepository {
  const ProduitRepository();

  Future<Database> get _db async {
    return DatabaseHelper.obtenirBase();
  }

  /// Récupère tous les produits locaux.
  Future<List<Produit>> obtenirTous() async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.produit,
      orderBy: 'nom ASC',
    );

    return resultats
        .map((map) => Produit.fromMap(map))
        .toList();
  }

  /// Récupère un produit grâce à son identifiant local/Django.
  Future<Produit?> obtenirParId(int id) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.produit,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Produit.fromMap(resultats.first);
  }

  /// Recherche un produit par son nom.
  Future<List<Produit>> rechercher(String recherche) async {
    final db = await _db;

    final terme = recherche.trim();

    if (terme.isEmpty) {
      return obtenirTous();
    }

    final resultats = await db.query(
      DatabaseTables.produit,
      where: 'nom LIKE ?',
      whereArgs: ['%$terme%'],
      orderBy: 'nom ASC',
    );

    return resultats
        .map((map) => Produit.fromMap(map))
        .toList();
  }

  /// Insère un nouveau produit ou remplace le produit
  /// existant ayant le même identifiant.
  Future<void> enregistrer(Produit produit) async {
    final db = await _db;

    await db.insert(
      DatabaseTables.produit,
      produit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insère plusieurs produits en une seule opération.
  Future<void> enregistrerPlusieurs(
    List<Produit> produits,
  ) async {
    if (produits.isEmpty) {
      return;
    }

    final db = await _db;

    final batch = db.batch();

    for (final produit in produits) {
      batch.insert(
        DatabaseTables.produit,
        produit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Met à jour un produit existant.
  Future<int> mettreAJour(Produit produit) async {
    final db = await _db;

    return db.update(
      DatabaseTables.produit,
      produit.toMap(),
      where: 'id = ?',
      whereArgs: [produit.id],
    );
  }

  /// Supprime un produit local.
  ///
  /// Cette méthode sera utilisée avec prudence car un produit peut
  /// être référencé par des SousProduit et du Stock.
  Future<int> supprimer(int id) async {
    final db = await _db;

    return db.delete(
      DatabaseTables.produit,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Supprime tous les produits locaux.
  ///
  /// À utiliser principalement lors d'une reconstruction complète
  /// des données locales.
  Future<int> supprimerTous() async {
    final db = await _db;

    return db.delete(
      DatabaseTables.produit,
    );
  }

  /// Nombre de produits présents localement.
  Future<int> compter() async {
    final db = await _db;

    final resultats = await db.rawQuery(
      'SELECT COUNT(*) AS total '
      'FROM ${DatabaseTables.produit}',
    );

    return Sqflite.firstIntValue(resultats) ?? 0;
  }
}