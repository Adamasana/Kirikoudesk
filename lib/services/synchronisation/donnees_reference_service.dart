import 'package:flutter/foundation.dart';

import '../../models/equipe.dart';
import '../../models/point_vente.dart';
import '../../models/produit.dart';
import '../../models/sous_produit.dart';
import '../../models/stock.dart';

import '../../repositories/equipe_repository.dart';
import '../../repositories/point_vente_repository.dart';
import '../../repositories/produit_repository.dart';
import '../../repositories/sous_produit_repository.dart';
import '../../repositories/stock_repository.dart';

import '../api/api_client.dart';

class DonneesReferenceService {
  final ApiClient _apiClient;

  final PointVenteRepository _pointVenteRepository;
  final EquipeRepository _equipeRepository;
  final ProduitRepository _produitRepository;
  final SousProduitRepository _sousProduitRepository;
  final StockRepository _stockRepository;

  DonneesReferenceService({
    ApiClient? apiClient,
    PointVenteRepository? pointVenteRepository,
    EquipeRepository? equipeRepository,
    ProduitRepository? produitRepository,
    SousProduitRepository? sousProduitRepository,
    StockRepository? stockRepository,
  })  : _apiClient = apiClient ?? ApiClient(),
        _pointVenteRepository =
            pointVenteRepository ?? const PointVenteRepository(),
        _equipeRepository =
            equipeRepository ?? const EquipeRepository(),
        _produitRepository =
            produitRepository ?? const ProduitRepository(),
        _sousProduitRepository =
            sousProduitRepository ?? const SousProduitRepository(),
        _stockRepository =
            stockRepository ?? const StockRepository();

  // ============================================================
  // POINTS DE VENTE
  // ============================================================

  /// Synchronise les points de vente depuis Django vers SQLite.
  ///
  /// [token] est facultatif.
  ///
  /// Lors d'une première connexion, le token vient tout juste
  /// d'être reçu par Django et n'est pas encore forcément
  /// enregistré dans SharedPreferences.
  Future<void> synchroniserPointsDeVente({
    String? token,
  }) async {
    debugPrint('');
    debugPrint('============================================================');
    debugPrint('SYNC POINTS DE VENTE');
    debugPrint('============================================================');

    final reponse = await _apiClient.get(
      '/points-vente/',
      token: token,
    );

    final donnees = _extraireListe(reponse);

    debugPrint(
      'Points de vente reçus depuis Django : ${donnees.length}',
    );

    final pointsDeVente = donnees
        .map(
          (element) => PointVente.fromMap(
            Map<String, dynamic>.from(element),
          ),
        )
        .toList();

    await _pointVenteRepository.enregistrerPlusieurs(
      pointsDeVente,
    );

    debugPrint(
      'Points de vente enregistrés localement : '
      '${pointsDeVente.length}',
    );

    debugPrint('============================================================');
  }

  // ============================================================
  // EQUIPES
  // ============================================================

  /// Synchronise les équipes depuis Django vers SQLite.
  ///
  /// IMPORTANT :
  /// Cette méthode doit être appelée après les points de vente,
  /// car equipe.point_de_vente_id possède une clé étrangère
  /// vers point_vente.id.
  Future<void> synchroniserEquipes({
    String? token,
  }) async {
    debugPrint('');
    debugPrint('============================================================');
    debugPrint('SYNC EQUIPES');
    debugPrint('============================================================');

    final reponse = await _apiClient.get(
      '/equipes/',
      token: token,
    );

    final donnees = _extraireListe(reponse);

    debugPrint(
      'Equipes reçues depuis Django : ${donnees.length}',
    );

    final equipes = <Equipe>[];

    for (final element in donnees) {
      final equipe = Map<String, dynamic>.from(element);

      debugPrint('');
      debugPrint('Equipe Django : $equipe');

      final pointDeVente =
          equipe['point_de_vente'] is Map
              ? Map<String, dynamic>.from(
                  equipe['point_de_vente'] as Map,
                )
              : <String, dynamic>{};

      final pointDeVenteId =
          equipe['point_de_vente_id'] ??
          pointDeVente['id'];

      if (pointDeVenteId == null) {
        debugPrint(
          'Equipe ignorée : aucun point de vente associé.',
        );
        continue;
      }

      final equipeId = _toInt(equipe['id']);

      final equipeLocale = Equipe(
        id: equipeId,
        nom: equipe['nom']?.toString() ?? '',
        pointDeVenteId: _toInt(pointDeVenteId),
        identifiant:
            equipe['identifiant']?.toString() ?? '',
      );

      equipes.add(equipeLocale);

      debugPrint(
        'Equipe préparée : '
        'id=${equipeLocale.id}, '
        'nom=${equipeLocale.nom}, '
        'pointDeVenteId=${equipeLocale.pointDeVenteId}, '
        'identifiant=${equipeLocale.identifiant}',
      );
    }

    await _equipeRepository.enregistrerPlusieurs(
      equipes,
    );

    debugPrint(
      'Equipes enregistrées localement : ${equipes.length}',
    );

    // Vérification spécifique utile pour le compte connecté.
    debugPrint('');
    debugPrint('------------- VÉRIFICATION EQUIPES LOCALES -------------');

    final equipesLocales =
        await _equipeRepository.obtenirToutes();

    debugPrint(
      'Nombre total équipes locales : '
      '${equipesLocales.length}',
    );

    for (final equipe in equipesLocales) {
      debugPrint(
        'Equipe locale #${equipe.id} '
        '- ${equipe.nom} '
        '- PV #${equipe.pointDeVenteId}',
      );
    }

    debugPrint('============================================================');
  }

