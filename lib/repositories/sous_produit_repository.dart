import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/sous_produit.dart';

class SousProduitRepository {
  const SousProduitRepository();

  Future<Database> get _db async {
    return DatabaseHelper.obtenirBase();
  }

  /// Récupère tous les sous-produits locaux.
  Future<List<SousProduit>> obtenirTous() async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.sousProduit,
      orderBy: 'id ASC',
    );

    return resultats
        .map((map) => SousProduit.fromMap(map))
        .toList();
  }

  /// Récupère les variantes d'un produit.
  Future<List<SousProduit>> obtenirParProduit(
    int produitId,
  ) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.sousProduit,
      where: 'produit_id = ?',
      whereArgs: [produitId],
      orderBy: 'id ASC',
    );

    return resultats
        .map((map) => SousProduit.fromMap(map))
        .toList();
  }

  /// Récupère un sous-produit grâce à son ID.
  Future<SousProduit?> obtenirParId(int id) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.sousProduit,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return SousProduit.fromMap(resultats.first);
  }

  /// Récupère un sous-produit grâce à son identifiant unique.
  ///
  /// Cet identifiant est particulièrement important pour la
  /// synchronisation avec Django.
  Future<SousProduit?> obtenirParIdentifiant(
    String identifiant,
  ) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.sousProduit,
      where: 'identifiant = ?',
      whereArgs: [identifiant],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return SousProduit.fromMap(resultats.first);
  }

  /// Récupère un sous-produit grâce à son numéro.
  ///
  /// Le numéro correspond notamment au numéro utilisé par le système
  /// de scan côté Django.
  Future<SousProduit?> obtenirParNumero(
    String numero,
  ) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.sousProduit,
      where: 'numero = ?',
      whereArgs: [numero],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return SousProduit.fromMap(resultats.first);
  }

  /// Récupère uniquement les sous-produits actifs d'un produit.
  Future<List<SousProduit>> obtenirActifsParProduit(
    int produitId,
  ) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.sousProduit,
      where: '''
        produit_id = ?
        AND actif = ?
      ''',
      whereArgs: [
        produitId,
        'Oui',
      ],
      orderBy: 'id ASC',
    );

    return resultats
        .map((map) => SousProduit.fromMap(map))
        .toList();
  }

  /// Enregistre un sous-produit localement.
  Future<void> enregistrer(
    SousProduit sousProduit,
  ) async {
    final db = await _db;

    await db.insert(
      DatabaseTables.sousProduit,
      sousProduit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Enregistre plusieurs sous-produits.
  Future<void> enregistrerPlusieurs(
    List<SousProduit> sousProduits,
  ) async {
    if (sousProduits.isEmpty) {
      return;
    }

    final db = await _db;

    final batch = db.batch();

    for (final sousProduit in sousProduits) {
      batch.insert(
        DatabaseTables.sousProduit,
        sousProduit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Met à jour un sous-produit existant.
  Future<int> mettreAJour(
    SousProduit sousProduit,
  ) async {
    final db = await _db;

    return db.update(
      DatabaseTables.sousProduit,
      sousProduit.toMap(),
      where: 'id = ?',
      whereArgs: [sousProduit.id],
    );
  }

  /// Supprime un sous-produit.
  Future<int> supprimer(int id) async {
    final db = await _db;

    return db.delete(
      DatabaseTables.sousProduit,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Compte les sous-produits d'un produit.
  Future<int> compterParProduit(
    int produitId,
  ) async {
    final db = await _db;

    final resultats = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseTables.sousProduit}
      WHERE produit_id = ?
      ''',
      [produitId],
    );

    return Sqflite.firstIntValue(resultats) ?? 0;
  }
}