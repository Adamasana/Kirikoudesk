import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';
import '../../models/commande.dart';
import '../../models/session.dart';
import '../../repositories/commande_repository.dart';
import '../../repositories/stock_repository.dart';
import '../api/api_client.dart';

class CommandeSyncService {
  final ApiClient _apiClient;
  final CommandeRepository _commandeRepository;
  final StockRepository _stockRepository;

  CommandeSyncService({
    ApiClient? apiClient,
    CommandeRepository? commandeRepository,
    StockRepository? stockRepository,
  })  : _apiClient = apiClient ?? ApiClient(),
        _commandeRepository =
            commandeRepository ?? const CommandeRepository(),
        _stockRepository =
            stockRepository ?? const StockRepository();

  // ============================================================
  // SYNCHRONISER UNE COMMANDE VALIDÉE
  // ============================================================

  Future<Commande> synchroniserCommande(
    Commande commande,
  ) async {
    // ----------------------------------------------------------
    // 1. Vérifications locales
    // ----------------------------------------------------------

    if (commande.id == null) {
      throw const CommandeSyncException(
        'Impossible de synchroniser une commande sans '
        'identifiant local.',
      );
    }

    if (commande.idLocal.trim().isEmpty) {
      throw const CommandeSyncException(
        'La commande ne possède pas d’identifiant local.',
      );
    }

    if (commande.statutLocal != 'Facture') {
      throw const CommandeSyncException(
        'La commande doit être validée localement avant '
        'de pouvoir être synchronisée.',
      );
    }

    // ----------------------------------------------------------
    // La date de validation est obligatoire.
    //
    // Elle représente le véritable moment où la vente a été
    // validée dans la caisse.
    //
    // Elle sera envoyée à Django dans le champ "date".
    // ----------------------------------------------------------

    if (commande.dateValidation == null) {
      throw const CommandeSyncException(
        'Impossible de synchroniser la commande : '
        'sa date de validation est introuvable.',
      );
    }

    // ----------------------------------------------------------
    // Si elle est déjà synchronisée, inutile de la renvoyer.
    // ----------------------------------------------------------

    if (commande.syncStatus == 'synced' &&
        commande.idDjango != null) {
      return commande;
    }

    // ----------------------------------------------------------
    // 2. Récupérer les articles
    // ----------------------------------------------------------

    final shops =
        await _commandeRepository.obtenirShopsParCommande(
      commande.id!,
    );

    if (shops.isEmpty) {
      throw const CommandeSyncException(
        'Impossible de synchroniser une commande sans article.',
      );
    }

    // ----------------------------------------------------------
    // 3. Construire les articles attendus par Django
    // ----------------------------------------------------------

    final db = await DatabaseHelper.obtenirBase();

    final articles = <Map<String, dynamic>>[];

    for (final shop in shops) {
      final articleId = _convertirEnInt(
        shop['article_id'],
      );

      if (articleId == null) {
        throw const CommandeSyncException(
          'Un article de la commande possède un '
          'identifiant invalide.',
        );
      }

      // --------------------------------------------------------
      // Le Shop pointe directement vers le SousProduit.
      // --------------------------------------------------------

      final sousProduitResultats = await db.query(
        DatabaseTables.sousProduit,
        columns: [
          'identifiant',
        ],
        where: 'id = ?',
        whereArgs: [
          articleId,
        ],
        limit: 1,
      );

      if (sousProduitResultats.isEmpty) {
        throw CommandeSyncException(
          'Le sous-produit local $articleId est introuvable.',
        );
      }

      final identifiant =
          sousProduitResultats.first['identifiant']
                  ?.toString()
                  .trim() ??
              '';

      if (identifiant.isEmpty) {
        throw CommandeSyncException(
          'Le sous-produit local $articleId ne possède '
          'pas d’identifiant.',
        );
      }

      final quantite =
          _convertirEnInt(
                shop['quantite'],
              ) ??
              0;

      if (quantite < 1) {
        throw const CommandeSyncException(
          'La quantité d’un article est invalide.',
        );
      }

      articles.add({
        'identifiant': identifiant,
        'quantite': quantite,
      });
    }

    // ----------------------------------------------------------
    // 4. Construire le payload Django
    // ----------------------------------------------------------
    //
    // IMPORTANT :
    //
    // dateValidation = moment réel de validation locale.
    //
    // On l'envoie dans "date" parce que le backend Django
    // utilise ce champ pour renseigner Commande.date.
    //
    // On ne doit surtout pas utiliser DateTime.now() ici :
    //
    // - la vente peut avoir été validée hors ligne ;
    // - Internet peut revenir plusieurs minutes/heures plus tard ;
    // - la date de la facture doit rester la date réelle
    //   de validation.
    //
    // ----------------------------------------------------------

    final donnees = <String, dynamic>{
      'id_local': commande.idLocal,
      'nom': commande.nom,
      'telephone': commande.telephone,
      'remise': commande.remise,
      'date': commande.dateValidation!.toUtc().toIso8601String(),
      'articles': articles,
    };

    // ----------------------------------------------------------
    // 5. Envoyer à Django
    // ----------------------------------------------------------

    try {
      final reponse = await _apiClient.post(
        '/synchroniser_commande/',
        donnees: donnees,
      );

      // --------------------------------------------------------
      // Django n'a pas confirmé la synchronisation
      // --------------------------------------------------------

      if (reponse['success'] != true) {
        final code =
            reponse['code']?.toString() ?? '';

        final message =
            reponse['message']?.toString() ??
                'La synchronisation a échoué.';

        // ------------------------------------------------------
        // STOCK INSUFFISANT
        //
        // Django indique le sous-produit concerné.
        //
        // Le stock local correspondant est également mis à zéro.
        // ------------------------------------------------------

        if (code == 'stock_insuffisant') {
          await _gererStockInsuffisant(
            reponse,
          );
        }

        await _marquerEnAttente(
          commande,
          message,
        );

        throw CommandeSyncException(
          message,
        );
      }

      // --------------------------------------------------------
      // 6. Récupérer l'identifiant Django
      // --------------------------------------------------------

      final commandeDjangoId =
          _convertirEnInt(
        reponse['commande_id'],
      );

      if (commandeDjangoId == null) {
        const message =
            'Django a confirmé la synchronisation mais '
            'n’a pas retourné d’identifiant de commande valide.';

        await _marquerEnAttente(
          commande,
          message,
        );

        throw const CommandeSyncException(
          message,
        );
      }

      // --------------------------------------------------------
      // 7. Synchronisation serveur réussie
      // --------------------------------------------------------

      final maintenant = DateTime.now();

      await _commandeRepository.mettreAJourSynchronisation(
        commandeId: commande.id!,
        syncStatus: 'synced',
        idDjango: commandeDjangoId,
        syncDate: maintenant,
        syncErreur: null,
      );

      // --------------------------------------------------------
      // 8. Mettre à jour la table synchronisation
      // --------------------------------------------------------

      await _mettreAJourSynchronisationLocale(
        commandeLocaleId: commande.id!,
        commandeDjangoId: commandeDjangoId,
        statut: 'synced',
      );

      // --------------------------------------------------------
      // 9. Construire la version finale
      // --------------------------------------------------------

      final commandeSynchronisee =
          commande.copyWith(
        idDjango: commandeDjangoId,
        statutLocal: 'Facture',
        syncStatus: 'synced',
        syncDate: maintenant,
        syncErreur: null,
      );

      // --------------------------------------------------------
      // 10. Supprimer la copie locale
      //
      // IMPORTANT :
      //
      // La commande serveur existe maintenant.
      //
      // On utilise supprimerApresSynchronisation() et NON
      // supprimer(), car cette méthode :
      //
      // - vérifie que la commande est bien Facture ;
      // - vérifie qu'elle est synced ;
      // - vérifie qu'elle possède un id Django ;
      // - supprime la ligne synchronisation ;
      // - supprime la commande locale ;
      // - ne restaure PAS le stock.
      //
      // Le stock a déjà été consommé lors de la création locale
      // de la commande.
      // --------------------------------------------------------

      try {
        await _commandeRepository
            .supprimerApresSynchronisation(
          commande.id!,
        );
      } catch (e) {
        throw CommandeSyncException(
          'La facture a bien été synchronisée avec le serveur, '
          'mais sa copie locale n’a pas pu être supprimée.',
          cause: e,
        );
      }

      // --------------------------------------------------------
      // 11. Retourner la commande synchronisée
      // --------------------------------------------------------

      return commandeSynchronisee;
    } on ApiException catch (e) {
      // --------------------------------------------------------
      // Erreur HTTP
      // --------------------------------------------------------

      if (_estStockInsuffisant(e)) {
        await _gererStockInsuffisant(
          e.data,
        );
      }

      await _marquerEnAttente(
        commande,
        e.message,
      );

      throw CommandeSyncException(
        e.message,
        cause: e,
      );
    } on CommandeSyncException {
      rethrow;
    } catch (e) {
      // --------------------------------------------------------
      // Erreur inattendue
      // --------------------------------------------------------

      final commandeActuelle =
          await _commandeRepository.obtenirParId(
        commande.id!,
      );

      if (commandeActuelle != null &&
          commandeActuelle.syncStatus == 'synced' &&
          commandeActuelle.idDjango != null) {
        throw CommandeSyncException(
          'La facture a été synchronisée avec le serveur, '
          'mais une erreur est survenue lors du traitement local.',
          cause: e,
        );
      }

      const message =
          'Impossible de synchroniser la commande.';

      await _marquerEnAttente(
        commande,
        message,
      );

      throw CommandeSyncException(
        message,
        cause: e,
      );
    }
  }

