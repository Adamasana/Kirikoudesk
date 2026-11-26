
import '../api/api_client.dart';
import '../../repositories/synchronisation_incrementale_repository.dart';

class SynchronisationIncrementaleService {
  final ApiClient _apiClient;
  final SynchronisationIncrementaleRepository _repository;

  // ============================================================
  // VERROU GLOBAL
  // ============================================================

  /// Empêche plusieurs synchronisations simultanées,
  /// même si plusieurs instances du service existent.

  static bool _synchronisationEnCours = false;

  bool get estEnCours => _synchronisationEnCours;

  // ============================================================
  // CONSTRUCTEUR
  // ============================================================

  SynchronisationIncrementaleService({
    ApiClient? apiClient,
    SynchronisationIncrementaleRepository? repository,
  })  : _apiClient = apiClient ?? ApiClient(),
        _repository = repository ??
            const SynchronisationIncrementaleRepository();

  // ============================================================
  // SYNCHRONISATION COMPLETE
  // ============================================================

  /// Synchronise les nouveaux produits, sous-produits et stocks.
  ///
  /// Ordre :
  /// 1. Initialisation des curseurs.
  /// 2. Récupération des nouveaux produits.
  /// 3. Enregistrement des produits.
  /// 4. Récupération des nouveaux sous-produits et stocks.
  /// 5. Enregistrement des sous-produits et stocks.
  ///
  /// Retourne null si une autre synchronisation est déjà en cours.
  ///
  /// En cas d'erreur, l'exception est propagée à l'appelant.

  Future<Map<String, int>?> synchroniser() async {
    // ----------------------------------------------------------
    // VERIFIER LE VERROU
    // ----------------------------------------------------------

    if (_synchronisationEnCours) {
      return null;
    }

    _synchronisationEnCours = true;

    try {
      // --------------------------------------------------------
      // 1. INITIALISER LES CURSEURS
      // --------------------------------------------------------

      final curseurs =
          await _repository.initialiserCurseurs();

      final dernierProduitId =
          curseurs['dernier_produit_id']!;

      final dernierSousProduitId =
          curseurs['dernier_sous_produit_id']!;

      int nombreProduits = 0;
      int nombreSousProduits = 0;
      int nombreStocks = 0;

      // --------------------------------------------------------
      // 2. RECUPERER LES NOUVEAUX PRODUITS
      // --------------------------------------------------------

      final reponseProduits =
          await _apiClient.obtenirNouveauxProduits(
        dernierId: dernierProduitId,
      );

      _verifierReponse(
        reponseProduits,
        'Récupération des nouveaux produits',
      );

      final produits = _extraireListe(
        reponseProduits,
        'produits',
      );

      final nouveauDernierProduitId = _extraireDernierId(
        reponseProduits,
        'dernier_id',
      );

      // --------------------------------------------------------
      // 3. ENREGISTRER LES NOUVEAUX PRODUITS
      // --------------------------------------------------------

      if (produits.isNotEmpty) {
        await _repository.enregistrerNouveauxProduits(
          produits: produits,
          dernierId: nouveauDernierProduitId,
        );

        nombreProduits = produits.length;
      }

      // --------------------------------------------------------
      // 4. RECUPERER LES NOUVEAUX SOUS-PRODUITS ET STOCKS
      // --------------------------------------------------------

      final reponseSousProduits =
          await _apiClient.obtenirNouveauxSousProduits(
        dernierId: dernierSousProduitId,
      );

      _verifierReponse(
        reponseSousProduits,
        'Récupération des nouveaux sous-produits',
      );

      final sousProduits = _extraireListe(
        reponseSousProduits,
        'sous_produits',
      );

      final stocks = _extraireListe(
        reponseSousProduits,
        'stocks',
      );

      final nouveauDernierSousProduitId =
          _extraireDernierId(
        reponseSousProduits,
        'dernier_id',
      );

      // --------------------------------------------------------
      // 5. ENREGISTRER LES SOUS-PRODUITS ET STOCKS
      // --------------------------------------------------------

      if (sousProduits.isNotEmpty || stocks.isNotEmpty) {
        await _repository.enregistrerNouveauxSousProduits(
          sousProduits: sousProduits,
          stocks: stocks,
          dernierId: nouveauDernierSousProduitId,
        );

        nombreSousProduits = sousProduits.length;
        nombreStocks = stocks.length;
      }

      // --------------------------------------------------------
      // 6. RETOURNER LE BILAN
      // --------------------------------------------------------

      return {
        'produits': nombreProduits,
        'sous_produits': nombreSousProduits,
        'stocks': nombreStocks,
      };
    } finally {
      // --------------------------------------------------------
      // LIBERER LE VERROU
      // --------------------------------------------------------

      _synchronisationEnCours = false;
    }
  }

  // ============================================================
  // VERIFIER LA REPONSE API
  // ============================================================

  void _verifierReponse(
    Map<String, dynamic> reponse,
    String operation,
  ) {
    if (reponse['success'] != true) {
      final message =
          reponse['message'] ??
          reponse['error'] ??
          'Réponse invalide du serveur.';

      throw FormatException(
        '$operation : $message',
      );
    }
  }

  // ============================================================
  // EXTRAIRE UNE LISTE JSON
  // ============================================================

  List<dynamic> _extraireListe(
    Map<String, dynamic> reponse,
    String cle,
  ) {
    final donnees = reponse[cle];

    if (donnees == null) {
      throw FormatException(
        'La réponse du serveur ne contient pas la clé "$cle".',
      );
    }

    if (donnees is! List) {
      throw FormatException(
        'Le champ "$cle" reçu du serveur n’est pas une liste.',
      );
    }

    return donnees;
  }

  // ============================================================
  // EXTRAIRE LE DERNIER ID
  // ============================================================

  int _extraireDernierId(
    Map<String, dynamic> reponse,
    String cle,
  ) {
    final valeur = reponse[cle];

    if (valeur is int) {
      return valeur;
    }

    if (valeur is num) {
      return valeur.toInt();
    }

    if (valeur is String) {
      final resultat = int.tryParse(valeur);

      if (resultat != null) {
        return resultat;
      }
    }

    throw FormatException(
      'Le champ "$cle" reçu du serveur est invalide.',
    );
  }

  // ============================================================
  // FERMER LE CLIENT API
  // ============================================================

  void fermer() {
    _apiClient.fermer();
  }
}
