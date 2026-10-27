import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';
import '../repositories/utilisateur_repository.dart';
import '../services/api/api_client.dart';
import '../services/synchronisation/donnees_reference_service.dart';

class AuthentificationRepository {
  final ApiClient _apiClient;

  final UtilisateurRepository _utilisateurRepository =
      const UtilisateurRepository();

  AuthentificationRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  // ============================================================
  // CONNEXION
  // ============================================================

  Future<Session> connecter({
    required String email,
    required String motDePasse,
  }) async {
    print('');
    print('============================================================');
    print('DÉBUT CONNEXION FLUTTER');
    print('============================================================');
    print('Email : ${email.trim()}');
    print('============================================================');

    // ----------------------------------------------------------
    // 1. APPEL API DJANGO
    // ----------------------------------------------------------

    print('');
    print('------------- APPEL API DJANGO -------------');
    print('POST /login/');
    print('---------------------------------------------');

    final reponse = await _apiClient.post(
      '/login/',
      donnees: {
        'email': email.trim(),
        'password': motDePasse,
      },
    );

    // ----------------------------------------------------------
    // 2. RÉPONSE DU SERVEUR
    // ----------------------------------------------------------

    print('');
    print('================ LOGIN FLUTTER ================');
    print('Réponse complète : $reponse');
    print('success : ${reponse['success']}');
    print('token  : ${reponse['token']}');
    print('user   : ${reponse['user']}');
    print('================================================');

    // ----------------------------------------------------------
    // 3. VÉRIFICATION SUCCESS
    // ----------------------------------------------------------

    if (reponse['success'] != true) {
      print('');
      print('ERREUR : LE SERVEUR A INDIQUÉ QUE LA CONNEXION A ÉCHOUÉ.');
      print('Message : ${reponse['message']}');

      throw AuthentificationException(
        reponse['message']?.toString() ??
            'La connexion a échoué.',
      );
    }

    print('');
    print('OK : CONNEXION DJANGO RÉUSSIE.');

    // ----------------------------------------------------------
    // 4. RÉCUPÉRATION DU TOKEN
    // ----------------------------------------------------------

    final token = reponse['token']?.toString();

    print('');
    print('------------- TOKEN -------------');
    print(
      'Token présent : '
      '${token != null && token.isNotEmpty}',
    );
    print('---------------------------------');

    if (token == null || token.isEmpty) {
      print('ERREUR : TOKEN ABSENT.');

      throw const AuthentificationException(
        'Le serveur n’a pas retourné de token.',
      );
    }

    // ----------------------------------------------------------
    // 5. VÉRIFICATION DES DONNÉES UTILISATEUR
    // ----------------------------------------------------------

    print('');
    print('------------- UTILISATEUR DJANGO -------------');
    print('Type user : ${reponse['user'].runtimeType}');
    print('User : ${reponse['user']}');
    print('-----------------------------------------------');

    if (reponse['user'] is! Map) {
      print(
        'ERREUR : LES INFORMATIONS UTILISATEUR '
        'SONT ABSENTES.',
      );

      throw const AuthentificationException(
        'Les informations de l’utilisateur sont absentes.',
      );
    }

    final user = Map<String, dynamic>.from(
      reponse['user'] as Map,
    );

    // ----------------------------------------------------------
    // 6. ID DJANGO
    // ----------------------------------------------------------

    final userId = _obtenirUserId(user);

    print('');
    print('------------- ID DJANGO -------------');
    print('userId : $userId');
    print('-------------------------------------');

    if (userId == null || userId <= 0) {
      print('ERREUR : ID DJANGO INVALIDE.');

      throw const AuthentificationException(
        'L’identifiant du compte utilisateur est absent '
        'de la réponse du serveur.',
      );
    }

    // ----------------------------------------------------------
    // 7. BOUTIQUE
    // ----------------------------------------------------------

    final boutique = user['boutique'] is Map
        ? Map<String, dynamic>.from(
            user['boutique'] as Map,
          )
        : <String, dynamic>{};

    final boutiqueId = _toNullableInt(
      boutique['id'],
    );

    print('');
    print('------------- BOUTIQUE -------------');
    print('Boutique : $boutique');
    print('Boutique ID : $boutiqueId');
    print('------------------------------------');

    // ----------------------------------------------------------
    // 8. DONNÉES UTILISATEUR
    // ----------------------------------------------------------

    print('');
    print('============= AVANT SYNCHRONISATION =============');
    print('userId      : $userId');
    print('boutique    : $boutique');
    print('boutiqueId  : $boutiqueId');
    print('numero      : ${user['numero']}');
    print('username    : ${user['username']}');
    print('email       : ${user['email']}');

    // Django utilise first_name / last_name.
    print('first_name  : ${user['first_name']}');
    print('last_name   : ${user['last_name']}');

    print('telephone   : ${user['telephone']}');
    print('adresse     : ${user['adresse']}');
    print('statut      : ${user['statut']}');
    print('post        : ${user['post']}');
    print('points      : ${user['points']}');
    print('==================================================');

    // ----------------------------------------------------------
    // 9. VÉRIFICATION BOUTIQUE
    // ----------------------------------------------------------

    if (boutiqueId == null || boutiqueId <= 0) {
      print('');
      print(
        'ERREUR : L’UTILISATEUR DJANGO N’A PAS DE BOUTIQUE VALIDE.',
      );

      throw const AuthentificationException(
        'La boutique associée à cet utilisateur est absente '
        'ou invalide.',
      );
    }

    // ----------------------------------------------------------
    // 10. SYNCHRONISATION INITIALE DES RÉFÉRENTIELS
    // ----------------------------------------------------------
    //
    // IMPORTANT :
    //
    // Nous faisons cette synchronisation AVANT d'insérer
    // l'utilisateur dans SQLite.
    //
    // Pourquoi ?
    //
    // utilisateur.boutique_id possède une clé étrangère :
    //
    // utilisateur.boutique_id
    //             ↓
    //       equipe.id
    //
    // Django nous renvoie par exemple :
    //
    // boutique.id = 2
    //
    // Mais si equipe.id = 2 n'existe pas encore localement,
    // SQLite refuse :
    //
    // FOREIGN KEY constraint failed
    //
    // Nous synchronisons donc d'abord :
    //
    // points de vente
    //       ↓
    // équipes
    //       ↓
    // produits
    //       ↓
    // sous-produits
    //       ↓
    // stocks
    //
    // Le token fraîchement obtenu est transmis directement
    // au service car il n'est pas encore forcément présent
    // dans SharedPreferences.
    //
    // ----------------------------------------------------------

    print('');
    print('############################################################');
    print('SYNCHRONISATION INITIALE DES RÉFÉRENTIELS');
    print('############################################################');

    print('');
    print('Token transmis directement au service :');
    print(
      token.isNotEmpty,
    );

    final donneesReferenceService =
        DonneesReferenceService();

    try {
      await donneesReferenceService.synchroniser(
        token: token,
      );

      print('');
      print(
        'OK : SYNCHRONISATION INITIALE DES RÉFÉRENTIELS '
        'TERMINÉE.',
      );

      print('');
      print(
        '------------- VÉRIFICATION DONNÉES LOCALES -------------',
      );

      await donneesReferenceService.afficherDonneesLocales();

      print('');
      print(
        'OK : LES RÉFÉRENTIELS SONT DISPONIBLES LOCALEMENT.',
      );
    } catch (e, stackTrace) {
      print('');
      print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      print('ERREUR SYNCHRONISATION INITIALE');
      print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

      print('Erreur : $e');

      print('');
      print('StackTrace :');
      print(stackTrace);

      print('');
      print(
        'L’utilisateur ne sera PAS enregistré dans SQLite '
        'car les référentiels n’ont pas pu être synchronisés.',
      );

      print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

      donneesReferenceService.fermer();

      throw AuthentificationException(
        'La connexion a réussi, mais la synchronisation '
        'initiale des données a échoué.\n\n'
        '$e',
      );
    }

    donneesReferenceService.fermer();

    print('');
    print('############################################################');
    print('FIN SYNCHRONISATION INITIALE DES RÉFÉRENTIELS');
    print('############################################################');

    // ----------------------------------------------------------
    // 11. ENREGISTREMENT LOCAL SQLITE
    // ----------------------------------------------------------

    print('');
    print('============================================================');
    print('DÉBUT ENREGISTREMENT UTILISATEUR SQLITE');
    print('============================================================');

    print('');
    print('Vérification des données avant insertion :');
    print('userId     : $userId');
    print('boutiqueId : $boutiqueId');
    print('numero     : ${user['numero']}');

    final utilisateurLocal =
        await _utilisateurRepository.enregistrerCompteDjango(
      userId: userId,

      boutiqueId: boutiqueId,

      telephone:
          user['telephone']?.toString() ??
              '',

      adresse:
          user['adresse']?.toString() ??
              '',

      statut:
          user['statut']?.toString() ??
              '',

      post:
          user['post']?.toString() ??
              '',

      numero:
          user['numero']?.toString(),
    );

    // ----------------------------------------------------------
    // 12. SQLITE OK
    // ----------------------------------------------------------

    print('');
    print('============= SQLITE OK =============');
    print('ID LOCAL       : ${utilisateurLocal.id}');
    print('USER ID DJANGO : ${utilisateurLocal.userId}');
    print('NUMERO         : ${utilisateurLocal.numero}');
    print('BOUTIQUE ID    : ${utilisateurLocal.boutiqueId}');
    print('TELEPHONE      : ${utilisateurLocal.telephone}');
    print('ADRESSE        : ${utilisateurLocal.adresse}');
    print('STATUT         : ${utilisateurLocal.statut}');
    print('POST           : ${utilisateurLocal.post}');
    print('======================================');

    // ----------------------------------------------------------
    // 13. CRÉATION DE LA SESSION
    // ----------------------------------------------------------

    print('');
    print('============================================================');
    print('CRÉATION DE LA SESSION');
    print('============================================================');

    final session = Session.fromLoginResponse(
      token,
      user,
      utilisateurIdLocal: utilisateurLocal.id,
    );

    print('');
    print('============= SESSION CRÉÉE =============');
    print('User ID Django : ${session.userId}');
    print('ID local       : ${session.utilisateurId}');
    print('Email          : ${session.email}');
    print('Username       : ${session.username}');
    print('Numero         : ${session.numero}');
    print('Prenom         : ${session.prenom}');
    print('Nom            : ${session.nom}');
    print('Boutique ID    : ${session.boutiqueId}');
    print('Point vente ID : ${session.pointVenteId}');
    print('Token présent  : ${session.token.isNotEmpty}');
    print('==========================================');

    // ----------------------------------------------------------
    // 14. SAUVEGARDE DE LA SESSION
    // ----------------------------------------------------------

    print('');
    print('------------- SAUVEGARDE SESSION -------------');

    await session.sauvegarder();

    print('SESSION SAUVEGARDÉE AVEC SUCCÈS.');
    print('----------------------------------------------');

    // ----------------------------------------------------------
    // 15. FIN CONNEXION
    // ----------------------------------------------------------

    print('');
    print('============================================================');
    print('CONNEXION FLUTTER TERMINÉE AVEC SUCCÈS');
    print('============================================================');
    print('');

    return session;
  }

