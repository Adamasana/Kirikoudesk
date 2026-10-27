import '../api/api_client.dart';
import 'commande_sync_service.dart';
import '../../repositories/commande_repository.dart';

class SynchronisationGlobaleService {
  final ApiClient _apiClient;
  final CommandeRepository _commandeRepository;

  late final CommandeSyncService _commandeSyncService;

  SynchronisationGlobaleService({
    ApiClient? apiClient,
    CommandeRepository? commandeRepository,
  })  : _apiClient = apiClient ?? ApiClient(),
        _commandeRepository =
            commandeRepository ?? const CommandeRepository() {
    // IMPORTANT :
    // On réutilise exactement le même ApiClient et le même
    // CommandeRepository que ceux du service global.
    //
    // Ainsi, on ne recrée pas une autre logique de synchronisation.
    _commandeSyncService = CommandeSyncService(
      apiClient: _apiClient,
      commandeRepository: _commandeRepository,
    );
  }

  // ============================================================
  // SYNCHRONISATION GLOBALE
  // ============================================================
  //
  // Pour le moment, la synchronisation globale s'occupe
  // prioritairement des commandes locales en attente.
  //
  // IMPORTANT :
  //
  // On NE reconstruit PAS ici le payload de la commande.
  //
  // On NE fait PAS :
  //
  //     POST /synchroniser/
  //
  // pour les commandes.
  //
  // On réutilise directement :
  //
  //     CommandeSyncService.synchroniserCommande()
  //
  // Ce service possède déjà toute la logique fiable :
  //
  //   - récupération des Shops
  //   - récupération des SousProduits
  //   - construction du payload
  //   - appel /synchroniser_commande/
  //   - gestion du stock insuffisant
  //   - gestion des erreurs
  //   - mise à jour sync_status
  //   - récupération de commande_id Django
  //   - SUPPRESSION DE LA COMMANDE LOCALE
  //
  // La commande n'est donc supprimée que si Django confirme
  // réellement la synchronisation.
  //
  // ============================================================

  Future<SynchronisationGlobaleResultat> synchroniser() async {
    final commandes =
        await _commandeRepository.obtenirEnAttenteSynchronisation();

    // ------------------------------------------------------------
    // Aucune commande en attente
    // ------------------------------------------------------------

    if (commandes.isEmpty) {
      return const SynchronisationGlobaleResultat(
        success: true,
        totalCommandes: 0,
        commandesSynchronisees: 0,
        commandesDejaSynchronisees: 0,
        erreursCommandes: [],
        resultatsCommandes: [],
        pointsDeVente: [],
        equipes: [],
        produits: [],
        sousProduits: [],
        stocks: [],
        factures: [],
        dashboard: {},
      );
    }

    var commandesSynchronisees = 0;
    var commandesDejaSynchronisees = 0;

    final erreursCommandes = <dynamic>[];
    final resultatsCommandes = <dynamic>[];

    // ------------------------------------------------------------
    // Synchronisation commande par commande
    // ------------------------------------------------------------

    for (final commande in commandes) {
      try {
        final commandeSynchronisee =
            await _commandeSyncService.synchroniserCommande(
          commande,
        );

        commandesSynchronisees++;

        resultatsCommandes.add({
          'success': true,
          'id_local': commande.idLocal,
          'commande_id': commandeSynchronisee.idDjango,
        });
      } catch (e) {
        // --------------------------------------------------------
        // IMPORTANT :
        //
        // Une erreur sur une commande ne doit pas empêcher les
        // autres commandes d'être synchronisées.
        //
        // CommandeSyncService a déjà remis la commande en pending
        // lorsque la synchronisation échoue.
        // --------------------------------------------------------

        erreursCommandes.add({
          'success': false,
          'id_local': commande.idLocal,
          'message': e.toString(),
        });
      }
    }

    return SynchronisationGlobaleResultat(
      success: erreursCommandes.isEmpty,
      totalCommandes: commandes.length,
      commandesSynchronisees: commandesSynchronisees,
      commandesDejaSynchronisees: commandesDejaSynchronisees,
      erreursCommandes: erreursCommandes,
      resultatsCommandes: resultatsCommandes,
      pointsDeVente: const [],
      equipes: const [],
      produits: const [],
      sousProduits: const [],
      stocks: const [],
      factures: const [],
      dashboard: const {},
    );
  }