  // ============================================================
  // GESTION DU STOCK INSUFFISANT
  // ============================================================

  Future<void> _gererStockInsuffisant(
    dynamic donnees,
  ) async {
    if (donnees is! Map) {
      return;
    }

    final code =
        donnees['code']?.toString() ?? '';

    if (code != 'stock_insuffisant') {
      return;
    }

    final identifiant =
        donnees['identifiant']
            ?.toString()
            .trim() ??
        '';

    if (identifiant.isEmpty) {
      return;
    }

    // ----------------------------------------------------------
    // Récupérer la session de l'utilisateur connecté
    // ----------------------------------------------------------

    final session =
        await Session.fromPreferences();

    if (session == null) {
      throw const CommandeSyncException(
        'Impossible de mettre à jour le stock local : '
        'aucune session utilisateur active.',
      );
    }

    final pointVenteId =
        session.pointVenteId;

    if (pointVenteId == null) {
      throw const CommandeSyncException(
        'Impossible de mettre à jour le stock local : '
        'aucun point de vente n’est associé à la session.',
      );
    }

    // ----------------------------------------------------------
    // Retrouver le sous-produit local par son identifiant
    // ----------------------------------------------------------

    final db =
        await DatabaseHelper.obtenirBase();

    final sousProduitResultats =
        await db.query(
      DatabaseTables.sousProduit,
      columns: [
        'id',
        'identifiant',
      ],
      where: 'identifiant = ?',
      whereArgs: [
        identifiant,
      ],
      limit: 1,
    );

    if (sousProduitResultats.isEmpty) {
      throw CommandeSyncException(
        'Le sous-produit "$identifiant" existe sur Django '
        'mais est introuvable dans la base locale.',
      );
    }

    final sousProduitId =
        _convertirEnInt(
      sousProduitResultats.first['id'],
    );

    if (sousProduitId == null) {
      throw CommandeSyncException(
        'Identifiant local invalide pour le sous-produit '
        '"$identifiant".',
      );
    }

    // ----------------------------------------------------------
    // Retrouver le stock local du point de vente courant
    // ----------------------------------------------------------

    final stock =
        await _stockRepository
            .obtenirParPointVenteEtSousProduit(
      pointDeVenteId: pointVenteId,
      sousProduitId: sousProduitId,
    );

    if (stock == null) {
      throw CommandeSyncException(
        'Aucun stock local trouvé pour "$identifiant" '
        'au point de vente $pointVenteId.',
      );
    }

    // ----------------------------------------------------------
    // Mettre le stock local à zéro
    // ----------------------------------------------------------

    await _stockRepository.mettreAJour(
      stock.copyWith(
        quantite: 0,
      ),
    );
  }