  // ============================================================
  // SESSION
  // ============================================================

  Future<Session?> obtenirSession() async {
    print('');
    print('------------- VÉRIFICATION SESSION -------------');

    final session = await Session.fromPreferences();

    if (session == null) {
      print('Aucune session locale trouvée.');
    } else {
      print('Session locale trouvée.');
      print('User ID Django : ${session.userId}');
      print('ID local       : ${session.utilisateurId}');
      print('Email          : ${session.email}');
      print('Username       : ${session.username}');
      print('Numero         : ${session.numero}');
      print('Prenom         : ${session.prenom}');
      print('Nom            : ${session.nom}');
      print('Boutique ID    : ${session.boutiqueId}');
      print('Point vente ID : ${session.pointVenteId}');
      print(
        'Token présent  : '
        '${session.token.isNotEmpty}',
      );
    }

    print('------------------------------------------------');

    return session;
  }

  // ============================================================
  // TOKEN
  // ============================================================

  Future<String?> obtenirToken() async {
    final session = await obtenirSession();

    return session?.token;
  }

  // ============================================================
  // ID DJANGO
  // ============================================================

  /// Retourne l'ID Django.
  Future<int?> obtenirUserId() async {
    final session = await obtenirSession();

    return session?.userId;
  }

  // ============================================================
  // ID LOCAL SQLITE
  // ============================================================

