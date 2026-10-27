import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/commande.dart';
import '../models/session.dart';

class CommandeRepository {
  const CommandeRepository();

  // ============================================================
  // COMMANDES
  // ============================================================

  Future<List<Commande>> obtenirToutes() async {
    final db = await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.commande,
      orderBy: 'id DESC',
    );

    return resultats.map(Commande.fromMap).toList();
  }

  // ============================================================
  // COMMANDES AFFICHÉES DANS LA CAISSE
  // ============================================================

  Future<List<Commande>> obtenirCommandesPourCaisse() async {
    final db = await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.commande,
      where: '''
        statut_local = ?
        OR (
          statut_local = ?
          AND sync_status = ?
          AND id_django IS NULL
        )
      ''',
      whereArgs: [
        'Caisse',
        'Facture',
        'pending',
      ],
      orderBy: 'id DESC',
    );

    return resultats.map(Commande.fromMap).toList();
  }

  // ============================================================
  // OBTENIR PAR ID LOCAL SQLITE
  // ============================================================

  Future<Commande?> obtenirParId(int id) async {
    final db = await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.commande,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Commande.fromMap(resultats.first);
  }

  // ============================================================
  // OBTENIR PAR ID LOCAL DE SYNCHRONISATION
  // ============================================================

  Future<Commande?> obtenirParIdLocal(
    String idLocal,
  ) async {
    final db = await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.commande,
      where: 'id_local = ?',
      whereArgs: [idLocal],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Commande.fromMap(resultats.first);
  }

  // ============================================================
  // OBTENIR PAR ID DJANGO
  // ============================================================

  Future<Commande?> obtenirParIdDjango(
    int idDjango,
  ) async {
    final db = await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.commande,
      where: 'id_django = ?',
      whereArgs: [idDjango],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return Commande.fromMap(resultats.first);
  }

  // ============================================================
  // OBTENIR PAR STATUT
  // ============================================================

  Future<List<Commande>> obtenirParStatut(
    String statut,
  ) async {
    final db = await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.commande,
      where: 'statut_local = ?',
      whereArgs: [statut],
      orderBy: 'id DESC',
    );

    return resultats.map(Commande.fromMap).toList();
  }

  // ============================================================
  // COMMANDES EN ATTENTE DE SYNCHRONISATION
  // ============================================================

  Future<List<Commande>> obtenirEnAttenteSynchronisation() async {
    final db = await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.commande,
      where:
          'sync_status = ? '
          'AND statut_local = ?',
      whereArgs: [
        'pending',
        'Facture',
      ],
      orderBy: 'id ASC',
    );

    return resultats.map(Commande.fromMap).toList();
  }

  // ============================================================
  // COMMANDES EN ERREUR DE SYNCHRONISATION
  // ============================================================

  Future<List<Commande>> obtenirAvecErreurSynchronisation() async {
    final db = await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.commande,
      where: 'sync_status = ?',
      whereArgs: ['error'],
      orderBy: 'id ASC',
    );

    return resultats.map(Commande.fromMap).toList();
  }

  // ============================================================
  // ENREGISTRER COMMANDE
  // ============================================================

  Future<int> enregistrer(
    Commande commande,
  ) async {
    final db = await DatabaseHelper.obtenirBase();

    final donnees = commande.toMap();

    donnees.remove('id');

    if ((donnees['id_local']?.toString().trim() ?? '').isEmpty) {
      donnees['id_local'] = _genererIdLocal();
    }

    return db.insert(
      DatabaseTables.commande,
      donnees,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // ============================================================
  // METTRE À JOUR COMMANDE
  // ============================================================

  Future<int> mettreAJour(
    Commande commande,
  ) async {
    if (commande.id == null) {
      throw const CommandeRepositoryException(
        'Impossible de mettre à jour une commande sans identifiant local.',
      );
    }

    final db = await DatabaseHelper.obtenirBase();

    final donnees = commande.toMap();

    donnees.remove('id');

    return db.update(
      DatabaseTables.commande,
      donnees,
      where: 'id = ?',
      whereArgs: [commande.id],
    );
  }

  // ============================================================
  // METTRE À JOUR STATUT SIMPLE
  // ============================================================

  Future<int> mettreAJourStatut({
    required int commandeId,
    required String statut,
  }) async {
    final db = await DatabaseHelper.obtenirBase();

    return db.update(
      DatabaseTables.commande,
      {
        'statut_local': statut,
        'date_update': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [commandeId],
    );
  }

  // ============================================================
  // VALIDER LOCALEMENT UNE COMMANDE
  // ============================================================
  //
  // Caisse
  //   ↓
  // Facture locale
  //   ↓
  // sync_status = pending
  //   ↓
  // date_validation = maintenant
  //
  // IMPORTANT :
  //
  // date_validation = moment où le vendeur valide la caisse.
  //
  // sync_date = moment où Django confirme la synchronisation.
  //
  // Les deux dates sont donc différentes.
  //
  // ============================================================

  Future<Commande> validerLocalement(
    int commandeId,
  ) async {
    final db = await DatabaseHelper.obtenirBase();

    try {
      return await db.transaction<Commande>(
        (transaction) async {
          final resultats = await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (resultats.isEmpty) {
            throw const CaisseTransactionException(
              'La commande est introuvable.',
            );
          }

          final commande = Commande.fromMap(
            resultats.first,
          );

          // ------------------------------------------------------
          // FACTURE DÉJÀ SYNCHRONISÉE
          // ------------------------------------------------------

          if (commande.statutLocal == 'Facture' &&
              commande.syncStatus == 'synced') {
            throw const CaisseTransactionException(
              'Cette facture est déjà synchronisée.',
            );
          }

          if (commande.idDjango != null) {
            throw const CaisseTransactionException(
              'Cette commande possède déjà un identifiant Django.',
            );
          }

          // ------------------------------------------------------
          // STATUT AUTORISÉ
          // ------------------------------------------------------

          if (commande.statutLocal != 'Caisse' &&
              commande.statutLocal != 'Facture') {
            throw CaisseTransactionException(
              'Impossible de valider une commande '
              'avec le statut « ${commande.statutLocal} ».',
            );
          }

          // ------------------------------------------------------
          // VÉRIFIER LES SHOPS
          // ------------------------------------------------------

          final shops = await transaction.query(
            DatabaseTables.shop,
            where: 'commande_id = ?',
            whereArgs: [commandeId],
          );

          if (shops.isEmpty) {
            throw const CaisseTransactionException(
              'Impossible de valider une commande sans article.',
            );
          }

          // ------------------------------------------------------
          // DATE DE VALIDATION
          // ------------------------------------------------------

          final maintenant =
              DateTime.now().toIso8601String();

          // ------------------------------------------------------
          // PASSER EN FACTURE LOCALE
          // ------------------------------------------------------

          await transaction.update(
            DatabaseTables.commande,
            {
              'statut_local': 'Facture',
              'sync_status': 'pending',
              'sync_date': null,
              'sync_erreur': null,
              'date_validation': maintenant,
              'date_update': maintenant,
            },
            where: 'id = ?',
            whereArgs: [commandeId],
          );

          // ------------------------------------------------------
          // METTRE LA SYNCHRONISATION EN ATTENTE
          // ------------------------------------------------------

          final synchronisationModifiee =
              await transaction.update(
            DatabaseTables.synchronisation,
            {
              'statut': 'pending',
              'tentatives': 0,
              'commande_django_id': null,
            },
            where: 'commande_locale_id = ?',
            whereArgs: [commandeId],
          );

          // ------------------------------------------------------
          // SI AUCUNE LIGNE DE SYNCHRONISATION N'EXISTE
          // ON LA CRÉE.
          // ------------------------------------------------------

          if (synchronisationModifiee == 0) {
            final commandeActualiseeResult =
                await transaction.query(
              DatabaseTables.commande,
              where: 'id = ?',
              whereArgs: [commandeId],
              limit: 1,
            );

            if (commandeActualiseeResult.isEmpty) {
              throw const CaisseTransactionException(
                'La commande validée ne peut pas être relue.',
              );
            }

            final commandeActualisee =
                Commande.fromMap(
              commandeActualiseeResult.first,
            );

            await transaction.insert(
              DatabaseTables.synchronisation,
              {
                'commande_locale_id': commandeId,
                'id_local': commandeActualisee.idLocal,
                'commande_django_id': null,
                'statut': 'pending',
                'tentatives': 0,
              },
              conflictAlgorithm:
                  ConflictAlgorithm.abort,
            );
          }

          // ------------------------------------------------------
          // RELIRE LA COMMANDE
          // ------------------------------------------------------

          final commandeMiseAJour =
              await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (commandeMiseAJour.isEmpty) {
            throw const CaisseTransactionException(
              'La commande validée ne peut pas être relue localement.',
            );
          }

          return Commande.fromMap(
            commandeMiseAJour.first,
          );
        },
      );
    } on CommandeRepositoryException {
      rethrow;
    } catch (e) {
      throw CaisseTransactionException(
        'Impossible de valider la commande localement.',
        cause: e,
      );
    }
  }

  // ============================================================
  // ANNULER UNE VALIDATION LOCALE
  // ============================================================
  //
  // Facture locale
  //      ↓
  // Caisse
  //
  // Aucun stock n'est restauré ici car le stock n'a pas été
  // retiré au moment de la validation.
  //
  // Le stock a été retiré lors de l'ajout du Shop.
  //
  // ============================================================

  Future<Commande> annulerValidationLocale(
    int commandeId,
  ) async {
    final db = await DatabaseHelper.obtenirBase();

    try {
      return await db.transaction<Commande>(
        (transaction) async {
          final resultats = await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (resultats.isEmpty) {
            throw const CaisseTransactionException(
              'La commande est introuvable.',
            );
          }

          final commande = Commande.fromMap(
            resultats.first,
          );

          if (commande.statutLocal != 'Facture') {
            throw const CaisseTransactionException(
              'Cette commande n’est pas une facture locale.',
            );
          }

          if (commande.syncStatus == 'synced' ||
              commande.idDjango != null) {
            throw const CaisseTransactionException(
              'Cette facture a déjà été synchronisée. '
              'Son annulation doit être effectuée sur le serveur.',
            );
          }

          final maintenant =
              DateTime.now().toIso8601String();

          await transaction.update(
            DatabaseTables.commande,
            {
              'statut_local': 'Caisse',
              'sync_status': 'cancelled',
              'sync_date': null,
              'sync_erreur': null,

              // IMPORTANT :
              // la validation précédente n'est plus valide.
              'date_validation': null,

              'date_update': maintenant,
            },
            where: 'id = ?',
            whereArgs: [commandeId],
          );

          await transaction.update(
            DatabaseTables.synchronisation,
            {
              'statut': 'cancelled',
              'commande_django_id': null,
              'tentatives': 0,
            },
            where: 'commande_locale_id = ?',
            whereArgs: [commandeId],
          );

          final commandeMiseAJour =
              await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (commandeMiseAJour.isEmpty) {
            throw const CaisseTransactionException(
              'La commande ne peut pas être relue après annulation.',
            );
          }

          return Commande.fromMap(
            commandeMiseAJour.first,
          );
        },
      );
    } on CommandeRepositoryException {
      rethrow;
    } catch (e) {
      throw CaisseTransactionException(
        'Impossible d’annuler la validation locale.',
        cause: e,
      );
    }
  }

  // ============================================================
  // MARQUER UNE COMMANDE COMME SYNCHRONISABLE
  // ============================================================

  Future<void> remettreEnAttenteSynchronisation(
    int commandeId,
  ) async {
    final db = await DatabaseHelper.obtenirBase();

    try {
      await db.transaction(
        (transaction) async {
          final resultats = await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (resultats.isEmpty) {
            throw const CaisseTransactionException(
              'La commande est introuvable.',
            );
          }

          final commande =
              Commande.fromMap(resultats.first);

          // ------------------------------------------------------
          // UNE COMMANDE QUI N'A JAMAIS ÉTÉ VALIDÉE NE DEVRAIT
          // PAS ÊTRE REMISE EN ATTENTE DE SYNCHRONISATION.
          // ------------------------------------------------------

          if (commande.dateValidation == null) {
            throw const CaisseTransactionException(
              'La commande ne possède aucune date de validation.',
            );
          }

          await transaction.update(
            DatabaseTables.commande,
            {
              'statut_local': 'Facture',
              'sync_status': 'pending',
              'sync_date': null,
              'sync_erreur': null,
              'date_update':
                  DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [commandeId],
          );

          final synchronisationModifiee =
              await transaction.update(
            DatabaseTables.synchronisation,
            {
              'statut': 'pending',
              'tentatives': 0,
            },
            where: 'commande_locale_id = ?',
            whereArgs: [commandeId],
          );

          if (synchronisationModifiee == 0) {
            await transaction.insert(
              DatabaseTables.synchronisation,
              {
                'commande_locale_id': commandeId,
                'id_local': commande.idLocal,
                'commande_django_id': null,
                'statut': 'pending',
                'tentatives': 0,
              },
              conflictAlgorithm:
                  ConflictAlgorithm.abort,
            );
          }
        },
      );
    } on CommandeRepositoryException {
      rethrow;
    } catch (e) {
      throw CaisseTransactionException(
        'Impossible de remettre la commande en attente.',
        cause: e,
      );
    }
  }

  // ============================================================
  // METTRE À JOUR SYNCHRONISATION
  // ============================================================

  Future<int> mettreAJourSynchronisation({
    required int commandeId,
    required String syncStatus,
    int? idDjango,
    DateTime? syncDate,
    String? syncErreur,
  }) async {
    final db = await DatabaseHelper.obtenirBase();

    final donnees = <String, dynamic>{
      'sync_status': syncStatus,
      'sync_date': syncDate?.toIso8601String(),
      'sync_erreur': syncErreur,
      'date_update':
          DateTime.now().toIso8601String(),
    };

    if (idDjango != null) {
      donnees['id_django'] = idDjango;
    }

    return db.update(
      DatabaseTables.commande,
      donnees,
      where: 'id = ?',
      whereArgs: [commandeId],
    );
  }

  // ============================================================
  // CREER COMMANDE + SHOPS
  // ============================================================

  Future<Commande> enregistrerAvecArticles({
    required Commande commande,
    required List<Map<String, dynamic>> articles,
  }) async {
    if (articles.isEmpty) {
      throw const CaisseTransactionException(
        'Impossible de créer une commande sans article.',
      );
    }

    final session =
        await Session.fromPreferences();

    if (session == null) {
      throw const CaisseTransactionException(
        'Aucune session utilisateur active.',
      );
    }

    final pointDeVenteId =
        session.pointVenteId;

    if (pointDeVenteId == null) {
      throw const CaisseTransactionException(
        'Le point de vente de l’utilisateur connecté est introuvable.',
      );
    }

    final db =
        await DatabaseHelper.obtenirBase();

    try {
      return await db.transaction<Commande>(
        (transaction) async {
          final stocks =
              <Map<String, dynamic>>[];

          // ======================================================
          // VÉRIFIER TOUS LES STOCKS AVANT DE CRÉER LA COMMANDE
          // ======================================================

          for (final article in articles) {
            final articleId =
                _convertirEnInt(
              article['article_id'],
            );

            final quantite =
                _convertirEnInt(
              article['quantite'],
            );

            if (articleId == null) {
              throw const CaisseTransactionException(
                'Le sous-produit de la vente est introuvable.',
              );
            }

            if (quantite == null || quantite < 1) {
              throw const CaisseTransactionException(
                'La quantité de vente est invalide.',
              );
            }

            final stockResult =
                await transaction.query(
              DatabaseTables.stock,
              where:
                  'point_de_vente_id = ? '
                  'AND sous_produit_id = ?',
              whereArgs: [
                pointDeVenteId,
                articleId,
              ],
              limit: 1,
            );

            if (stockResult.isEmpty) {
              final pointDeVente =
                  await _obtenirNomPointDeVente(
                transaction,
                pointDeVenteId,
              );

              final codeSousProduit =
                  await _obtenirCodeSousProduit(
                transaction,
                articleId,
              );

              throw StockIntrouvableException(
                pointDeVente: pointDeVente,
                sousProduit: codeSousProduit,
              );
            }

            stocks.add({
              'articleId': articleId,
              'quantite': quantite,
              'stock': stockResult.first,
            });
          }

          // ======================================================
          // DONNÉES COMMANDE
          // ======================================================

          final donneesCommande =
              commande.toMap();

          donneesCommande.remove('id');

          final idLocalActuel =
              donneesCommande['id_local']
                      ?.toString()
                      .trim() ??
                  '';

          if (idLocalActuel.isEmpty) {
            donneesCommande['id_local'] =
                _genererIdLocal();
          }

          donneesCommande['statut_local'] =
              'Caisse';

          donneesCommande['sync_status'] =
              'pending';

          // Une nouvelle commande de caisse n'est pas encore
          // validée.
          donneesCommande['date_validation'] =
              null;

          donneesCommande['sync_date'] =
              null;

          donneesCommande['sync_erreur'] =
              null;

          // ======================================================
          // CRÉER COMMANDE
          // ======================================================

          final commandeId =
              await transaction.insert(
            DatabaseTables.commande,
            donneesCommande,
            conflictAlgorithm:
                ConflictAlgorithm.abort,
          );

          // ======================================================
          // CRÉER LES SHOPS
          // ======================================================

          for (final article in articles) {
            final articleId =
                _convertirEnInt(
              article['article_id'],
            );

            final quantite =
                _convertirEnInt(
              article['quantite'],
            );

            if (articleId == null ||
                quantite == null) {
              throw const CaisseTransactionException(
                'Les informations du produit sont invalides.',
              );
            }

            final couleur =
                article['couleur']?.toString() ??
                    '';

            final pointure =
                article['pointure']?.toString() ??
                    '';

            final prix =
                _convertirEnInt(
                      article['prix'],
                    ) ??
                    0;

            final montant =
                _convertirEnInt(
                      article['montant'],
                    ) ??
                    prix * quantite;

            final statut =
                article['statut']?.toString() ??
                    'Caisse';

            await transaction.insert(
              DatabaseTables.shop,
              {
                'commande_id': commandeId,
                'article_id': articleId,
                'quantite': quantite,
                'couleur': couleur,
                'pointure': pointure,
                'prix': prix,
                'montant': montant,
                'statut': statut,
              },
              conflictAlgorithm:
                  ConflictAlgorithm.abort,
            );
          }

          // ======================================================
          // DIMINUER LES STOCKS
          // ======================================================

          for (final element in stocks) {
            final stock =
                element['stock']
                    as Map<String, dynamic>;

            final stockId =
                _convertirEnInt(
              stock['id'],
            );

            final stockActuel =
                _convertirEnInt(
                      stock['quantite'],
                    ) ??
                    0;

            final quantite =
                element['quantite'] as int;

            if (stockId == null) {
              throw const CaisseTransactionException(
                'Le stock local possède un identifiant invalide.',
              );
            }

            final nouvelleQuantite =
                max(
              0,
              stockActuel - quantite,
            );

            await transaction.update(
              DatabaseTables.stock,
              {
                'quantite':
                    nouvelleQuantite,
              },
              where: 'id = ?',
              whereArgs: [stockId],
            );
          }

          // ======================================================
          // CRÉER LA LIGNE DE SYNCHRONISATION
          // ======================================================

          final idLocal =
              donneesCommande['id_local']
                      ?.toString() ??
                  '';

          await transaction.insert(
            DatabaseTables.synchronisation,
            {
              'commande_locale_id':
                  commandeId,
              'id_local': idLocal,
              'commande_django_id':
                  commande.idDjango,
              'statut': 'pending',
              'tentatives': 0,
            },
            conflictAlgorithm:
                ConflictAlgorithm.abort,
          );

          // ======================================================
          // RELIRE LA COMMANDE
          // ======================================================

          final commandeResult =
              await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (commandeResult.isEmpty) {
            throw const CaisseTransactionException(
              'La commande a été créée mais ne peut pas être relue localement.',
            );
          }

          return Commande.fromMap(
            commandeResult.first,
          );
        },
      );
    } on CommandeRepositoryException {
      rethrow;
    } catch (e) {
      throw CaisseTransactionException(
        'Impossible d’enregistrer la commande localement. '
        'Erreur SQLite : $e',
        cause: e,
      );
    }
  }

  // ============================================================
  // SHOPS D'UNE COMMANDE
  // ============================================================

  Future<List<Map<String, dynamic>>> obtenirShopsParCommande(
    int commandeId,
  ) async {
    final db =
        await DatabaseHelper.obtenirBase();

    return db.query(
      DatabaseTables.shop,
      where: 'commande_id = ?',
      whereArgs: [commandeId],
      orderBy: 'id ASC',
    );
  }

  // ============================================================
  // AJOUTER UN SHOP
  // ============================================================

  Future<int> ajouterShop({
    required int commandeId,
    required int articleId,
    required int quantite,
    required String couleur,
    required String pointure,
    required int prix,
    required String statut,
  }) async {
    if (quantite < 1) {
      throw const CaisseTransactionException(
        'La quantité doit être supérieure à 0.',
      );
    }

    final session =
        await Session.fromPreferences();

    if (session == null) {
      throw const CaisseTransactionException(
        'Aucune session utilisateur active.',
      );
    }

    final pointDeVenteId =
        session.pointVenteId;

    if (pointDeVenteId == null) {
      throw const CaisseTransactionException(
        'Le point de vente de l’utilisateur connecté est introuvable.',
      );
    }

    final db =
        await DatabaseHelper.obtenirBase();

    try {
      return await db.transaction<int>(
        (transaction) async {
          // ======================================================
          // VÉRIFIER LA COMMANDE
          // ======================================================

          final commandeResult =
              await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (commandeResult.isEmpty) {
            throw const CaisseTransactionException(
              'La commande est introuvable.',
            );
          }

          final commande =
              Commande.fromMap(
            commandeResult.first,
          );

          // Une facture déjà synchronisée ne doit plus être
          // modifiée localement.
          if (commande.syncStatus == 'synced' ||
              commande.idDjango != null) {
            throw const CaisseTransactionException(
              'Cette commande a déjà été synchronisée et ne peut plus être modifiée localement.',
            );
          }

          // ======================================================
          // VÉRIFIER LE STOCK
          // ======================================================

          final stockResult =
              await transaction.query(
            DatabaseTables.stock,
            where:
                'point_de_vente_id = ? '
                'AND sous_produit_id = ?',
            whereArgs: [
              pointDeVenteId,
              articleId,
            ],
            limit: 1,
          );

          if (stockResult.isEmpty) {
            final pointDeVente =
                await _obtenirNomPointDeVente(
              transaction,
              pointDeVenteId,
            );

            final codeSousProduit =
                await _obtenirCodeSousProduit(
              transaction,
              articleId,
            );

            throw StockIntrouvableException(
              pointDeVente: pointDeVente,
              sousProduit: codeSousProduit,
            );
          }

          final stock =
              stockResult.first;

          final stockId =
              _convertirEnInt(
            stock['id'],
          );

          final stockActuel =
              _convertirEnInt(
                    stock['quantite'],
                  ) ??
                  0;

          if (stockId == null) {
            throw const CaisseTransactionException(
              'Le stock local possède un identifiant invalide.',
            );
          }

          // ======================================================
          // RECHERCHER SHOP EXISTANT
          // ======================================================

          final shopResult =
              await transaction.query(
            DatabaseTables.shop,
            where:
                'commande_id = ? '
                'AND article_id = ?',
            whereArgs: [
              commandeId,
              articleId,
            ],
            limit: 1,
          );

          // ======================================================
          // SHOP EXISTANT
          // ======================================================

          if (shopResult.isNotEmpty) {
            final shop =
                shopResult.first;

            final shopId =
                _convertirEnInt(
              shop['id'],
            );

            final ancienneQuantite =
                _convertirEnInt(
                      shop['quantite'],
                    ) ??
                    0;

            final ancienPrix =
                _convertirEnInt(
                      shop['prix'],
                    ) ??
                    prix;

            if (shopId == null) {
              throw const CaisseTransactionException(
                'Le Shop existant possède un identifiant invalide.',
              );
            }

            final nouvelleQuantite =
                ancienneQuantite +
                    quantite;

            final nouveauMontant =
                ancienPrix *
                    nouvelleQuantite;

            await transaction.update(
              DatabaseTables.shop,
              {
                'quantite':
                    nouvelleQuantite,
                'prix': ancienPrix,
                'montant':
                    nouveauMontant,
                'couleur':
                    couleur,
                'pointure':
                    pointure,
                'statut':
                    statut,
              },
              where: 'id = ?',
              whereArgs: [shopId],
            );

            final nouvelleQuantiteStock =
                max(
              0,
              stockActuel - quantite,
            );

            await transaction.update(
              DatabaseTables.stock,
              {
                'quantite':
                    nouvelleQuantiteStock,
              },
              where: 'id = ?',
              whereArgs: [stockId],
            );

            await _recalculerTotauxTransaction(
              transaction,
              commandeId,
            );

            return shopId;
          }

          // ======================================================
          // NOUVEAU SHOP
          // ======================================================

          final montant =
              prix * quantite;

          final shopId =
              await transaction.insert(
            DatabaseTables.shop,
            {
              'commande_id':
                  commandeId,
              'article_id':
                  articleId,
              'quantite':
                  quantite,
              'couleur':
                  couleur,
              'pointure':
                  pointure,
              'prix':
                  prix,
              'montant':
                  montant,
              'statut':
                  statut,
            },
            conflictAlgorithm:
                ConflictAlgorithm.abort,
          );

          // ======================================================
          // DIMINUER LE STOCK
          // ======================================================

          final nouvelleQuantiteStock =
              max(
            0,
            stockActuel - quantite,
          );

          await transaction.update(
            DatabaseTables.stock,
            {
              'quantite':
                  nouvelleQuantiteStock,
            },
            where: 'id = ?',
            whereArgs: [stockId],
          );

          // ======================================================
          // RECALCULER TOTAUX
          // ======================================================

          await _recalculerTotauxTransaction(
            transaction,
            commandeId,
          );

          return shopId;
        },
      );
    } on CommandeRepositoryException {
      rethrow;
    } catch (e) {
      throw CaisseTransactionException(
        'Impossible d’ajouter le produit à la commande.',
        cause: e,
      );
    }
  }

  // ============================================================
  // SUPPRIMER SHOP + RESTAURER STOCK
  // ============================================================

  Future<void> supprimerShopEtRestaurerStock({
    required int shopId,
  }) async {
    final session =
        await Session.fromPreferences();

    if (session == null) {
      throw const CaisseTransactionException(
        'Aucune session utilisateur active.',
      );
    }

    final pointDeVenteId =
        session.pointVenteId;

    if (pointDeVenteId == null) {
      throw const CaisseTransactionException(
        'Le point de vente de l’utilisateur connecté est introuvable.',
      );
    }

    final db =
        await DatabaseHelper.obtenirBase();

    try {
      await db.transaction(
        (transaction) async {
          final shopResult =
              await transaction.query(
            DatabaseTables.shop,
            where: 'id = ?',
            whereArgs: [shopId],
            limit: 1,
          );

          if (shopResult.isEmpty) {
            throw const CaisseTransactionException(
              'Le produit de la commande est introuvable.',
            );
          }

          final shop =
              shopResult.first;

          final commandeId =
              _convertirEnInt(
            shop['commande_id'],
          );

          final articleId =
              _convertirEnInt(
            shop['article_id'],
          );

          final quantite =
              _convertirEnInt(
                    shop['quantite'],
                  ) ??
                  0;

          if (commandeId == null) {
            throw const CaisseTransactionException(
              'La commande associée au produit est introuvable.',
            );
          }

          if (articleId == null) {
            throw const CaisseTransactionException(
              'Le sous-produit associé à cette ligne est introuvable.',
            );
          }

          final commandeResult =
              await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (commandeResult.isEmpty) {
            throw const CaisseTransactionException(
              'La commande associée au Shop est introuvable.',
            );
          }

          final commande =
              Commande.fromMap(
            commandeResult.first,
          );

          if (commande.syncStatus == 'synced' ||
              commande.idDjango != null) {
            throw const CaisseTransactionException(
              'Cette commande a déjà été synchronisée et ne peut plus être modifiée localement.',
            );
          }

          final stockResult =
              await transaction.query(
            DatabaseTables.stock,
            where:
                'point_de_vente_id = ? '
                'AND sous_produit_id = ?',
            whereArgs: [
              pointDeVenteId,
              articleId,
            ],
            limit: 1,
          );

          if (stockResult.isEmpty) {
            final pointDeVente =
                await _obtenirNomPointDeVente(
              transaction,
              pointDeVenteId,
            );

            final codeSousProduit =
                await _obtenirCodeSousProduit(
              transaction,
              articleId,
            );

            throw StockIntrouvableException(
              pointDeVente: pointDeVente,
              sousProduit: codeSousProduit,
            );
          }

          final stock =
              stockResult.first;

          final stockId =
              _convertirEnInt(
            stock['id'],
          );

          final stockActuel =
              _convertirEnInt(
                    stock['quantite'],
                  ) ??
                  0;

          if (stockId == null) {
            throw const CaisseTransactionException(
              'Le stock local possède un identifiant invalide.',
            );
          }

          await transaction.update(
            DatabaseTables.stock,
            {
              'quantite':
                  stockActuel + quantite,
            },
            where: 'id = ?',
            whereArgs: [stockId],
          );

          await transaction.delete(
            DatabaseTables.shop,
            where: 'id = ?',
            whereArgs: [shopId],
          );

          await _recalculerTotauxTransaction(
            transaction,
            commandeId,
          );
        },
      );
    } on CommandeRepositoryException {
      rethrow;
    } catch (e) {
      throw CaisseTransactionException(
        'Impossible de supprimer le produit de la commande.',
        cause: e,
      );
    }
  }

  // ============================================================
  // SUPPRIMER COMMANDE + RESTAURER STOCK
  // ============================================================

  Future<void> supprimerAvecRestaurationStock(
    int commandeId,
  ) async {
    final session =
        await Session.fromPreferences();

    if (session == null) {
      throw const CaisseTransactionException(
        'Aucune session utilisateur active.',
      );
    }

    final pointDeVenteId =
        session.pointVenteId;

    if (pointDeVenteId == null) {
      throw const CaisseTransactionException(
        'Le point de vente de l’utilisateur connecté est introuvable.',
      );
    }

    final db =
        await DatabaseHelper.obtenirBase();

    try {
      await db.transaction(
        (transaction) async {
          final commandeResult =
              await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (commandeResult.isEmpty) {
            throw const CaisseTransactionException(
              'La commande est introuvable.',
            );
          }

          final commande =
              Commande.fromMap(
            commandeResult.first,
          );

          if (commande.syncStatus == 'synced' ||
              commande.idDjango != null) {
            throw const CaisseTransactionException(
              'Cette commande a déjà été synchronisée et ne peut plus être supprimée localement.',
            );
          }

          final shops =
              await transaction.query(
            DatabaseTables.shop,
            where: 'commande_id = ?',
            whereArgs: [commandeId],
            orderBy: 'id ASC',
          );

          final restaurations =
              <Map<String, dynamic>>[];

          for (final shop in shops) {
            final articleId =
                _convertirEnInt(
              shop['article_id'],
            );

            final quantite =
                _convertirEnInt(
                      shop['quantite'],
                    ) ??
                    0;

            if (articleId == null) {
              throw const CaisseTransactionException(
                'Un produit de la commande ne possède pas de sous-produit associé.',
              );
            }

            final stockResult =
                await transaction.query(
              DatabaseTables.stock,
              where:
                  'point_de_vente_id = ? '
                  'AND sous_produit_id = ?',
              whereArgs: [
                pointDeVenteId,
                articleId,
              ],
              limit: 1,
            );

            if (stockResult.isEmpty) {
              final pointDeVente =
                  await _obtenirNomPointDeVente(
                transaction,
                pointDeVenteId,
              );

              final codeSousProduit =
                  await _obtenirCodeSousProduit(
                transaction,
                articleId,
              );

              throw StockIntrouvableException(
                pointDeVente: pointDeVente,
                sousProduit: codeSousProduit,
              );
            }

            restaurations.add({
              'stock':
                  stockResult.first,
              'quantite':
                  quantite,
            });
          }

          // ======================================================
          // RESTAURER STOCK
          // ======================================================

          for (final restauration
              in restaurations) {
            final stock =
                restauration['stock']
                    as Map<String, dynamic>;

            final quantite =
                restauration['quantite']
                    as int;

            final stockId =
                _convertirEnInt(
              stock['id'],
            );

            final stockActuel =
                _convertirEnInt(
                      stock['quantite'],
                    ) ??
                    0;

            if (stockId == null) {
              throw const CaisseTransactionException(
                'Le stock local possède un identifiant invalide.',
              );
            }

            await transaction.update(
              DatabaseTables.stock,
              {
                'quantite':
                    stockActuel + quantite,
              },
              where: 'id = ?',
              whereArgs: [stockId],
            );
          }

          // ======================================================
          // SUPPRIMER SYNCHRONISATION
          // ======================================================

          await transaction.delete(
            DatabaseTables.synchronisation,
            where:
                'commande_locale_id = ?',
            whereArgs: [commandeId],
          );

          // ======================================================
          // SUPPRIMER COMMANDE
          // ======================================================

          await transaction.delete(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
          );
        },
      );
    } on CommandeRepositoryException {
      rethrow;
    } catch (e) {
      throw CaisseTransactionException(
        'Impossible de supprimer la commande.',
        cause: e,
      );
    }
  }

  // ============================================================
  // SUPPRIMER COMMANDE APRÈS SYNCHRONISATION
  // ============================================================

  Future<void> supprimerApresSynchronisation(
    int commandeId,
  ) async {
    final db =
        await DatabaseHelper.obtenirBase();

    try {
      await db.transaction(
        (transaction) async {
          final commandeResult =
              await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (commandeResult.isEmpty) {
            return;
          }

          final commande =
              Commande.fromMap(
            commandeResult.first,
          );

          if (commande.statutLocal !=
                  'Facture' ||
              commande.syncStatus !=
                  'synced' ||
              commande.idDjango == null) {
            throw const CaisseTransactionException(
              'Impossible de supprimer une commande locale '
              'qui n’a pas été confirmée comme synchronisée.',
            );
          }

          // ------------------------------------------------------
          // IMPORTANT :
          // ne PAS restaurer le stock.
          //
          // Le serveur a déjà enregistré la vente.
          // ------------------------------------------------------

          await transaction.delete(
            DatabaseTables.synchronisation,
            where:
                'commande_locale_id = ?',
            whereArgs: [commandeId],
          );

          await transaction.delete(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
          );
        },
      );
    } on CommandeRepositoryException {
      rethrow;
    } catch (e) {
      throw CaisseTransactionException(
        'Impossible de supprimer la commande locale après synchronisation.',
        cause: e,
      );
    }
  }

  // ============================================================
  // METTRE À JOUR INFORMATIONS
  // ============================================================

  Future<void> mettreAJourInformations({
    required int commandeId,
    required String nom,
    required String telephone,
    required int remise,
  }) async {
    if (nom.trim().isEmpty) {
      throw const CaisseTransactionException(
        'Le nom du client est obligatoire.',
      );
    }

    if (telephone.trim().isEmpty) {
      throw const CaisseTransactionException(
        'Le téléphone du client est obligatoire.',
      );
    }

    if (remise < 0) {
      throw const CaisseTransactionException(
        'La remise ne peut pas être négative.',
      );
    }

    final db =
        await DatabaseHelper.obtenirBase();

    try {
      await db.transaction(
        (transaction) async {
          final commandeResult =
              await transaction.query(
            DatabaseTables.commande,
            where: 'id = ?',
            whereArgs: [commandeId],
            limit: 1,
          );

          if (commandeResult.isEmpty) {
            throw const CaisseTransactionException(
              'La commande est introuvable.',
            );
          }

          final commande =
              Commande.fromMap(
            commandeResult.first,
          );

          if (commande.syncStatus == 'synced' ||
              commande.idDjango != null) {
            throw const CaisseTransactionException(
              'Cette commande a déjà été synchronisée et ne peut plus être modifiée localement.',
            );
          }

          await transaction.update(
            DatabaseTables.commande,
            {
              'nom': nom.trim(),
              'telephone':
                  telephone.trim(),
              'remise': remise,
              'date_update':
                  DateTime.now()
                      .toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [commandeId],
          );

          await _recalculerTotauxTransaction(
            transaction,
            commandeId,
          );
        },
      );
    } on CommandeRepositoryException {
      rethrow;
    } catch (e) {
      throw CaisseTransactionException(
        'Impossible de mettre à jour la commande.',
        cause: e,
      );
    }
  }

  // ============================================================
  // RECALCULER TOTAUX
  // ============================================================

  Future<void> recalculerTotaux(
    int commandeId,
  ) async {
    final db =
        await DatabaseHelper.obtenirBase();

    await db.transaction(
      (transaction) async {
        await _recalculerTotauxTransaction(
          transaction,
          commandeId,
        );
      },
    );
  }

  // ============================================================
  // RECALCUL INTERNE
  // ============================================================

  Future<void> _recalculerTotauxTransaction(
    Transaction transaction,
    int commandeId,
  ) async {
    final commandeResult =
        await transaction.query(
      DatabaseTables.commande,
      where: 'id = ?',
      whereArgs: [commandeId],
      limit: 1,
    );

    if (commandeResult.isEmpty) {
      throw const CaisseTransactionException(
        'La commande est introuvable.',
      );
    }

    final commande =
        commandeResult.first;

    final shops =
        await transaction.query(
      DatabaseTables.shop,
      where: 'commande_id = ?',
      whereArgs: [commandeId],
      orderBy: 'id ASC',
    );

    int montant = 0;

    for (final shop in shops) {
      final statut =
          shop['statut']?.toString() ??
              'Caisse';

      if (statut.toLowerCase() ==
          'annule') {
        continue;
      }

      montant +=
          _convertirEnInt(
                shop['montant'],
              ) ??
              0;
    }

    final remise =
        _convertirEnInt(
              commande['remise'],
            ) ??
            0;

    final livraison =
        _convertirEnInt(
              commande['livraison'],
            ) ??
            0;

    final total =
        max(
      0,
      montant - remise + livraison,
    );

    await transaction.update(
      DatabaseTables.commande,
      {
        'montant': montant,
        'total': total,
        'date_update':
            DateTime.now()
                .toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [commandeId],
    );
  }

  // ============================================================
  // SUPPRESSION SIMPLE
  // ============================================================

  Future<int> supprimer(
    int id,
  ) async {
    final db =
        await DatabaseHelper.obtenirBase();

    return db.delete(
      DatabaseTables.commande,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // COMPTER
  // ============================================================

  Future<int> compter() async {
    final db =
        await DatabaseHelper.obtenirBase();

    final resultats =
        await db.rawQuery(
      'SELECT COUNT(*) AS total '
      'FROM ${DatabaseTables.commande}',
    );

    return Sqflite.firstIntValue(
          resultats,
        ) ??
        0;
  }

  // ============================================================
  // COMPTER EN ATTENTE
  // ============================================================

  Future<int>
      compterEnAttenteSynchronisation() async {
    final db =
        await DatabaseHelper.obtenirBase();

    final resultats =
        await db.rawQuery(
      'SELECT COUNT(*) AS total '
      'FROM ${DatabaseTables.commande} '
      'WHERE sync_status = ? '
      'AND statut_local = ?',
      [
        'pending',
        'Facture',
      ],
    );

    return Sqflite.firstIntValue(
          resultats,
        ) ??
        0;
  }

  // ============================================================
  // CODE SOUS-PRODUIT
  // ============================================================

  Future<String> _obtenirCodeSousProduit(
    Transaction transaction,
    int sousProduitId,
  ) async {
    final resultats =
        await transaction.query(
      DatabaseTables.sousProduit,
      columns: [
        'identifiant',
        'numero',
      ],
      where: 'id = ?',
      whereArgs: [sousProduitId],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return sousProduitId.toString();
    }

    final sousProduit =
        resultats.first;

    final identifiant =
        sousProduit['identifiant']
            ?.toString()
            .trim();

    if (identifiant != null &&
        identifiant.isNotEmpty) {
      return identifiant;
    }

    final numero =
        sousProduit['numero']
            ?.toString()
            .trim();

    if (numero != null &&
        numero.isNotEmpty) {
      return numero;
    }

    return sousProduitId.toString();
  }

  // ============================================================
  // NOM POINT DE VENTE
  // ============================================================

  Future<String> _obtenirNomPointDeVente(
    Transaction transaction,
    int pointDeVenteId,
  ) async {
    final resultats =
        await transaction.query(
      DatabaseTables.pointVente,
      columns: [
        'ville',
        'quartier',
      ],
      where: 'id = ?',
      whereArgs: [pointDeVenteId],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return pointDeVenteId.toString();
    }

    final ville =
        resultats.first['ville']
                ?.toString()
                .trim() ??
            '';

    final quartier =
        resultats.first['quartier']
                ?.toString()
                .trim() ??
            '';

    if (ville.isEmpty &&
        quartier.isEmpty) {
      return pointDeVenteId.toString();
    }

    if (ville.isEmpty) {
      return quartier;
    }

    if (quartier.isEmpty) {
      return ville;
    }

    return '$ville - $quartier';
  }

  // ============================================================
  // GÉNÉRER ID LOCAL
  // ============================================================

  String _genererIdLocal() {
    final maintenant =
        DateTime.now()
            .microsecondsSinceEpoch;

    final aleatoire =
        Random.secure()
            .nextInt(1000000);

    return 'CMD-$maintenant-$aleatoire';
  }

  // ============================================================
  // CONVERSION ENTIER
  // ============================================================

  int? _convertirEnInt(
    dynamic valeur,
  ) {
    if (valeur == null) {
      return null;
    }

    if (valeur is int) {
      return valeur;
    }

    if (valeur is num) {
      return valeur.toInt();
    }

    return int.tryParse(
      valeur.toString(),
    );
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

class CommandeRepositoryException
    implements Exception {
  final String message;
  final Object? cause;

  const CommandeRepositoryException(
    this.message, {
    this.cause,
  });

  @override
  String toString() {
    if (cause == null) {
      return message;
    }

    return '$message Cause : $cause';
  }
}

// ============================================================================
// EXCEPTION TRANSACTION CAISSE
// ============================================================================

class CaisseTransactionException
    extends CommandeRepositoryException {
  const CaisseTransactionException(
    super.message, {
    super.cause,
  });
}

// ============================================================================
// STOCK INTROUVABLE
// ============================================================================

class StockIntrouvableException
    extends CaisseTransactionException {
  final String pointDeVente;
  final String sousProduit;

  StockIntrouvableException({
    required this.pointDeVente,
    required this.sousProduit,
  }) : super(
          'Stock introuvable pour le point de vente '
          '$pointDeVente et le sous-produit '
          '$sousProduit. '
          'Veuillez vérifier le stock dans le dépôt central.',
        );
}