
import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/produit.dart';
import '../models/sous_produit.dart';
import '../models/stock.dart';

class SynchronisationIncrementaleRepository {
  const SynchronisationIncrementaleRepository();

  // ============================================================
  // BASE DE DONNEES
  // ============================================================

  Future<Database> get _db async {
    return DatabaseHelper.obtenirBase();
  }

  // ============================================================
  // INITIALISER LES CURSEURS
  // ============================================================

  /// Initialise les curseurs à partir des données déjà présentes
  /// dans SQLite.
  ///
  /// Cette initialisation intervient une seule fois, après
  /// la synchronisation initiale des données de référence.
  ///
  /// Elle évite de télécharger une nouvelle fois tous les
  /// produits et sous-produits déjà présents localement.

  Future<Map<String, int>> initialiserCurseurs() async {
    final db = await _db;

    return db.transaction((txn) async {
      final result = await txn.query(
        DatabaseTables.synchronisationIncrementale,
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (result.isEmpty) {
        throw StateError(
          'La table de synchronisation incrémentale '
          'ne contient pas sa ligne de configuration.',
        );
      }

      final configuration = result.first;

      final dateInitialisation =
          configuration['date_derniere_synchronisation'];

      // --------------------------------------------------------
      // PREMIERE INITIALISATION
      // --------------------------------------------------------

      if (dateInitialisation == null) {
        final produits = await txn.rawQuery('''
          SELECT COALESCE(MAX(id), 0) AS dernier_id
          FROM ${DatabaseTables.produit}
        ''');

        final sousProduits = await txn.rawQuery('''
          SELECT COALESCE(MAX(id), 0) AS dernier_id
          FROM ${DatabaseTables.sousProduit}
        ''');

        final dernierProduitId =
            (produits.first['dernier_id'] as num).toInt();

        final dernierSousProduitId =
            (sousProduits.first['dernier_id'] as num).toInt();

        await txn.update(
          DatabaseTables.synchronisationIncrementale,
          {
            'dernier_produit_id': dernierProduitId,
            'dernier_sous_produit_id': dernierSousProduitId,
            'date_derniere_synchronisation':
                DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [1],
        );

        return {
          'dernier_produit_id': dernierProduitId,
          'dernier_sous_produit_id': dernierSousProduitId,
        };
      }

      // --------------------------------------------------------
      // CURSEURS DEJA INITIALISES
      // --------------------------------------------------------

      return {
        'dernier_produit_id':
            (configuration['dernier_produit_id'] as num).toInt(),
        'dernier_sous_produit_id':
            (configuration['dernier_sous_produit_id'] as num).toInt(),
      };
    });
  }

  // ============================================================
  // OBTENIR LES CURSEURS
  // ============================================================

  Future<Map<String, int>> obtenirCurseurs() async {
    final db = await _db;

    final result = await db.query(
      DatabaseTables.synchronisationIncrementale,
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (result.isEmpty) {
      throw StateError(
        'Impossible de récupérer les curseurs de synchronisation.',
      );
    }

    final configuration = result.first;

    return {
      'dernier_produit_id':
          (configuration['dernier_produit_id'] as num).toInt(),
      'dernier_sous_produit_id':
          (configuration['dernier_sous_produit_id'] as num).toInt(),
    };
  }

  // ============================================================
  // ENREGISTRER LES NOUVEAUX PRODUITS
  // ============================================================

  /// Enregistre les nouveaux produits dans SQLite.
  ///
  /// Le curseur est mis à jour uniquement après l'insertion
  /// des produits, dans la même transaction.

  Future<void> enregistrerNouveauxProduits({
    required List<dynamic> produits,
    required int dernierId,
  }) async {
    final db = await _db;

    await db.transaction((txn) async {
      // --------------------------------------------------------
      // ENREGISTRER LES PRODUITS
      // --------------------------------------------------------

      for (final element in produits) {
        if (element is! Map) {
          throw const FormatException(
            'Format de produit invalide reçu du serveur.',
          );
        }

        final donnees = Map<String, dynamic>.from(element);

        final produit = Produit.fromMap(donnees);

        await txn.insert(
          DatabaseTables.produit,
          produit.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // --------------------------------------------------------
      // METTRE A JOUR LE CURSEUR
      // --------------------------------------------------------

      final configuration = await txn.query(
        DatabaseTables.synchronisationIncrementale,
        columns: ['dernier_produit_id'],
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (configuration.isEmpty) {
        throw StateError(
          'Configuration de synchronisation introuvable.',
        );
      }

      final curseurActuel =
          (configuration.first['dernier_produit_id'] as num).toInt();

      final nouveauCurseur =
          dernierId > curseurActuel ? dernierId : curseurActuel;

      await txn.update(
        DatabaseTables.synchronisationIncrementale,
        {
          'dernier_produit_id': nouveauCurseur,
          'date_derniere_synchronisation':
              DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    });
  }

  // ============================================================
  // ENREGISTRER LES NOUVEAUX SOUS-PRODUITS ET STOCKS
  // ============================================================

  /// Enregistre les nouveaux sous-produits et leurs stocks.
  ///
  /// Les sous-produits sont insérés avant les stocks afin
  /// de respecter les clés étrangères SQLite.
  ///
  /// Le curseur des sous-produits est mis à jour uniquement
  /// après l'enregistrement de toutes les données.

  Future<void> enregistrerNouveauxSousProduits({
    required List<dynamic> sousProduits,
    required List<dynamic> stocks,
    required int dernierId,
  }) async {
    final db = await _db;

    await db.transaction((txn) async {
      // --------------------------------------------------------
      // ENREGISTRER LES SOUS-PRODUITS
      // --------------------------------------------------------

      for (final element in sousProduits) {
        if (element is! Map) {
          throw const FormatException(
            'Format de sous-produit invalide reçu du serveur.',
          );
        }

        final donnees = Map<String, dynamic>.from(element);

        final sousProduit = SousProduit.fromMap(donnees);

        await txn.insert(
          DatabaseTables.sousProduit,
          sousProduit.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // --------------------------------------------------------
      // ENREGISTRER LES STOCKS
      // --------------------------------------------------------

      for (final element in stocks) {
        if (element is! Map) {
          throw const FormatException(
            'Format de stock invalide reçu du serveur.',
          );
        }

        final donnees = Map<String, dynamic>.from(element);

        final stock = Stock.fromMap(donnees);

        await txn.insert(
          DatabaseTables.stock,
          stock.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // --------------------------------------------------------
      // METTRE A JOUR LE CURSEUR
      // --------------------------------------------------------

      final configuration = await txn.query(
        DatabaseTables.synchronisationIncrementale,
        columns: ['dernier_sous_produit_id'],
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (configuration.isEmpty) {
        throw StateError(
          'Configuration de synchronisation introuvable.',
        );
      }

      final curseurActuel =
          (configuration.first['dernier_sous_produit_id'] as num)
              .toInt();

      final nouveauCurseur =
          dernierId > curseurActuel ? dernierId : curseurActuel;

      await txn.update(
        DatabaseTables.synchronisationIncrementale,
        {
          'dernier_sous_produit_id': nouveauCurseur,
          'date_derniere_synchronisation':
              DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    });
  }
}