  /// Retourne l'ID local SQLite.
  Future<int?> obtenirUtilisateurId() async {
    final session = await obtenirSession();

    return session?.utilisateurId;
  }

  // ============================================================
  // ÉTAT CONNEXION
  // ============================================================

  Future<bool> estConnecte() async {
    final session = await obtenirSession();

    return session != null &&
        session.token.isNotEmpty;
  }

  // ============================================================
  // DÉCONNEXION
  // ============================================================

  Future<void> deconnecter() async {
    print('');
    print('============================================================');
    print('DÉCONNEXION');
    print('============================================================');

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.remove(
      'auth_token',
    );

    await preferences.remove(
      'auth_user_id',
    );

    await preferences.remove(
      'auth_django_user_id',
    );

    await preferences.remove(
      'auth_utilisateur_id',
    );

    await preferences.remove(
      'auth_numero',
    );

    await preferences.remove(
      'auth_username',
    );

    await preferences.remove(
      'auth_email',
    );

    await preferences.remove(
      'auth_first_name',
    );

    await preferences.remove(
      'auth_last_name',
    );

    await preferences.remove(
      'auth_telephone',
    );

    await preferences.remove(
      'auth_adresse',
    );

    await preferences.remove(
      'auth_statut',
    );

    await preferences.remove(
      'auth_post',
    );

    await preferences.remove(
      'auth_points',
    );

    await preferences.remove(
      'auth_boutique_id',
    );

    await preferences.remove(
      'auth_boutique_nom',
    );

    await preferences.remove(
      'auth_boutique_identifiant',
    );

    await preferences.remove(
      'auth_point_vente_id',
    );

    await preferences.remove(
      'auth_ville',
    );

    await preferences.remove(
      'auth_quartier',
    );

    print('Session locale supprimée.');
    print('============================================================');
    print('');
  }

  // ============================================================
  // FERMETURE API CLIENT
  // ============================================================

  void fermer() {
    _apiClient.fermer();
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================

  static int? _obtenirUserId(
    Map<String, dynamic> user,
  ) {
    final valeur = user['id'];

    if (valeur is int) {
      return valeur;
    }

    final resultat = int.tryParse(
      valeur?.toString() ?? '',
    );

    return resultat;
  }

  static int? _toNullableInt(
    dynamic valeur,
  ) {
    if (valeur == null) {
      return null;
    }

    if (valeur is int) {
      return valeur;
    }

    return int.tryParse(
      valeur.toString(),
    );
  }
}

// ============================================================
// EXCEPTION AUTHENTIFICATION
// ============================================================

class AuthentificationException
    implements Exception {
  final String message;

  const AuthentificationException(
    this.message,
  );

  @override
  String toString() {
    return 'AuthentificationException: $message';
  }
}