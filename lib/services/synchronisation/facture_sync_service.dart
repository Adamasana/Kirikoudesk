import 'package:sqflite/sqflite.dart';

import '../api/api_client.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';

class FactureSyncService {
  final ApiClient _apiClient;

  FactureSyncService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  // ============================================================
  // SYNCHRONISER LES FACTURES
  // ============================================================

  Future<int> synchroniser() async {
    final reponse = await _apiClient.get(
      '/factures/',
    );

    final donnees = reponse['factures'];

    if (donnees is! List) {
      throw const FactureSyncException(
        'La réponse des factures est invalide.',
      );
    }

    final db = await DatabaseHelper.obtenirBase();

    final dateLimite = DateTime.now().subtract(
      const Duration(days: 30),
    );

    int nombreSynchronise = 0;

    // ==========================================================
    // IDENTIFIANTS DJANGO DES FACTURES PRESENTES EN LIGNE
    //
    // On ne conserve ici que les factures des 30 derniers jours.
    //
    // Cela nous permettra ensuite de détecter les factures
    // supprimées en ligne.
    // ==========================================================

    final idsDjangoDistants = <int>{};

    await db.transaction(
      (transaction) async {
        for (final element in donnees) {
          if (element is! Map<String, dynamic>) {
            continue;
          }

          final idDjango = _convertirEnInt(
            element['id'],
          );

          if (idDjango == null) {
            continue;
          }

          final dateCreation = _convertirDate(
            element['date_creation'],
          );

          final dateUpdate = _convertirDate(
            element['date_update'],
          );

          // ----------------------------------------------------
          // NE CONSERVER QUE LES 30 DERNIERS JOURS
          // ----------------------------------------------------

          final dateReference =
              dateUpdate ?? dateCreation;

          if (dateReference != null &&
              dateReference.isBefore(dateLimite)) {
            continue;
          }

          // ----------------------------------------------------
          // Cette facture existe actuellement sur Django.
          //
          // On l'ajoute à la liste des IDs distants afin de
          // pouvoir détecter les suppressions locales plus bas.
          // ----------------------------------------------------

          idsDjangoDistants.add(
            idDjango,
          );

          // ----------------------------------------------------
          // INSERTION / MISE A JOUR
          // ----------------------------------------------------

          await _synchroniserFacture(
            transaction,
            element,
            idDjango,
            dateCreation,
            dateUpdate,
          );

          nombreSynchronise++;
        }

        // ======================================================
        // SUPPRIMER LES FACTURES LOCALES QUI N'EXISTENT PLUS
        // SUR DJANGO
        // ======================================================

        await _supprimerFacturesSupprimeesEnLigne(
          transaction,
          idsDjangoDistants,
          dateLimite,
        );
      },
    );

    return nombreSynchronise;
  }

  // ============================================================
  // SYNCHRONISER UNE FACTURE
  // ============================================================

  Future<void> _synchroniserFacture(
    DatabaseExecutor transaction,
    Map<String, dynamic> facture,
    int idDjango,
    DateTime? dateCreation,
    DateTime? dateUpdate,
  ) async {
    final commandeExistante = await transaction.query(
      DatabaseTables.commande,
      where: 'id_django = ?',
      whereArgs: [
        idDjango,
      ],
      limit: 1,
    );

    final donneesCommande =
        _construireDonneesCommande(
      facture,
      idDjango,
      dateCreation,
      dateUpdate,
    );

    int commandeId;

    // ==========================================================
    // COMMANDE EXISTANTE
    // ==========================================================

    if (commandeExistante.isNotEmpty) {
      commandeId =
          _convertirEnInt(
                commandeExistante.first['id'],
              ) ??
              0;

      if (commandeId == 0) {
        throw const FactureSyncException(
          'Identifiant local de facture invalide.',
        );
      }

      await transaction.update(
        DatabaseTables.commande,
        donneesCommande,
        where: 'id = ?',
        whereArgs: [
          commandeId,
        ],
      );

      // --------------------------------------------------------
      // Les articles distants représentent l'état actuel
      // de la facture.
      //
      // On supprime donc les anciens articles locaux avant
      // de remettre ceux retournés par Django.
      // --------------------------------------------------------

      await transaction.delete(
        DatabaseTables.shop,
        where: 'commande_id = ?',
        whereArgs: [
          commandeId,
        ],
      );
    }

    // ==========================================================
    // NOUVELLE COMMANDE
    // ==========================================================

    else {
      commandeId = await transaction.insert(
        DatabaseTables.commande,
        donneesCommande,
      );
    }

    // ==========================================================
    // ARTICLES
    // ==========================================================

    final articles = facture['articles'];

    if (articles is List) {
      for (final element in articles) {
        if (element is! Map<String, dynamic>) {
          continue;
        }

        await transaction.insert(
          DatabaseTables.shop,
          {
            'commande_id': commandeId,
            'article_id': _convertirEnInt(
              element['article_id'],
            ),
            'quantite':
                _convertirEnInt(
                      element['quantite'],
                    ) ??
                    0,
            'couleur':
                element['couleur']?.toString() ??
                    '',
            'pointure':
                element['pointure']?.toString() ??
                    '',
            'prix':
                _convertirEnInt(
                      element['prix'],
                    ) ??
                    0,
            'montant':
                _convertirEnInt(
                      element['montant'],
                    ) ??
                    0,
            'statut':
                element['statut']?.toString() ??
                    'Facture',
          },
        );
      }
    }
  }

