
import '../api/api_client.dart';
import '../../models/inventaire/inventaire.dart';
import '../../models/inventaire/ligne_inventaire.dart';
import '../../repositories/inventaire_repository.dart';

class InventaireService {
  final InventaireRepository _repository;
  final ApiClient _apiClient;

  InventaireService({
    InventaireRepository? repository,
    ApiClient? apiClient,
  })  : _repository = repository ?? const InventaireRepository(),
        _apiClient = apiClient ?? ApiClient();

  static const String formatJson = 'kirikoubf_inventaire';
  static const int versionJson = 1;

  // ============================================================
  // CRÉER UNE SESSION
  // ============================================================

  Future<int> demarrerInventaire({
    required int pointVenteId,
    int? utilisateurId,
  }) {
    return _repository.creerInventaire(
      pointVenteId: pointVenteId,
      utilisateurId: utilisateurId,
    );
  }

  // ============================================================
  // RÉCUPÉRER UNE SESSION EN COURS
  // ============================================================

  Future<Inventaire?> obtenirSessionEnCours({
    required int pointVenteId,
  }) {
    return _repository.obtenirInventaireEnCours(
      pointVenteId: pointVenteId,
    );
  }

  // ============================================================
  // RÉCUPÉRER UNE SESSION PAR SON ID
  // ============================================================

  Future<Inventaire?> obtenirSession(int inventaireId) {
    return _repository.obtenirInventaire(inventaireId);
  }

  // ============================================================
  // ENREGISTRER UN CODE SCANNÉ
  // ============================================================

  Future<void> enregistrerScan({
    required int inventaireId,
    required String code,
  }) async {
    final codeNettoye = code.trim();

    if (codeNettoye.isEmpty) {
      throw ArgumentError(
        'Veuillez scanner un code valide.',
      );
    }

    await _repository.ajouterScan(
      inventaireId: inventaireId,
      code: codeNettoye,
    );
  }

  // ============================================================
  // IMPORTER UN INVENTAIRE
  // ============================================================

  Future<int> importerInventaire({
    required int pointVenteId,
    int? utilisateurId,
    required List<dynamic> scansJson,
  }) async {
    if (scansJson.isEmpty) {
      throw FormatException(
        'Le fichier ne contient aucun code à importer.',
      );
    }

    final scans = <Map<String, dynamic>>[];

    for (final element in scansJson) {
      if (element is! Map) {
        throw FormatException(
          'Une ligne du fichier JSON est invalide.',
        );
      }

      final code = element['code'];
      final quantite = element['quantite'];

      if (code is! String || code.trim().isEmpty) {
        throw FormatException(
          'Un code du fichier JSON est vide ou invalide.',
        );
      }

      if (quantite is! int || quantite <= 0) {
        throw FormatException(
          'La quantité du code "$code" est invalide.',
        );
      }

      scans.add({
        'code': code.trim(),
        'quantite': quantite,
      });
    }

    return _repository.creerInventaireAvecScans(
      pointVenteId: pointVenteId,
      utilisateurId: utilisateurId,
      scans: scans,
    );
  }

  // ============================================================
  // PRÉPARER LES DONNÉES POUR L'EXPORT JSON
  // ============================================================

  Future<Map<String, dynamic>> exporterInventaire(
    int inventaireId,
  ) async {
    final inventaire =
        await _repository.obtenirInventaire(inventaireId);

    if (inventaire == null) {
      throw StateError('Inventaire introuvable.');
    }

    final lignes =
        await _repository.obtenirLignes(inventaireId);

    return {
      'format': formatJson,
      'version': versionJson,
      'date_export': DateTime.now().toIso8601String(),
      'scans': lignes.map((ligne) {
        return {
          'code': ligne.code,
          'quantite': ligne.quantite,
        };
      }).toList(),
    };
  }

  // ============================================================
  // ENVOYER L'INVENTAIRE À DJANGO
  // ============================================================

  Future<Map<String, dynamic>> validerInventaire({
    required int inventaireId,
    required int pointVenteId,
    required String typeInventaire,
  }) async {
    // Vérifier le type d'inventaire choisi.
    if (typeInventaire != 'total' &&
        typeInventaire != 'partiel') {
      throw ArgumentError(
        'Le type d’inventaire doit être total ou partiel.',
      );
    }

    // Vérifier que la session locale existe.
    final inventaire =
        await _repository.obtenirInventaire(inventaireId);

    if (inventaire == null) {
      throw StateError('Inventaire local introuvable.');
    }

    if (inventaire.statut != 'en_cours') {
      throw StateError(
        'Cet inventaire n’est plus en cours.',
      );
    }

    // Récupérer les codes regroupés et leurs quantités.
    final lignes =
        await _repository.obtenirLignes(inventaireId);

    if (lignes.isEmpty) {
      throw StateError(
        'Aucun code scanné à envoyer.',
      );
    }

    // Préparer les données des scans.
    final scans = lignes.map((ligne) {
      return <String, dynamic>{
        'code': ligne.code,
        'quantite': ligne.quantite,
      };
    }).toList();

    // Envoyer l'inventaire et son type à l'API Django.
    final resultat = await _apiClient.validerInventaire(
      pointVenteId: pointVenteId,
      scans: scans,
      typeInventaire: typeInventaire,
    );

    // Vérifier la réponse de Django.
    if (resultat['success'] == false) {
      throw StateError(
        resultat['message']?.toString() ??
            'Django a refusé la validation de l’inventaire.',
      );
    }

    // Clôturer localement uniquement après confirmation positive.
    await _repository.cloturerInventaire(inventaireId);

    return resultat;
  }

  // ============================================================
  // RÉCUPÉRER LES LIGNES REGROUPÉES
  // ============================================================

  Future<List<LigneInventaire>> obtenirLignes(
    int inventaireId,
  ) {
    return _repository.obtenirLignes(inventaireId);
  }

  // ============================================================
  // RÉCUPÉRER LES SCANS INDIVIDUELS
  // ============================================================

  Future<List<Map<String, dynamic>>> obtenirScans(
    int inventaireId,
  ) {
    return _repository.obtenirScans(inventaireId);
  }

  // ============================================================
  // SUPPRIMER UN SCAN
  // ============================================================

  Future<void> supprimerScan(int scanId) {
    return _repository.supprimerScan(scanId);
  }

  // ============================================================
  // COMPTER LES SCANS
  // ============================================================

  Future<int> compterScans(int inventaireId) {
    return _repository.compterScans(inventaireId);
  }

  // ============================================================
  // ANNULER UNE SESSION
  // ============================================================

  Future<void> annulerInventaire(int inventaireId) {
    return _repository.annulerInventaire(inventaireId);
  }
}
