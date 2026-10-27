import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/synchronisation.dart';

class SynchronisationRepository {
  const SynchronisationRepository();

  Future<Database> get _db async {
    return DatabaseHelper.obtenirBase();
  }

  /// Récupère toutes les synchronisations.
  Future<List<Synchronisation>> obtenirToutes() async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.synchronisation,
      orderBy: 'id ASC',
    );

    return resultats
        .map((map) => Synchronisation.fromMap(map))
        .toList();
  }

  /// Récupère une synchronisation par son ID SQLite.
  Future<Synchronisation?> obtenirParId(int id) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.synchronisation,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Synchronisation.fromMap(resultats.first);
  }

  /// Récupère la synchronisation d'une commande locale.
  Future<Synchronisation?> obtenirParCommandeLocale(
    int commandeLocaleId,
  ) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.synchronisation,
      where: 'commande_locale_id = ?',
      whereArgs: [commandeLocaleId],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Synchronisation.fromMap(resultats.first);
  }

  /// Récupère une synchronisation grâce à l'identifiant local
  /// stable de la commande.
  Future<Synchronisation?> obtenirParIdLocal(
    String idLocal,
  ) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.synchronisation,
      where: 'id_local = ?',
      whereArgs: [idLocal],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Synchronisation.fromMap(resultats.first);
  }

  /// Récupère les synchronisations en attente.
  Future<List<Synchronisation>> obtenirEnAttente() async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.synchronisation,
      where: 'statut = ?',
      whereArgs: ['pending'],
      orderBy: 'id ASC',
    );

    return resultats
        .map((map) => Synchronisation.fromMap(map))
        .toList();
  }

  /// Récupère les synchronisations ayant échoué.
  Future<List<Synchronisation>> obtenirEnErreur() async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.synchronisation,
      where: 'statut = ?',
      whereArgs: ['error'],
      orderBy: 'id ASC',
    );

    return resultats
        .map((map) => Synchronisation.fromMap(map))
        .toList();
  }

  /// Enregistre une nouvelle synchronisation.
  Future<int> enregistrer(
    Synchronisation synchronisation,
  ) async {
    final db = await _db;

    final donnees = synchronisation.toMap();
    donnees.remove('id');

    return db.insert(
      DatabaseTables.synchronisation,
      donnees,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Met à jour une synchronisation.
  Future<int> mettreAJour(
    Synchronisation synchronisation,
  ) async {
    final db = await _db;

    final donnees = synchronisation.toMap();
    donnees.remove('id');

    return db.update(
      DatabaseTables.synchronisation,
      donnees,
      where: 'id = ?',
      whereArgs: [synchronisation.id],
    );
  }

  /// Crée ou met à jour l'entrée de synchronisation d'une commande.
  Future<void> creerOuMettreAJour({
    required int commandeLocaleId,
    required String idLocal,
    int? commandeDjangoId,
    String statut = 'pending',
    int tentatives = 0,
    DateTime? derniereTentative,
    String? derniereErreur,
    DateTime? dateSynchronisation,
  }) async {
    final db = await _db;

    final donnees = {
      'commande_locale_id': commandeLocaleId,
      'id_local': idLocal,
      'commande_django_id': commandeDjangoId,
      'statut': statut,
      'tentatives': tentatives,
      'derniere_tentative':
          derniereTentative?.toIso8601String(),
      'derniere_erreur': derniereErreur,
      'date_synchronisation':
          dateSynchronisation?.toIso8601String(),
    };

    await db.insert(
      DatabaseTables.synchronisation,
      donnees,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Marque une synchronisation comme étant en cours.
  Future<int> marquerEnCours(int id) async {
    final db = await _db;

    return db.update(
      DatabaseTables.synchronisation,
      {
        'statut': 'syncing',
        'derniere_tentative':
            DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marque une synchronisation comme réussie.
  Future<int> marquerSynchronisee({
    required int id,
    required int commandeDjangoId,
  }) async {
    final db = await _db;

    return db.update(
      DatabaseTables.synchronisation,
      {
        'statut': 'synced',
        'commande_django_id': commandeDjangoId,
        'derniere_erreur': null,
        'date_synchronisation':
            DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marque une synchronisation en erreur.
  Future<int> marquerErreur({
    required int id,
    required String erreur,
  }) async {
    final db = await _db;

    return db.rawUpdate(
      '''
      UPDATE ${DatabaseTables.synchronisation}
      SET
        statut = ?,
        tentatives = tentatives + 1,
        derniere_tentative = ?,
        derniere_erreur = ?
      WHERE id = ?
      ''',
      [
        'error',
        DateTime.now().toIso8601String(),
        erreur,
        id,
      ],
    );
  }

  /// Remet une synchronisation en attente.
  Future<int> remettreEnAttente(int id) async {
    final db = await _db;

    return db.update(
      DatabaseTables.synchronisation,
      {
        'statut': 'pending',
        'derniere_erreur': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Supprime une synchronisation.
  Future<int> supprimer(int id) async {
    final db = await _db;

    return db.delete(
      DatabaseTables.synchronisation,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Compte les synchronisations en attente.
  Future<int> compterEnAttente() async {
    final db = await _db;

    final resultats = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseTables.synchronisation}
      WHERE statut = ?
      ''',
      ['pending'],
    );

    return Sqflite.firstIntValue(resultats) ?? 0;
  }

  /// Compte les synchronisations en erreur.
  Future<int> compterEnErreur() async {
    final db = await _db;

    final resultats = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseTables.synchronisation}
      WHERE statut = ?
      ''',
      ['error'],
    );

    return Sqflite.firstIntValue(resultats) ?? 0;
  }
}