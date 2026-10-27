import 'package:shared_preferences/shared_preferences.dart';

class Session {
  /// ID du User Django.
  final int userId;

  /// ID local de la table utilisateur SQLite.
  final int utilisateurId;

  final String token;

  final String numero;

  final String username;
  final String email;

  final String prenom;
  final String nom;

  final String telephone;
  final String adresse;
  final String statut;
  final String post;

  final double points;

  final int? boutiqueId;
  final String boutiqueNom;
  final String boutiqueIdentifiant;

  final int? pointVenteId;
  final String ville;
  final String quartier;

  const Session({
    required this.userId,
    required this.utilisateurId,
    required this.token,
    required this.numero,
    required this.username,
    required this.email,
    required this.prenom,
    required this.nom,
    required this.telephone,
    required this.adresse,
    required this.statut,
    required this.post,
    required this.points,
    required this.boutiqueId,
    required this.boutiqueNom,
    required this.boutiqueIdentifiant,
    required this.pointVenteId,
    required this.ville,
    required this.quartier,
  });

  /// Construit une session à partir de la réponse Django.
  ///
  /// utilisateurIdLocal est l'ID de la ligne utilisateur
  /// créée dans SQLite après le login.
  factory Session.fromLoginResponse(
    String token,
    Map<String, dynamic> user, {
    required int utilisateurIdLocal,
  }) {
    final boutique = user['boutique'] is Map
        ? Map<String, dynamic>.from(
            user['boutique'] as Map,
          )
        : <String, dynamic>{};

    final pointVente =
        boutique['point_de_vente'] is Map
            ? Map<String, dynamic>.from(
                boutique['point_de_vente'] as Map,
              )
            : <String, dynamic>{};

    return Session(
      userId: _toInt(
        user['id'],
      ),
      utilisateurId: utilisateurIdLocal,
      token: token,
      numero: user['numero']?.toString() ?? '',
      username:
          user['username']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      prenom:
          user['first_name']?.toString() ?? '',
      nom:
          user['last_name']?.toString() ?? '',
      telephone:
          user['telephone']?.toString() ?? '',
      adresse:
          user['adresse']?.toString() ?? '',
      statut:
          user['statut']?.toString() ?? '',
      post:
          user['post']?.toString() ?? '',
      points: _toDouble(
        user['points'],
      ),
      boutiqueId: _toNullableInt(
        boutique['id'],
      ),
      boutiqueNom:
          boutique['nom']?.toString() ?? '',
      boutiqueIdentifiant:
          boutique['identifiant']?.toString() ?? '',
      pointVenteId: _toNullableInt(
        pointVente['id'],
      ),
      ville:
          pointVente['ville']?.toString() ?? '',
      quartier:
          pointVente['quartier']?.toString() ?? '',
    );
  }

  static Future<Session?> fromPreferences() async {
    final preferences =
        await SharedPreferences.getInstance();

    final token =
        preferences.getString('auth_token');

    if (token == null || token.isEmpty) {
      return null;
    }

    return Session(
      userId:
          preferences.getInt('auth_django_user_id') ??
              preferences.getInt('auth_user_id') ??
              0,

      utilisateurId:
          preferences.getInt(
                'auth_utilisateur_id',
              ) ??
              0,

      token: token,

      numero:
          preferences.getString(
                'auth_numero',
              ) ??
              '',

      username:
          preferences.getString(
                'auth_username',
              ) ??
              '',

      email:
          preferences.getString(
                'auth_email',
              ) ??
              '',

      prenom:
          preferences.getString(
                'auth_first_name',
              ) ??
              '',

      nom:
          preferences.getString(
                'auth_last_name',
              ) ??
              '',

      telephone:
          preferences.getString(
                'auth_telephone',
              ) ??
              '',

      adresse:
          preferences.getString(
                'auth_adresse',
              ) ??
              '',

      statut:
          preferences.getString(
                'auth_statut',
              ) ??
              '',

      post:
          preferences.getString(
                'auth_post',
              ) ??
              '',

      points:
          preferences.getDouble(
                'auth_points',
              ) ??
              0,

      boutiqueId:
          preferences.getInt(
        'auth_boutique_id',
      ),

      boutiqueNom:
          preferences.getString(
                'auth_boutique_nom',
              ) ??
              '',

      boutiqueIdentifiant:
          preferences.getString(
                'auth_boutique_identifiant',
              ) ??
              '',

      pointVenteId:
          preferences.getInt(
        'auth_point_vente_id',
      ),

      ville:
          preferences.getString(
                'auth_ville',
              ) ??
              '',

      quartier:
          preferences.getString(
                'auth_quartier',
              ) ??
              '',
    );
  }

  Future<void> sauvegarder() async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(
      'auth_token',
      token,
    );

    /// ID Django.
    await preferences.setInt(
      'auth_django_user_id',
      userId,
    );

    /// ID local SQLite.
    await preferences.setInt(
      'auth_utilisateur_id',
      utilisateurId,
    );

    await preferences.setString(
      'auth_numero',
      numero,
    );

    await preferences.setString(
      'auth_username',
      username,
    );

    await preferences.setString(
      'auth_email',
      email,
    );

    await preferences.setString(
      'auth_first_name',
      prenom,
    );

    await preferences.setString(
      'auth_last_name',
      nom,
    );

    await preferences.setString(
      'auth_telephone',
      telephone,
    );

    await preferences.setString(
      'auth_adresse',
      adresse,
    );

    await preferences.setString(
      'auth_statut',
      statut,
    );

    await preferences.setString(
      'auth_post',
      post,
    );

    await preferences.setDouble(
      'auth_points',
      points,
    );

    if (boutiqueId != null) {
      await preferences.setInt(
        'auth_boutique_id',
        boutiqueId!,
      );
    } else {
      await preferences.remove(
        'auth_boutique_id',
      );
    }

    await preferences.setString(
      'auth_boutique_nom',
      boutiqueNom,
    );

    await preferences.setString(
      'auth_boutique_identifiant',
      boutiqueIdentifiant,
    );

    if (pointVenteId != null) {
      await preferences.setInt(
        'auth_point_vente_id',
        pointVenteId!,
      );
    } else {
      await preferences.remove(
        'auth_point_vente_id',
      );
    }

    await preferences.setString(
      'auth_ville',
      ville,
    );

    await preferences.setString(
      'auth_quartier',
      quartier,
    );
  }

  static int _toInt(
    dynamic valeur,
  ) {
    if (valeur is int) {
      return valeur;
    }

    return int.tryParse(
          valeur?.toString() ?? '',
        ) ??
        0;
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

  static double _toDouble(
    dynamic valeur,
  ) {
    if (valeur is num) {
      return valeur.toDouble();
    }

    return double.tryParse(
          valeur?.toString() ?? '',
        ) ??
        0;
  }
}