class Commande {
  final int? id;

  final String idLocal;

  final int? idDjango;

  /// Utilisateur éventuellement associé à la commande.
  ///
  /// Pour une commande créée depuis la Caisse,
  /// cette valeur reste null.
  final int? userId;

  /// Utilisateur qui encaisse la commande.
  ///
  /// Pour une commande créée depuis la Caisse,
  /// c'est l'utilisateur actuellement connecté.
  final int? encaissePar;

  /// Gestionnaire de la commande.
  ///
  /// Pour une commande créée depuis la Caisse,
  /// cette valeur reste null pour le moment.
  final int? gestionnaireId;

  final String nom;

  final String telephone;

  final String? ville;

  final String? deplacement;

  final int montant;

  final int remise;

  final int livraison;

  final int total;

  final String payer;

  final String statutLocal;

  final String origine;

  /// Date et heure de création de la commande locale.
  final DateTime dateCreation;

  /// Date et heure de validation de la commande en caisse.
  ///
  /// Cette date est envoyée à Django lors de la synchronisation
  /// afin de conserver la date réelle de validation, même si
  /// la synchronisation intervient plus tard.
  final DateTime? dateValidation;

  final DateTime? dateUpdate;

  final String syncStatus;

  /// Date et heure de synchronisation avec Django.
  final DateTime? syncDate;

  final String? syncErreur;

  const Commande({
    this.id,
    required this.idLocal,
    this.idDjango,
    this.userId,
    this.encaissePar,
    this.gestionnaireId,
    required this.nom,
    required this.telephone,
    this.ville,
    this.deplacement,
    required this.montant,
    required this.remise,
    required this.livraison,
    required this.total,
    required this.payer,
    required this.statutLocal,
    required this.origine,
    required this.dateCreation,
    this.dateValidation,
    this.dateUpdate,
    required this.syncStatus,
    this.syncDate,
    this.syncErreur,
  });

  factory Commande.fromMap(
    Map<String, dynamic> map,
  ) {
    return Commande(
      id: map['id'] as int?,

      idLocal: map['id_local'] as String,

      idDjango: map['id_django'] as int?,

      userId: map['user_id'] as int?,

      encaissePar: map['encaisse_par'] as int?,

      gestionnaireId: map['gestionnaire_id'] as int?,

      nom: map['nom'] as String? ?? '',

      telephone: map['telephone'] as String? ?? '',

      ville: map['ville'] as String?,

      deplacement: map['deplacement'] as String?,

      montant: map['montant'] as int? ?? 0,

      remise: map['remise'] as int? ?? 0,

      livraison: map['livraison'] as int? ?? 0,

      total: map['total'] as int? ?? 0,

      payer: map['payer'] as String? ?? 'Non',

      statutLocal:
          map['statut_local'] as String? ?? 'Caisse',

      origine:
          map['origine'] as String? ?? 'Caisse',

      dateCreation: DateTime.parse(
        map['date_creation'].toString(),
      ),

      dateValidation: map['date_validation'] != null
          ? DateTime.tryParse(
              map['date_validation'].toString(),
            )
          : null,

      dateUpdate: map['date_update'] != null
          ? DateTime.tryParse(
              map['date_update'].toString(),
            )
          : null,

      syncStatus:
          map['sync_status'] as String? ?? 'pending',

      syncDate: map['sync_date'] != null
          ? DateTime.tryParse(
              map['sync_date'].toString(),
            )
          : null,

      syncErreur:
          map['sync_erreur'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,

      'id_local': idLocal,

      'id_django': idDjango,

      'user_id': userId,

      'encaisse_par': encaissePar,

      'gestionnaire_id': gestionnaireId,

      'nom': nom,

      'telephone': telephone,

      'ville': ville,

      'deplacement': deplacement,

      'montant': montant,

      'remise': remise,

      'livraison': livraison,

      'total': total,

      'payer': payer,

      'statut_local': statutLocal,

      'origine': origine,

      'date_creation':
          dateCreation.toIso8601String(),

      'date_validation':
          dateValidation?.toIso8601String(),

      'date_update':
          dateUpdate?.toIso8601String(),

      'sync_status': syncStatus,

      'sync_date':
          syncDate?.toIso8601String(),

      'sync_erreur': syncErreur,
    };
  }

  Commande copyWith({
    int? id,
    String? idLocal,
    int? idDjango,
    int? userId,
    int? encaissePar,
    int? gestionnaireId,
    String? nom,
    String? telephone,
    String? ville,
    String? deplacement,
    int? montant,
    int? remise,
    int? livraison,
    int? total,
    String? payer,
    String? statutLocal,
    String? origine,
    DateTime? dateCreation,
    DateTime? dateValidation,
    DateTime? dateUpdate,
    String? syncStatus,
    DateTime? syncDate,
    String? syncErreur,
  }) {
    return Commande(
      id: id ?? this.id,

      idLocal:
          idLocal ?? this.idLocal,

      idDjango:
          idDjango ?? this.idDjango,

      userId:
          userId ?? this.userId,

      encaissePar:
          encaissePar ?? this.encaissePar,

      gestionnaireId:
          gestionnaireId ?? this.gestionnaireId,

      nom:
          nom ?? this.nom,

      telephone:
          telephone ?? this.telephone,

      ville:
          ville ?? this.ville,

      deplacement:
          deplacement ?? this.deplacement,

      montant:
          montant ?? this.montant,

      remise:
          remise ?? this.remise,

      livraison:
          livraison ?? this.livraison,

      total:
          total ?? this.total,

      payer:
          payer ?? this.payer,

      statutLocal:
          statutLocal ?? this.statutLocal,

      origine:
          origine ?? this.origine,

      dateCreation:
          dateCreation ?? this.dateCreation,

      dateValidation:
          dateValidation ?? this.dateValidation,

      dateUpdate:
          dateUpdate ?? this.dateUpdate,

      syncStatus:
          syncStatus ?? this.syncStatus,

      syncDate:
          syncDate ?? this.syncDate,

      syncErreur:
          syncErreur ?? this.syncErreur,
    );
  }
}