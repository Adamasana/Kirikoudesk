
import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/inventaire/inventaire.dart';
import '../models/inventaire/ligne_inventaire.dart';
import '../models/inventaire/scan_inventaire.dart';

class InventaireRepository {
  const InventaireRepository();

  Future<Database> get _db async {
    return DatabaseHelper.obtenirBase();
  }

  // ============================================================
  // CRÉER UNE SESSION
  // ============================================================

  Future<int> creerInventaire({
    required int pointVenteId,
    int? utilisateurId,
  }) async {
    final db = await _db;

    return db.transaction((txn) async {
      final sessionsExistantes = await txn.query(
        DatabaseTables.inventaire,
        columns: ['id'],
        where: 'point_vente_id = ? AND statut = ?',
        whereArgs: [pointVenteId, 'en_cours'],
        orderBy: 'id DESC',
        limit: 1,
      );

      if (sessionsExistantes.isNotEmpty) {
        throw StateError(
          'Un inventaire est déjà en cours pour ce point de vente.',
        );
      }

      return txn.insert(
        DatabaseTables.inventaire,
        Inventaire(
          pointVenteId: pointVenteId,
          utilisateurId: utilisateurId,
          dateCreation: DateTime.now(),
        ).toMap(),
      );
    });
  }

  // ============================================================
  // RÉCUPÉRER UNE SESSION EN COURS
  // ============================================================

  Future<Inventaire?> obtenirInventaireEnCours({
    required int pointVenteId,
  }) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.inventaire,
      where: 'point_vente_id = ? AND statut = ?',
      whereArgs: [pointVenteId, 'en_cours'],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (resultats.isEmpty) return null;