  // ============================================================
  // SUPPRIMER LES FACTURES SUPPRIMEES EN LIGNE
  // ============================================================

  Future<void> _supprimerFacturesSupprimeesEnLigne(
    DatabaseExecutor transaction,
    Set<int> idsDjangoDistants,
    DateTime dateLimite,
  ) async {
    // ----------------------------------------------------------
    // Récupérer uniquement les factures locales qui ont déjà été
    // synchronisées avec Django.
    //
    // IMPORTANT :
    // Les factures "pending" ne sont jamais concernées.
    // Elles doivent rester locales en attendant leur envoi.
    // ----------------------------------------------------------

    final facturesLocales =
        await transaction.query(
      DatabaseTables.commande,
      columns: [
        'id',
        'id_django',
        'date_creation',
        'sync_status',
        'statut_local',
        'origine',
      ],
      where: '''
        statut_local = ?
        AND origine = ?
        AND sync_status = ?
        AND id_django IS NOT NULL
        AND date_creation >= ?
      ''',
      whereArgs: [
        'Facture',
        'Caisse',
        'synced',
        dateLimite.toIso8601String(),
      ],
    );

    // ----------------------------------------------------------
    // Examiner chaque facture locale synchronisée.
    // ----------------------------------------------------------

    for (final factureLocale
        in facturesLocales) {
      final idLocal =
          _convertirEnInt(
        factureLocale['id'],
      );

      final idDjango =
          _convertirEnInt(
        factureLocale['id_django'],
      );

      if (idLocal == null || idDjango == null) {
        continue;
      }

      // --------------------------------------------------------
      // Si l'ID Django existe encore dans la réponse du serveur,
      // la facture existe toujours en ligne.
      // --------------------------------------------------------

      if (idsDjangoDistants.contains(idDjango)) {
        continue;
      }

      // --------------------------------------------------------
      // L'ID Django n'existe plus dans la réponse.
      //
      // La facture a donc été supprimée en ligne.
      //
      // On supprime :
      //   1. les articles Shop
      //   2. la synchronisation locale
      //   3. la commande locale
      // --------------------------------------------------------

      await transaction.delete(
        DatabaseTables.shop,
        where: 'commande_id = ?',
        whereArgs: [
          idLocal,
        ],
      );

      await transaction.delete(
        DatabaseTables.synchronisation,
        where: 'commande_locale_id = ?',
        whereArgs: [
          idLocal,
        ],
      );

      await transaction.delete(
        DatabaseTables.commande,
        where: 'id = ?',
        whereArgs: [
          idLocal,
        ],
      );
    }
  }

  // ============================================================
  // DONNEES COMMANDE
  // ============================================================

  Map<String, dynamic> _construireDonneesCommande(
    Map<String, dynamic> facture,
    int idDjango,
    DateTime? dateCreation,
    DateTime? dateUpdate,
  ) {
    final dateCreationEffective =
        dateCreation ?? DateTime.now();

    final idLocal =
        'DJANGO-FACTURE-$idDjango';

    return {
      'id_local': idLocal,
      'id_django': idDjango,

      'user_id': null,
      'encaisse_par': null,
      'gestionnaire_id': null,

      'nom':
          facture['nom']?.toString() ??
              '',
      'telephone':
          facture['telephone']?.toString() ??
              '',

      'ville':
          facture['ville']?.toString(),

      'deplacement':
          facture['deplacement']?.toString(),

      'montant':
          _convertirEnInt(
                facture['montant'],
              ) ??
              0,

      'remise':
          _convertirEnInt(
                facture['remise'],
              ) ??
              0,

      'livraison':
          _convertirEnInt(
                facture['livraison'],
              ) ??
              0,

      'total':
          _convertirEnInt(
                facture['total'],
              ) ??
              0,

      'payer': _convertirPayer(
        facture['payer'],
      ),

      'statut_local': 'Facture',

      'origine': 'Caisse',

      'date_creation':
          dateCreationEffective
              .toIso8601String(),

      'date_update':
          dateUpdate?.toIso8601String(),

      'sync_status': 'synced',

      'sync_date':
          DateTime.now()
              .toIso8601String(),

      'sync_erreur': null,
    };
  }

  // ============================================================
  // PAIEMENT
  // ============================================================

  String _convertirPayer(
    dynamic valeur,
  ) {
    if (valeur == null) {
      return 'Non';
    }

    if (valeur is bool) {
      return valeur ? 'Oui' : 'Non';
    }

    final texte =
        valeur.toString().trim();

    if (texte.isEmpty) {
      return 'Non';
    }

    return texte;
  }

  // ============================================================
  // CONVERSION EN ENTIER
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

  // ============================================================
  // CONVERSION EN DATE
  // ============================================================

  DateTime? _convertirDate(
    dynamic valeur,
  ) {
    if (valeur == null) {
      return null;
    }

    final texte =
        valeur.toString().trim();

    if (texte.isEmpty) {
      return null;
    }

    return DateTime.tryParse(
      texte,
    );
  }

  // ============================================================
  // FERMETURE DU SERVICE
  // ============================================================

  void dispose() {
    _apiClient.fermer();
  }
}

// ================================================================
// EXCEPTION
// ================================================================

class FactureSyncException
    implements Exception {
  final String message;

  const FactureSyncException(
    this.message,
  );

  @override
  String toString() {
    return message;
  }
}