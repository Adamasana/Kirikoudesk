import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/utilisateur.dart';

class UtilisateurRepository {
  const UtilisateurRepository();

  Future<Database> get _db async {
    return DatabaseHelper.obtenirBase();
  }

  // ============================================================
  // OBTENIR TOUS
  // ============================================================

  Future<List<Utilisateur>> obtenirTous() async {
    print('');
    print('============================================================');
    print('UTILISATEUR REPOSITORY : OBTENIR TOUS');
    print('============================================================');

    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.utilisateur,
      orderBy: 'id ASC',
    );

    print('Nombre utilisateurs locaux : ${resultats.length}');

    return resultats
        .map((map) => Utilisateur.fromMap(map))
        .toList();
  }

  // ============================================================
  // OBTENIR PAR ID LOCAL
  // ============================================================

  Future<Utilisateur?> obtenirParIdLocal(int id) async {
    print('');
    print('============================================================');
    print('UTILISATEUR REPOSITORY : RECHERCHE PAR ID LOCAL');
    print('============================================================');

    print('ID local recherché : $id');

    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.utilisateur,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    print('Nombre de résultats : ${resultats.length}');

    if (resultats.isEmpty) {
      print('Aucun utilisateur trouvé avec ID local $id.');
      print('============================================================');
      return null;
    }

    print('Utilisateur trouvé :');
    print(resultats.first);

    print('============================================================');

    return Utilisateur.fromMap(resultats.first);
  }

  // ============================================================
  // OBTENIR PAR USER ID DJANGO
  // ============================================================

  Future<Utilisateur?> obtenirParUserId(int userId) async {
    print('');
    print('============================================================');
    print('UTILISATEUR REPOSITORY : RECHERCHE PAR USER ID DJANGO');
    print('============================================================');

    print('User ID Django recherché : $userId');

    final db = await _db;

    final resultats = await db.query(
      DatabaseTables.utilisateur,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    print('Nombre de résultats : ${resultats.length}');

    if (resultats.isEmpty) {
      print('Aucun utilisateur trouvé.');
      print('============================================================');
      return null;
    }

    print('Utilisateur trouvé :');
    print(resultats.first);

    print('============================================================');

    return Utilisateur.fromMap(resultats.first);
  }

  // ============================================================
  // OBTENIR PAR NUMERO
  // ============================================================

  Future<Utilisateur?> obtenirParNumero(String numero) async {
    print('');
    print('============================================================');
    print('UTILISATEUR REPOSITORY : RECHERCHE PAR NUMERO');
    print('============================================================');

    print('Numero reçu : "$numero"');

    final db = await _db;

    print('OK : BASE SQLITE RÉCUPÉRÉE.');

    final numeroNettoye = numero.trim();

    print('Numero nettoyé : "$numeroNettoye"');

    if (numeroNettoye.isEmpty) {
      print('Numero vide.');
      print('============================================================');
      return null;
    }

    print('');
    print('Exécution de la requête SQLite...');
    print('Table : ${DatabaseTables.utilisateur}');
    print('WHERE : numero = "$numeroNettoye"');

    final resultats = await db.query(
      DatabaseTables.utilisateur,
      where: 'numero = ?',
      whereArgs: [numeroNettoye],
      limit: 1,
    );

    print('');
    print('Requête SQLite terminée.');
    print('Nombre de résultats : ${resultats.length}');

    if (resultats.isEmpty) {
      print('Aucun utilisateur local trouvé.');
      print('============================================================');
      return null;
    }

    print('');
    print('Utilisateur local trouvé :');
    print(resultats.first);

    print('============================================================');

    return Utilisateur.fromMap(resultats.first);
  }

  // ============================================================
  // OBTENIR PAR ID
  // ============================================================

  Future<Utilisateur?> obtenirParId(int userId) async {
    return obtenirParUserId(userId);
  }

  // ============================================================
  // VÉRIFIER LES CLÉS ÉTRANGÈRES
  // ============================================================

  Future<void> _verifierClesEtrangeres({
    required Database db,
    required int userId,
    required int? boutiqueId,
  }) async {
    print('');
    print('============================================================');
    print('VÉRIFICATION DES CLÉS ÉTRANGÈRES');
    print('============================================================');

    print('user_id Django   : $userId');
    print('boutique_id local: $boutiqueId');

    // ----------------------------------------------------------
    // Vérification PRAGMA foreign_key_list
    // ----------------------------------------------------------

    print('');
    print('------------- CONTRAINTES DE LA TABLE UTILISATEUR -------------');

    try {
      final contraintes = await db.rawQuery(
        'PRAGMA foreign_key_list(${DatabaseTables.utilisateur})',
      );

      print('Nombre de contraintes : ${contraintes.length}');

      for (final contrainte in contraintes) {
        print(contrainte);
      }
    } catch (e) {
      print('Impossible de lire les contraintes : $e');
    }

    // ----------------------------------------------------------
    // Vérification des tables existantes
    // ----------------------------------------------------------

    print('');
    print('------------- TABLES SQLITE -------------');

    try {
      final tables = await db.rawQuery(
        '''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
        ORDER BY name
        ''',
      );

      for (final table in tables) {
        print(table['name']);
      }
    } catch (e) {
      print('Erreur récupération tables : $e');
    }

    // ----------------------------------------------------------
    // Vérification user_id
    // ----------------------------------------------------------

    print('');
    print('------------- VÉRIFICATION USER_ID = $userId -------------');

    try {
      final utilisateurs = await db.rawQuery(
        '''
        SELECT *
        FROM utilisateur
        WHERE user_id = ?
        LIMIT 1
        ''',
        [userId],
      );

      print(
        'Résultat recherche user_id = $userId : '
        '${utilisateurs.length}',
      );

      if (utilisateurs.isNotEmpty) {
        print(utilisateurs.first);
      } else {
        print(
          'AUCUNE ligne utilisateur locale avec '
          'user_id = $userId.',
        );
      }
    } catch (e) {
      print('Erreur vérification user_id : $e');
    }

    // ----------------------------------------------------------
    // Vérification boutique_id
    // ----------------------------------------------------------

    print('');
    print(
      '------------- VÉRIFICATION BOUTIQUE_ID = $boutiqueId -------------',
    );

    if (boutiqueId == null) {
      print('boutiqueId est NULL.');
    } else {
      try {
        final equipes = await db.rawQuery(
          '''
          SELECT *
          FROM equipe
          WHERE id = ?
          LIMIT 1
          ''',
          [boutiqueId],
        );

        print(
          'Résultat recherche equipe.id = $boutiqueId : '
          '${equipes.length}',
        );

        if (equipes.isNotEmpty) {
          print(equipes.first);
        } else {
          print(
            'AUCUNE ligne equipe locale avec '
            'id = $boutiqueId.',
          );
        }
      } catch (e) {
        print('Erreur vérification equipe : $e');
      }
    }

    // ----------------------------------------------------------
    // Vérification PRAGMA foreign_keys
    // ----------------------------------------------------------

    print('');
    print('------------- SQLITE FOREIGN KEYS -------------');

    try {
      final foreignKeys = await db.rawQuery(
        'PRAGMA foreign_keys',
      );

      print(foreignKeys);
    } catch (e) {
      print('Erreur PRAGMA foreign_keys : $e');
    }

    print('');
    print('============================================================');
    print('FIN VÉRIFICATION DES CLÉS ÉTRANGÈRES');
    print('============================================================');
  }

  // ============================================================
  // ENREGISTRER COMPTE DJANGO
  // ============================================================

  Future<Utilisateur> enregistrerCompteDjango({
    required int userId,
    required int? boutiqueId,
    required String telephone,
    required String adresse,
    required String statut,
    required String post,
    required String? numero,
  }) async {
    print('');
    print('============================================================');
    print('UTILISATEUR REPOSITORY : DÉBUT ENREGISTREMENT');
    print('============================================================');

    print('userId      : $userId');
    print('boutiqueId  : $boutiqueId');
    print('telephone   : $telephone');
    print('adresse     : $adresse');
    print('statut      : $statut');
    print('post        : $post');
    print('numero      : $numero');

    print('');
    print('------------- RÉCUPÉRATION BASE SQLITE -------------');

    final db = await _db;

    print('OK : BASE SQLITE RÉCUPÉRÉE.');
    print('Database : $db');

    // ----------------------------------------------------------
    // NUMERO
    // ----------------------------------------------------------

    final numeroNettoye = numero?.trim();

    print('');
    print('------------- VALIDATION NUMERO -------------');
    print('Numero original : $numero');
    print('Numero nettoyé  : "$numeroNettoye"');

    if (numeroNettoye == null || numeroNettoye.isEmpty) {
      print('');
      print('ERREUR : NUMERO VIDE.');

      throw const UtilisateurRepositoryException(
        'Le numero de l’utilisateur Django est obligatoire '
        'pour identifier le compte local.',
      );
    }

    print('Numero valide.');

    // ----------------------------------------------------------
    // RECHERCHE EXISTANT
    // ----------------------------------------------------------

    print('');
    print('============================================================');
    print('RECHERCHE UTILISATEUR LOCAL EXISTANT');
    print('============================================================');

    print('Recherche avec numero : "$numeroNettoye"');

    final utilisateurExistant =
        await obtenirParNumero(numeroNettoye);

    print('');
    print('Retour de obtenirParNumero().');
    print('Utilisateur existant : $utilisateurExistant');

    // ----------------------------------------------------------
    // SI EXISTANT : UPDATE
    // ----------------------------------------------------------

    if (utilisateurExistant != null) {
      print('');
      print('============================================================');
      print('UTILISATEUR LOCAL EXISTANT');
      print('============================================================');

      print('ID LOCAL : ${utilisateurExistant.id}');

      final donneesMiseAJour = {
        'user_id': userId,
        'boutique_id': boutiqueId,
        'telephone': telephone,
        'adresse': adresse,
        'statut': statut,
        'post': post,
        'numero': numeroNettoye,
      };

      print('');
      print('------------- DONNÉES UPDATE -------------');
      print(donneesMiseAJour);

      try {
        final nombreModifie = await db.update(
          DatabaseTables.utilisateur,
          donneesMiseAJour,
          where: 'id = ?',
          whereArgs: [utilisateurExistant.id],
        );

        print('');
        print('UPDATE TERMINÉ.');
        print('Nombre de lignes modifiées : $nombreModifie');
      } catch (e, stackTrace) {
        print('');
        print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
        print('ERREUR SQLITE PENDANT UPDATE UTILISATEUR');
        print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

        print('Erreur : $e');

        print('');
        print('StackTrace :');
        print(stackTrace);

        print('');
        print('Données :');
        print(donneesMiseAJour);

        rethrow;
      }

      final utilisateurMisAJour =
          await obtenirParIdLocal(utilisateurExistant.id);

      if (utilisateurMisAJour == null) {
        throw const UtilisateurRepositoryException(
          'Impossible de relire l’utilisateur local après sa mise à jour.',
        );
      }

      print('');
      print('============================================================');
      print('UTILISATEUR REPOSITORY : FIN UPDATE');
      print('============================================================');

      return utilisateurMisAJour;
    }

    // ----------------------------------------------------------
    // NOUVEL UTILISATEUR
    // ----------------------------------------------------------

    print('');
    print('============================================================');
    print('AUCUN UTILISATEUR LOCAL EXISTANT');
    print('============================================================');

    print('Création d’un nouvel utilisateur SQLite.');

    // ----------------------------------------------------------
    // NOUVEAU : DIAGNOSTIC FOREIGN KEY
    // ----------------------------------------------------------

    await _verifierClesEtrangeres(
      db: db,
      userId: userId,
      boutiqueId: boutiqueId,
    );

    // ----------------------------------------------------------
    // DONNÉES INSERT
    // ----------------------------------------------------------

    final donneesInsertion = {
      'user_id': userId,
      'boutique_id': boutiqueId,
      'telephone': telephone,
      'adresse': adresse,
      'statut': statut,
      'post': post,
      'numero': numeroNettoye,
    };

    print('');
    print('------------- DONNÉES INSERT -------------');
    print(donneesInsertion);

    // ----------------------------------------------------------
    // INSERT
    // ----------------------------------------------------------

    print('');
    print('------------- INSERT SQLITE -------------');
    print('Insertion en cours...');

    int idLocal;

    try {
      idLocal = await db.insert(
        DatabaseTables.utilisateur,
        donneesInsertion,
      );

      print('');
      print('INSERT TERMINÉ.');
      print('ID LOCAL CRÉÉ : $idLocal');
    } catch (e, stackTrace) {
      print('');
      print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      print('ERREUR SQLITE PENDANT INSERT UTILISATEUR');
      print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

      print('');
      print('Erreur : $e');

      print('');
      print('StackTrace :');
      print(stackTrace);

      print('');
      print('Données envoyées à SQLite :');
      print(donneesInsertion);

      print('');
      print('Table : ${DatabaseTables.utilisateur}');

      print('');
      print('Colonnes utilisées :');
      print('user_id');
      print('boutique_id');
      print('telephone');
      print('adresse');
      print('statut');
      print('post');
      print('numero');

      print('');
      print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

      rethrow;
    }

    // ----------------------------------------------------------
    // RELECTURE
    // ----------------------------------------------------------

    print('');
    print('------------- RELECTURE APRÈS INSERT -------------');

    final utilisateur =
        await obtenirParIdLocal(idLocal);

    print('');
    print('Utilisateur relu : $utilisateur');

    if (utilisateur == null) {
      print('');
      print('ERREUR : UTILISATEUR INTROUVABLE APRÈS INSERT.');

      throw const UtilisateurRepositoryException(
        'Impossible de récupérer l’utilisateur local après son enregistrement.',
      );
    }

    print('');
    print('============================================================');
    print('UTILISATEUR REPOSITORY : FIN INSERT');
    print('============================================================');

    return utilisateur;
  }

  // ============================================================
  // ENREGISTRER
  // ============================================================

  Future<void> enregistrer(Utilisateur utilisateur) async {
    final db = await _db;

    await db.insert(
      DatabaseTables.utilisateur,
      utilisateur.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ============================================================
  // ENREGISTRER PLUSIEURS
  // ============================================================

  Future<void> enregistrerPlusieurs(
    List<Utilisateur> utilisateurs,
  ) async {
    if (utilisateurs.isEmpty) {
      return;
    }

    final db = await _db;

    final batch = db.batch();

    for (final utilisateur in utilisateurs) {
      batch.insert(
        DatabaseTables.utilisateur,
        utilisateur.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ============================================================
  // METTRE À JOUR
  // ============================================================

  Future<int> mettreAJour(Utilisateur utilisateur) async {
    final db = await _db;

    return db.update(
      DatabaseTables.utilisateur,
      utilisateur.toMap(),
      where: 'id = ?',
      whereArgs: [utilisateur.id],
    );
  }

  // ============================================================
  // SUPPRIMER
  // ============================================================

  Future<int> supprimer(int id) async {
    final db = await _db;

    return db.delete(
      DatabaseTables.utilisateur,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // SUPPRIMER TOUS
  // ============================================================

  Future<int> supprimerTous() async {
    final db = await _db;

    return db.delete(
      DatabaseTables.utilisateur,
    );
  }

  // ============================================================
  // COMPTER PAR BOUTIQUE
  // ============================================================

  Future<int> compterParBoutique(int boutiqueId) async {
    final db = await _db;

    final resultats = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseTables.utilisateur}
      WHERE boutique_id = ?
      ''',
      [boutiqueId],
    );

    return Sqflite.firstIntValue(resultats) ?? 0;
  }
}

// ============================================================
// EXCEPTION
// ============================================================

class UtilisateurRepositoryException implements Exception {
  final String message;

  const UtilisateurRepositoryException(this.message);

  @override
  String toString() {
    return 'UtilisateurRepositoryException: $message';
  }
}