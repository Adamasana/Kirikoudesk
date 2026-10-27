import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // ============================================================
  // URL DE L'API
  // ============================================================
  //
  // DEVELOPPEMENT :
  // http://127.0.0.1:8000/api/desktop
  //
  // PRODUCTION :
  // https://kirikoubf.fondationaic.org/api/desktop
  //
  // En production, l'URL est fournie lors de la compilation
  // avec :
  //
  // flutter build windows --release
  // --dart-define=API_BASE_URL=https://kirikoubf.fondationaic.org/api/desktop
  //
  // Si API_BASE_URL n'est pas fourni, l'application utilise
  // automatiquement l'URL locale de développement.
  //
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://kirikoubf.fondationaic.org/api/desktop',
  );

  final http.Client _client;

  ApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ============================================================
  // CONSTRUIRE URL
  // ============================================================

  Uri _url(String chemin) {
    return Uri.parse('$baseUrl$chemin');
  }

  // ============================================================
  // OBTENIR TOKEN
  // ============================================================

  Future<String?> _obtenirToken() async {
    final preferences =
        await SharedPreferences.getInstance();

    final token =
        preferences.getString('auth_token');

    if (token == null || token.isEmpty) {
      return null;
    }

    return token;
  }

  // ============================================================
  // HEADERS
  // ============================================================

  Future<Map<String, String>> _headers(
    String? token,
  ) async {
    final tokenEffectif =
        token ?? await _obtenirToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (tokenEffectif != null &&
        tokenEffectif.isNotEmpty) {
      headers['Authorization'] =
          'Token $tokenEffectif';
    }

    return headers;
  }

  // ============================================================
  // GET
  // ============================================================

  Future<Map<String, dynamic>> get(
    String chemin, {
    String? token,
  }) async {
    final url = _url(chemin);

    final reponse = await _client.get(
      url,
      headers: await _headers(token),
    );

    return _traiterReponse(reponse);
  }

  // ============================================================
  // POST
  // ============================================================

  Future<Map<String, dynamic>> post(
    String chemin, {
    Map<String, dynamic>? donnees,
    String? token,
  }) async {
    final url = _url(chemin);

    final headers = await _headers(token);

    final body = donnees == null
        ? null
        : jsonEncode(donnees);

    print('');
    print('============================================================');
    print('DEBUG API CLIENT POST');
    print('============================================================');
    print('URL     : $url');
    print('Headers : $headers');
    print('Donnees : $donnees');
    print('Body    : $body');
    print('============================================================');
    print('');

    final reponse = await _client.post(
      url,
      headers: headers,
      body: body,
    );

    return _traiterReponse(reponse);
  }

  // ============================================================
  // TRAITER REPONSE
  // ============================================================

  Map<String, dynamic> _traiterReponse(
    http.Response reponse,
  ) {
    dynamic donnees;

    // ----------------------------------------------------------
    // DECODER LE JSON
    // ----------------------------------------------------------

    if (reponse.body.isNotEmpty) {
      try {
        donnees = jsonDecode(
          reponse.body,
        );
      } catch (_) {
        throw ApiException(
          'La réponse du serveur n’est pas un JSON valide.\n'
          'Réponse reçue : ${reponse.body}',
          reponse.statusCode,
          data: null,
        );
      }
    }

    // ----------------------------------------------------------
    // REPONSE REUSSIE
    // ----------------------------------------------------------

    if (reponse.statusCode >= 200 &&
        reponse.statusCode < 300) {
      if (donnees is Map<String, dynamic>) {
        return donnees;
      }

      return <String, dynamic>{
        'success': true,
        'data': donnees,
      };
    }

    // ----------------------------------------------------------
    // REPONSE EN ERREUR
    // ----------------------------------------------------------

    String message =
        'Erreur serveur (${reponse.statusCode}).';

    if (donnees is Map<String, dynamic>) {
      final erreur =
          donnees['detail'] ??
          donnees['error'] ??
          donnees['message'] ??
          donnees['errors'];

      if (erreur != null) {
        if (erreur is Map ||
            erreur is List) {
          try {
            const encoder =
                JsonEncoder.withIndent('  ');

            message =
                encoder.convert(erreur);
          } catch (_) {
            message =
                erreur.toString();
          }
        } else {
          message =
              erreur.toString();
        }
      } else {
        try {
          const encoder =
              JsonEncoder.withIndent('  ');

          message =
              encoder.convert(donnees);
        } catch (_) {
          message =
              donnees.toString();
        }
      }
    } else if (reponse.body.isNotEmpty) {
      message =
          reponse.body;
    }

    // ----------------------------------------------------------
    // IMPORTANT :
    //
    // On conserve toute la réponse JSON du serveur.
    //
    // Exemple :
    //
    // {
    //   "success": false,
    //   "code": "stock_insuffisant",
    //   "identifiant": "ch001-xl-vert",
    //   "stock_disponible": 0,
    //   "quantite_demandee": 1,
    //   "stock_restant": 0
    // }
    //
    // Le service de synchronisation peut donc récupérer
    // ces informations via ApiException.data.
    // ----------------------------------------------------------

    throw ApiException(
      message,
      reponse.statusCode,
      data: donnees,
    );
  }

  // ============================================================
  // FERMER
  // ============================================================

  void fermer() {
    _client.close();
  }
}

// ================================================================
// API EXCEPTION
// ================================================================

class ApiException implements Exception {
  final String message;
  final int statusCode;

  /// Réponse complète du serveur.
  ///
  /// Permet notamment au service de synchronisation
  /// de lire :
  ///
  ///     code
  ///     identifiant
  ///     stock_disponible
  ///     stock_restant
  ///
  /// en cas d'erreur serveur.
  final dynamic data;

  const ApiException(
    this.message,
    this.statusCode, {
    this.data,
  });

  @override
  String toString() {
    return 'ApiException($statusCode): $message';
  }
}