  // ============================================================
  // FERMER
  // ============================================================

  void fermer() {
    _apiClient.fermer();
  }
}

// ============================================================================
// RÉSULTAT DE LA SYNCHRONISATION GLOBALE
// ============================================================================

class SynchronisationGlobaleResultat {
  final bool success;

  // ------------------------------------------------------------
  // COMMANDES
  // ------------------------------------------------------------

  final int totalCommandes;
  final int commandesSynchronisees;
  final int commandesDejaSynchronisees;
  final List<dynamic> erreursCommandes;
  final List<dynamic> resultatsCommandes;

  // ------------------------------------------------------------
  // DONNÉES DE RÉFÉRENCE
  // ------------------------------------------------------------

  final List<dynamic> pointsDeVente;
  final List<dynamic> equipes;
  final List<dynamic> produits;
  final List<dynamic> sousProduits;
  final List<dynamic> stocks;
  final List<dynamic> factures;
  final Map<String, dynamic> dashboard;

  const SynchronisationGlobaleResultat({
    required this.success,
    required this.totalCommandes,
    required this.commandesSynchronisees,
    required this.commandesDejaSynchronisees,
    required this.erreursCommandes,
    required this.resultatsCommandes,
    required this.pointsDeVente,
    required this.equipes,
    required this.produits,
    required this.sousProduits,
    required this.stocks,
    required this.factures,
    required this.dashboard,
  });

  // ============================================================
  // CONSTRUIRE DEPUIS LA RÉPONSE API
  // ============================================================

  factory SynchronisationGlobaleResultat.fromMap(
    Map<String, dynamic> donnees,
  ) {
    final commandes =
        donnees['commandes'] is Map
            ? Map<String, dynamic>.from(
                donnees['commandes'] as Map,
              )
            : <String, dynamic>{};

    final donneesServeur =
        donnees['donnees'] is Map
            ? Map<String, dynamic>.from(
                donnees['donnees'] as Map,
              )
            : <String, dynamic>{};

    return SynchronisationGlobaleResultat(
      success: donnees['success'] == true,

      totalCommandes:
          _convertirEnInt(
                commandes['total'],
              ) ??
              0,

      commandesSynchronisees:
          _convertirEnInt(
                commandes['synchronisees'],
              ) ??
              0,

      commandesDejaSynchronisees:
          _convertirEnInt(
                commandes['deja_synchronisees'],
              ) ??
              0,

      erreursCommandes:
          commandes['erreurs'] is List
              ? List<dynamic>.from(
                  commandes['erreurs'] as List,
                )
              : const [],

      resultatsCommandes:
          commandes['resultats'] is List
              ? List<dynamic>.from(
                  commandes['resultats'] as List,
                )
              : const [],

      pointsDeVente:
          donneesServeur['points_de_vente'] is List
              ? List<dynamic>.from(
                  donneesServeur['points_de_vente'] as List,
                )
              : const [],

      equipes:
          donneesServeur['equipes'] is List
              ? List<dynamic>.from(
                  donneesServeur['equipes'] as List,
                )
              : const [],

      produits:
          donneesServeur['produits'] is List
              ? List<dynamic>.from(
                  donneesServeur['produits'] as List,
                )
              : const [],

      sousProduits:
          donneesServeur['sous_produits'] is List
              ? List<dynamic>.from(
                  donneesServeur['sous_produits'] as List,
                )
              : const [],

      stocks:
          donneesServeur['stocks'] is List
              ? List<dynamic>.from(
                  donneesServeur['stocks'] as List,
                )
              : const [],

      factures:
          donneesServeur['factures'] is List
              ? List<dynamic>.from(
                  donneesServeur['factures'] as List,
                )
              : const [],

      dashboard:
          donneesServeur['dashboard'] is Map
              ? Map<String, dynamic>.from(
                  donneesServeur['dashboard'] as Map,
                )
              : const {},
    );
  }

  int get nombreErreurs =>
      erreursCommandes.length;

  bool get toutesLesCommandesSontSynchronisees =>
      totalCommandes ==
      commandesSynchronisees +
          commandesDejaSynchronisees;

  static int? _convertirEnInt(
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
// EXCEPTION
// ============================================================================

class SynchronisationGlobaleException
    implements Exception {
  final String message;

  const SynchronisationGlobaleException(
    this.message,
  );

  @override
  String toString() => message;
}