  // ============================================================
  // PRODUITS
  // ============================================================

  /// Synchronise les produits depuis Django vers SQLite.
  Future<void> synchroniserProduits({
    String? token,
  }) async {
    debugPrint('');
    debugPrint('============================================================');
    debugPrint('SYNC PRODUITS');
    debugPrint('============================================================');

    final reponse = await _apiClient.get(
      '/produits/',
      token: token,
    );

    final donnees = _extraireListe(reponse);

    final produits = donnees
        .map(
          (element) => Produit.fromMap(
            Map<String, dynamic>.from(element),
          ),
        )
        .toList();

    await _produitRepository.enregistrerPlusieurs(
      produits,
    );

    debugPrint(
      'Produits enregistrés localement : ${produits.length}',
    );

    debugPrint('============================================================');
  }

  // ============================================================
  // SOUS-PRODUITS
  // ============================================================

  /// Synchronise les sous-produits depuis Django vers SQLite.
  Future<void> synchroniserSousProduits({
    String? token,
  }) async {
    debugPrint('');
    debugPrint('============================================================');
    debugPrint('SYNC SOUS-PRODUITS');
    debugPrint('============================================================');

    final reponse = await _apiClient.get(
      '/sous-produits/',
      token: token,
    );

    final donnees = _extraireListe(reponse);

    final sousProduits = donnees
        .map(
          (element) => SousProduit.fromMap(
            Map<String, dynamic>.from(element),
          ),
        )
        .toList();

    await _sousProduitRepository.enregistrerPlusieurs(
      sousProduits,
    );

    debugPrint(
      'Sous-produits enregistrés localement : '
      '${sousProduits.length}',
    );

    debugPrint('============================================================');
  }

  // ============================================================
  // STOCKS
  // ============================================================

  /// Synchronise les stocks depuis Django vers SQLite.
  Future<void> synchroniserStocks({
    String? token,
  }) async {
    debugPrint('');
    debugPrint('============================================================');
    debugPrint('SYNC STOCKS');
    debugPrint('============================================================');

    final reponse = await _apiClient.get(
      '/stock/',
      token: token,
    );

    final donnees = _extraireListe(reponse);

    final stocks = donnees
        .map(
          (element) => Stock.fromMap(
            Map<String, dynamic>.from(element),
          ),
        )
        .toList();

    await _stockRepository.enregistrerPlusieurs(
      stocks,
    );

    debugPrint(
      'Stocks enregistrés localement : ${stocks.length}',
    );

    debugPrint('============================================================');
  }

  // ============================================================
  // SYNCHRONISATION COMPLETE
  // ============================================================

  /// Synchronise tous les référentiels.
  ///
  /// Ordre obligatoire :
  ///
  /// 1. Points de vente
  /// 2. Équipes
  /// 3. Produits
  /// 4. Sous-produits
  /// 5. Stocks
  ///
  /// L'ordre est important à cause des clés étrangères.
  Future<void> synchroniser({
    String? token,
  }) async {
    debugPrint('');
    debugPrint('');
    debugPrint('############################################################');
    debugPrint('DÉBUT SYNCHRONISATION RÉFÉRENTIELS');
    debugPrint('############################################################');

    debugPrint(
      'Token fourni directement : '
      '${token != null && token.isNotEmpty}',
    );

    try {
      // --------------------------------------------------------
      // 1. POINTS DE VENTE
      // --------------------------------------------------------

      await synchroniserPointsDeVente(
        token: token,
      );

      // --------------------------------------------------------
      // 2. EQUIPES
      // --------------------------------------------------------

      await synchroniserEquipes(
        token: token,
      );

      // --------------------------------------------------------
      // 3. PRODUITS
      // --------------------------------------------------------

      await synchroniserProduits(
        token: token,
      );

      // --------------------------------------------------------
      // 4. SOUS-PRODUITS
      // --------------------------------------------------------

      await synchroniserSousProduits(
        token: token,
      );

      // --------------------------------------------------------
      // 5. STOCKS
      // --------------------------------------------------------

      await synchroniserStocks(
        token: token,
      );

      debugPrint('');
      debugPrint('############################################################');
      debugPrint('SYNCHRONISATION RÉFÉRENTIELS TERMINÉE');
      debugPrint('############################################################');
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      debugPrint('ERREUR SYNCHRONISATION RÉFÉRENTIELS');
      debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

      debugPrint('Erreur : $e');

      debugPrint('');
      debugPrint('StackTrace :');
      debugPrint('$stackTrace');

      debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

      rethrow;
    }
  }