    return Inventaire.fromMap(resultats.first);
  }

  // ============================================================
  // RÉCUPÉRER UNE SESSION PAR SON ID
  // ============================================================

  Future<Inventaire?> obtenirInventaire(int id) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.inventaire,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (resultats.isEmpty) return null;

    return Inventaire.fromMap(resultats.first);
  }

  // ============================================================
  // AJOUTER UN SCAN
  // ============================================================

  Future<void> ajouterScan({
    required int inventaireId,
    required String code,
  }) async {
    final codeNettoye = code.trim();

    if (codeNettoye.isEmpty) {
      throw ArgumentError('Le code scanné est vide.');
    }

    final db = await _db;

    await db.transaction((txn) async {
      final sessions = await txn.query(
        DatabaseTables.inventaire,
        columns: ['id', 'statut'],
        where: 'id = ?',
        whereArgs: [inventaireId],
        limit: 1,
      );

      if (sessions.isEmpty) {
        throw StateError('Session d’inventaire introuvable.');
      }

      if (sessions.first['statut'] != 'en_cours') {
        throw StateError(
          'Cette session ne peut plus recevoir de scans.',
        );
      }

      await _ajouterScanDansTransaction(
        txn,
        inventaireId: inventaireId,
        code: codeNettoye,
      );
    });
  }

  // ============================================================
  // IMPORTER UN INVENTAIRE COMPLET
  // ============================================================

  Future<int> creerInventaireAvecScans({
    required int pointVenteId,
    int? utilisateurId,
    required List<Map<String, dynamic>> scans,
  }) async {
    final db = await _db;

    if (scans.isEmpty) {
      throw FormatException(
        'Le fichier ne contient aucun scan.',
      );
    }

    return db.transaction((txn) async {
      final sessionsExistantes = await txn.query(
        DatabaseTables.inventaire,
        columns: ['id'],
        where: 'point_vente_id = ? AND statut = ?',
        whereArgs: [pointVenteId, 'en_cours'],
        orderBy: 'id DESC',
      );

      if (sessionsExistantes.isNotEmpty) {
        final ids = sessionsExistantes
            .map((session) => session['id'])
            .join(', ');

        throw StateError(
          'Un inventaire est déjà en cours pour ce point de vente. '
          'Session(s) détectée(s) : $ids.',
        );
      }

      final inventaireId = await txn.insert(
        DatabaseTables.inventaire,
        Inventaire(
          pointVenteId: pointVenteId,
          utilisateurId: utilisateurId,
          dateCreation: DateTime.now(),
        ).toMap(),
      );

      // Chaque quantité est développée en scans individuels.
      for (final element in scans) {
        final code = element['code'];
        final quantite = element['quantite'];

        if (code is! String ||
            code.trim().isEmpty ||
            quantite is! int ||
            quantite <= 0) {
          throw FormatException(
            'Une ligne du fichier JSON est invalide.',
          );
        }

        for (int i = 0; i < quantite; i++) {
          await _ajouterScanDansTransaction(
            txn,
            inventaireId: inventaireId,
            code: code.trim(),
          );
        }
      }

      return inventaireId;
    });
  }

  // ============================================================
  // AJOUTER UN SCAN DANS UNE TRANSACTION EXISTANTE
  // ============================================================

  Future<void> _ajouterScanDansTransaction(
    Transaction txn, {
    required int inventaireId,
    required String code,
  }) async {
    final lignes = await txn.query(
      DatabaseTables.ligneInventaire,
      where: 'inventaire_id = ? AND code = ?',
      whereArgs: [inventaireId, code],
      limit: 1,
    );

    int ligneId;

    if (lignes.isEmpty) {
      ligneId = await txn.insert(
        DatabaseTables.ligneInventaire,
        LigneInventaire(
          inventaireId: inventaireId,
          code: code,
          quantite: 1,
        ).toMap(),
      );
    } else {
      ligneId = lignes.first['id'] as int;

      await txn.rawUpdate(
        '''
        UPDATE ${DatabaseTables.ligneInventaire}
        SET quantite = quantite + 1
        WHERE id = ?
        ''',
        [ligneId],
      );
    }

    await txn.insert(
      DatabaseTables.scanInventaire,
      ScanInventaire(
        ligneInventaireId: ligneId,
        dateScan: DateTime.now(),
      ).toMap(),
    );
  }

  // ============================================================
  // RÉCUPÉRER LES LIGNES REGROUPÉES
  // ============================================================

  Future<List<LigneInventaire>> obtenirLignes(
    int inventaireId,
  ) async {
    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.ligneInventaire,
      where: 'inventaire_id = ?',
      whereArgs: [inventaireId],
      orderBy: 'id DESC',
    );

    return resultats
        .map((map) => LigneInventaire.fromMap(map))
        .toList();
  }

  // ============================================================
  // RÉCUPÉRER TOUS LES SCANS INDIVIDUELS
  // ============================================================

  Future<List<Map<String, dynamic>>> obtenirScans(
    int inventaireId,
  ) async {
    final db = await _db;

    return db.rawQuery(
      '''
      SELECT
        s.id,
        s.ligne_inventaire_id,
        s.date_scan,
        l.code
      FROM ${DatabaseTables.scanInventaire} s
      INNER JOIN ${DatabaseTables.ligneInventaire} l
        ON l.id = s.ligne_inventaire_id
      WHERE l.inventaire_id = ?
      ORDER BY s.id DESC
      ''',
      [inventaireId],
    );
  }

  // ============================================================
  // SUPPRIMER UN SCAN INDIVIDUEL
  // ============================================================

  Future<void> supprimerScan(int scanId) async {
    final db = await _db;

    await db.transaction((txn) async {
      final scans = await txn.query(
        DatabaseTables.scanInventaire,
        where: 'id = ?',
        whereArgs: [scanId],
        limit: 1,
      );

      if (scans.isEmpty) return;

      final ligneId =
          scans.first['ligne_inventaire_id'] as int;

      final sessions = await txn.rawQuery(
        '''
        SELECT i.statut
        FROM ${DatabaseTables.inventaire} i
        INNER JOIN ${DatabaseTables.ligneInventaire} l
          ON l.inventaire_id = i.id
        WHERE l.id = ?
        ''',
        [ligneId],
      );

      if (sessions.isEmpty ||
          sessions.first['statut'] != 'en_cours') {
        throw StateError(
          'Ce scan ne peut plus être supprimé.',
        );
      }

      await txn.delete(
        DatabaseTables.scanInventaire,
        where: 'id = ?',
        whereArgs: [scanId],
      );

      await txn.rawUpdate(
        '''
        UPDATE ${DatabaseTables.ligneInventaire}
        SET quantite = quantite - 1
        WHERE id = ? AND quantite > 0
        ''',
        [ligneId],
      );

      await txn.delete(
        DatabaseTables.ligneInventaire,
        where: 'id = ? AND quantite <= 0',
        whereArgs: [ligneId],
      );
    });
  }

  // ============================================================
  // COMPTER LES SCANS
  // ============================================================

  Future<int> compterScans(int inventaireId) async {
    final db = await _db;

    final resultats = await db.rawQuery(
      '''
      SELECT COUNT(s.id) AS total
      FROM ${DatabaseTables.scanInventaire} s
      INNER JOIN ${DatabaseTables.ligneInventaire} l
        ON l.id = s.ligne_inventaire_id
      WHERE l.inventaire_id = ?
      ''',
      [inventaireId],
    );

    return Sqflite.firstIntValue(resultats) ?? 0;
  }

  // ============================================================
  // ANNULER ET SUPPRIMER UNE SESSION
  // ============================================================

  Future<void> annulerInventaire(int inventaireId) async {
    final db = await _db;

    await db.transaction((txn) async {
      final sessions = await txn.query(
        DatabaseTables.inventaire,
        columns: ['id', 'point_vente_id', 'statut'],
        where: 'id = ?',
        whereArgs: [inventaireId],
        limit: 1,
      );

      if (sessions.isEmpty) {
        return;
      }

      if (sessions.first['statut'] != 'en_cours') {
        throw StateError(
          'Cette session ne peut pas être annulée.',
        );
      }

      final pointVenteId =
          sessions.first['point_vente_id'] as int;

      await txn.delete(
        DatabaseTables.inventaire,
        where: 'point_vente_id = ? AND statut = ?',
        whereArgs: [pointVenteId, 'en_cours'],
      );

      final sessionsRestantes = await txn.query(
        DatabaseTables.inventaire,
        columns: ['id'],
        where: 'point_vente_id = ? AND statut = ?',
        whereArgs: [pointVenteId, 'en_cours'],
      );

      if (sessionsRestantes.isNotEmpty) {
        throw StateError(
          'La suppression de l’inventaire n’a pas abouti.',
        );
      }
    });
  }

  // ============================================================
  // CLÔTURER UN INVENTAIRE VALIDÉ PAR DJANGO
  // ============================================================

  Future<void> cloturerInventaire(int inventaireId) async {
    final db = await _db;

    final nombreModifications = await db.update(
      DatabaseTables.inventaire,
      {'statut': 'valide'},
      where: 'id = ? AND statut = ?',
      whereArgs: [inventaireId, 'en_cours'],
    );

    if (nombreModifications != 1) {
      throw StateError(
        'Impossible de clôturer cet inventaire local.',
      );
    }
  }
}
