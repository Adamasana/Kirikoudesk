import '../models/dashboard_statistiques.dart';
import '../models/facture.dart';
import '../repositories/dashboard_statistiques_repository.dart';
import '../services/api/api_client.dart';

class DashboardStatistiquesService {
  final ApiClient _apiClient;
  final DashboardStatistiquesRepository _repository;

  DashboardStatistiquesService({
    ApiClient? apiClient,
    DashboardStatistiquesRepository? repository,
  })  : _apiClient = apiClient ?? ApiClient(),
        _repository =
            repository ??
            const DashboardStatistiquesRepository();

  // ============================================================
  // STATISTIQUES COMPLÈTES DU DASHBOARD
  // ============================================================

  Future<DashboardStatistiques>
      obtenirStatistiques() async {
    // ----------------------------------------------------------
    // 1. DONNÉES LOCALES
    // ----------------------------------------------------------

    final statistiquesLocales =
        await _repository.obtenirStatistiquesDuJour();

    DashboardStatistiques? statistiquesServeur;

    // ----------------------------------------------------------
    // 2. DONNÉES SERVEUR
    // ----------------------------------------------------------

    try {
      statistiquesServeur =
          await obtenirStatistiquesServeur();
    } catch (_) {
      statistiquesServeur = null;
    }

    // ----------------------------------------------------------
    // 3. HORS CONNEXION
    // ----------------------------------------------------------

    if (statistiquesServeur == null) {
      return statistiquesLocales;
    }

    // ----------------------------------------------------------
    // 4. FUSION TELEPHONES
    // ----------------------------------------------------------

    final telephones = <String>{
      ...statistiquesLocales.telephones,
      ...statistiquesServeur.telephones,
    }.toList();

    // ----------------------------------------------------------
    // 5. FUSION FACTURES
    // ----------------------------------------------------------

    final facturesRecentes =
        _fusionnerFacturesRecentes(
      statistiquesLocales.facturesRecentes,
      statistiquesServeur.facturesRecentes,
    );

    // ----------------------------------------------------------
    // 6. RESULTAT
    // ----------------------------------------------------------

    return DashboardStatistiques(
      ventes:
          statistiquesLocales.ventes +
          statistiquesServeur.ventes,

      achats:
          statistiquesLocales.achats +
          statistiquesServeur.achats,

      commandes:
          statistiquesLocales.commandes +
          statistiquesServeur.commandes,

      telephones: telephones,

      facturesRecentes:
          facturesRecentes,
    );
  }

  // ============================================================
  // FUSION DES FACTURES
  // ============================================================

  List<Facture> _fusionnerFacturesRecentes(
    List<Facture> locales,
    List<Facture> serveur,
  ) {
    final toutesLesFactures = <Facture>[
      ...locales,
      ...serveur,
    ];

    final facturesUniques =
        <String, Facture>{};

    for (final facture in toutesLesFactures) {
      final cle = _cleFacture(facture);

      // Si la même facture existe déjà,
      // on conserve celle qui possède un id Django.
      final existante =
          facturesUniques[cle];

      if (existante == null) {
        facturesUniques[cle] = facture;
        continue;
      }

      if (existante.idDjango == null &&
          facture.idDjango != null) {
        facturesUniques[cle] = facture;
      }
    }

    final resultat =
        facturesUniques.values.toList();

    // ----------------------------------------------------------
    // TRI : PLUS RECENTE → PLUS ANCIENNE
    // ----------------------------------------------------------

    resultat.sort(
      (a, b) => b.dateCreation.compareTo(
        a.dateCreation,
      ),
    );

    // ----------------------------------------------------------
    // 5 MAXIMUM
    // ----------------------------------------------------------

    return resultat.take(5).toList();
  }

  // ============================================================
  // CLE FACTURE
  // ============================================================

  String _cleFacture(
    Facture facture,
  ) {
    if (facture.idDjango != null) {
      return 'django_${facture.idDjango}';
    }

    return 'local_${facture.id}';
  }

  // ============================================================
  // SERVEUR UNIQUEMENT
  // ============================================================

  Future<DashboardStatistiques>
      obtenirStatistiquesServeur() async {
    final reponse = await _apiClient.get(
      '/dashboard/statistiques/',
    );

    if (reponse['success'] != true) {
      throw ApiException(
        reponse['message']?.toString() ??
            'Impossible de récupérer les statistiques du Dashboard.',
        200,
        data: reponse,
      );
    }

    return DashboardStatistiques.fromJson(
      reponse,
    );
  }

  // ============================================================
  // FERMETURE
  // ============================================================

  void fermer() {
    _apiClient.fermer();
  }
}