  // ============================================================
  // VERIFIER SI L'ERREUR EST UN STOCK INSUFFISANT
  // ============================================================

  bool _estStockInsuffisant(
    ApiException exception,
  ) {
    if (exception.data is! Map) {
      return false;
    }

    final code =
        exception.data['code']
            ?.toString() ??
        '';

    return code == 'stock_insuffisant';
  }

  // ============================================================
  // SYNCHRONISER TOUTES LES COMMANDES EN ATTENTE
  // ============================================================

  Future<CommandeSyncResultat>
      synchroniserCommandesEnAttente() async {
    final commandes =
        await _commandeRepository
            .obtenirEnAttenteSynchronisation();

    if (commandes.isEmpty) {
      return const CommandeSyncResultat(
        total: 0,
        reussies: 0,
        erreurs: 0,
      );
    }

    var reussies = 0;
    var erreurs = 0;

    for (final commande in commandes) {
      try {
        await synchroniserCommande(
          commande,
        );

        reussies++;
      } catch (_) {
        erreurs++;
      }
    }

    return CommandeSyncResultat(
      total: commandes.length,
      reussies: reussies,
      erreurs: erreurs,
    );
  }

  // ============================================================
  // MARQUER UNE FACTURE EN ATTENTE
  // ============================================================

  Future<void> _marquerEnAttente(
    Commande commande,
    String message,
  ) async {
    if (commande.id == null) {
      return;
    }

    final commandeActuelle =
        await _commandeRepository.obtenirParId(
      commande.id!,
    );

    if (commandeActuelle == null) {
      return;
    }

    // ----------------------------------------------------------
    // Ne jamais écraser une synchronisation déjà confirmée.
    // ----------------------------------------------------------

    if (commandeActuelle.syncStatus == 'synced' &&
        commandeActuelle.idDjango != null) {
      return;
    }

    await _commandeRepository.mettreAJourSynchronisation(
      commandeId: commande.id!,
      syncStatus: 'pending',
      syncErreur: message,
    );

    await _mettreAJourSynchronisationLocale(
      commandeLocaleId: commande.id!,
      commandeDjangoId: commande.idDjango,
      statut: 'pending',
    );
  }

  // ============================================================
  // METTRE À JOUR LA TABLE synchronisation
  // ============================================================

  Future<void> _mettreAJourSynchronisationLocale({
    required int commandeLocaleId,
    required int? commandeDjangoId,
    required String statut,
  }) async {
    final db =
        await DatabaseHelper.obtenirBase();

    await db.update(
      DatabaseTables.synchronisation,
      {
        'commande_django_id': commandeDjangoId,
        'statut': statut,
      },
      where: 'commande_locale_id = ?',
      whereArgs: [
        commandeLocaleId,
      ],
    );
  }

  // ============================================================
  // CONVERSION
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
  // DISPOSE
  // ============================================================

  void dispose() {
    _apiClient.fermer();
  }
}

// ================================================================
// RESULTAT SYNCHRONISATION
// ================================================================

class CommandeSyncResultat {
  final int total;
  final int reussies;
  final int erreurs;

  const CommandeSyncResultat({
    required this.total,
    required this.reussies,
    required this.erreurs,
  });
}

// ================================================================
// EXCEPTION
// ================================================================

class CommandeSyncException implements Exception {
  final String message;
  final Object? cause;

  const CommandeSyncException(
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