  // ============================================================
  // AFFICHER LES DONNEES LOCALES
  // ============================================================

  Future<void> afficherDonneesLocales() async {
    final pointsDeVente =
        await _pointVenteRepository.obtenirTous();

    final equipes =
        await _equipeRepository.obtenirToutes();

    final produits =
        await _produitRepository.obtenirTous();

    final sousProduits =
        await _sousProduitRepository.obtenirTous();

    final stocks =
        await _stockRepository.obtenirTous();

    debugPrint(
      '===== DONNÉES LOCALES =====',
    );

    debugPrint(
      'Points de vente : ${pointsDeVente.length}',
    );

    for (final pointDeVente in pointsDeVente) {
      debugPrint(
        'Point de vente #${pointDeVente.id} '
        '- ${pointDeVente.ville} '
        '- ${pointDeVente.quartier}',
      );
    }

    debugPrint(
      'Équipes : ${equipes.length}',
    );

    for (final equipe in equipes) {
      debugPrint(
        'Équipe #${equipe.id} '
        '- ${equipe.nom} '
        '- point de vente #${equipe.pointDeVenteId} '
        '- ${equipe.identifiant}',
      );
    }

    debugPrint(
      'Produits : ${produits.length}',
    );

    for (final produit in produits) {
      debugPrint(
        'Produit #${produit.id} '
        '- ${produit.nom} '
        '- prix : ${produit.prix} '
        '- prix événement : ${produit.prixEvenement} '
        '- prix actuel : ${produit.prixActuel} '
        '- promo : ${produit.promo} '
        '- liquidation : ${produit.liquidation} '
        '- actif : ${produit.actif}',
      );
    }

    debugPrint(
      'Sous-produits : ${sousProduits.length}',
    );

    for (final sousProduit in sousProduits) {
      debugPrint(
        'Sous-produit #${sousProduit.id} '
        '- produit #${sousProduit.produitId} '
        '- ${sousProduit.identifiant} '
        '- couleur : ${sousProduit.couleur} '
        '- pointure : ${sousProduit.pointure} '
        '- actif : ${sousProduit.actif} '
        '- numero : ${sousProduit.numero}',
      );
    }

    debugPrint(
      'Stocks : ${stocks.length}',
    );

    for (final stock in stocks) {
      debugPrint(
        'Stock #${stock.id} '
        '- point de vente #${stock.pointDeVenteId} '
        '- sous-produit #${stock.sousProduitId} '
        '- quantité : ${stock.quantite}',
      );
    }

    debugPrint(
      '===== FIN DONNÉES LOCALES =====',
    );
  }

  // ============================================================
  // EXTRAIRE UNE LISTE DE LA REPONSE API
  // ============================================================

  List<Map<String, dynamic>> _extraireListe(
    dynamic reponse,
  ) {
    dynamic donnees = reponse;

    if (reponse is Map) {
      if (reponse['results'] is List) {
        donnees = reponse['results'];
      } else if (reponse['data'] is List) {
        donnees = reponse['data'];
      } else if (reponse['points_de_vente'] is List) {
        donnees = reponse['points_de_vente'];
      } else if (reponse['equipes'] is List) {
        donnees = reponse['equipes'];
      } else if (reponse['produits'] is List) {
        donnees = reponse['produits'];
      } else if (reponse['sous_produits'] is List) {
        donnees = reponse['sous_produits'];
      } else if (reponse['stocks'] is List) {
        donnees = reponse['stocks'];
      }
    }

    if (donnees is! List) {
      throw ApiException(
        'Le serveur n’a pas retourné une liste de données valide.',
        500,
      );
    }

    return donnees
        .whereType<Map>()
        .map(
          (element) =>
              Map<String, dynamic>.from(element),
        )
        .toList();
  }

  // ============================================================
  // CONVERSION INT
  // ============================================================

  int _toInt(dynamic valeur) {
    if (valeur is int) {
      return valeur;
    }

    return int.parse(
      valeur.toString(),
    );
  }

  // ============================================================
  // FERMER
  // ============================================================

  void fermer() {
    _apiClient.fermer();
  }
}