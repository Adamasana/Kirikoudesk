class Achat {
  final int id;
  final int? articleId;
  final String identifiant;
  final String produit;
  final String couleur;
  final String pointure;
  final int quantite;
  final int prix;
  final int montant;
  final String statut;
  final DateTime? date;

  const Achat({
    required this.id,
    this.articleId,
    required this.identifiant,
    required this.produit,
    required this.couleur,
    required this.pointure,
    required this.quantite,
    required this.prix,
    required this.montant,
    required this.statut,
    this.date,
  });

  factory Achat.fromMap(
    Map<String, dynamic> map,
  ) {
    return Achat(
      id: _convertirEnInt(
            map['id'],
          ) ??
          0,
      articleId: _convertirEnInt(
        map['article_id'],
      ),
      identifiant:
          map['identifiant']?.toString() ?? '',
      produit:
          map['produit']?.toString() ?? '',
      couleur:
          map['couleur']?.toString() ?? '',
      pointure:
          map['pointure']?.toString() ?? '',
      quantite:
          _convertirEnInt(
                map['quantite'],
              ) ??
              0,
      prix:
          _convertirEnInt(
                map['prix'],
              ) ??
              0,
      montant:
          _convertirEnInt(
                map['montant'],
              ) ??
              0,
      statut:
          map['statut']?.toString() ?? '',
      date: _convertirDate(
        map['date'],
      ),
    );
  }

  Achat copyWith({
    int? id,
    int? articleId,
    String? identifiant,
    String? produit,
    String? couleur,
    String? pointure,
    int? quantite,
    int? prix,
    int? montant,
    String? statut,
    DateTime? date,
  }) {
    return Achat(
      id: id ?? this.id,
      articleId: articleId ?? this.articleId,
      identifiant:
          identifiant ?? this.identifiant,
      produit:
          produit ?? this.produit,
      couleur:
          couleur ?? this.couleur,
      pointure:
          pointure ?? this.pointure,
      quantite:
          quantite ?? this.quantite,
      prix:
          prix ?? this.prix,
      montant:
          montant ?? this.montant,
      statut:
          statut ?? this.statut,
      date:
          date ?? this.date,
    );
  }
}

class Facture {
  final int id;

  /// ID / PK de la commande Django.
  final int? idDjango;

  final String nom;
  final String telephone;
  final String? ville;
  final String? deplacement;

  final int montant;
  final int remise;
  final int livraison;
  final int total;

  final String payer;
  final String statut;
  final String origine;

  /// Date réelle de validation de la facture.
  ///
  /// Côté local, elle correspond à `date_validation`.
  /// Côté Django, elle correspond à `Commande.date`.
  final DateTime? date;

  /// Date de création de la commande locale.
  final DateTime dateCreation;

  final DateTime? datePaiement;
  final DateTime? dateConfirmation;
  final DateTime? dateUpdate;

  final List<Achat> produits;

  const Facture({
    required this.id,
    this.idDjango,
    required this.nom,
    required this.telephone,
    this.ville,
    this.deplacement,
    required this.montant,
    required this.remise,
    required this.livraison,
    required this.total,
    required this.payer,
    required this.statut,
    required this.origine,
    this.date,
    required this.dateCreation,
    this.datePaiement,
    this.dateConfirmation,
    this.dateUpdate,
    required this.produits,
  });

  factory Facture.fromMap(
    Map<String, dynamic> map,
  ) {
    final produitsMap =
        map['produits'] as List<dynamic>? ?? [];

    return Facture(
      id: _convertirEnInt(
            map['id'],
          ) ??
          0,

      idDjango: _convertirEnInt(
        map['id_django'],
      ),

      nom:
          map['nom']?.toString() ?? '',

      telephone:
          map['telephone']?.toString() ?? '',

      ville:
          map['ville']?.toString(),

      deplacement:
          map['deplacement']?.toString(),

      montant:
          _convertirEnInt(
                map['montant'],
              ) ??
              0,

      remise:
          _convertirEnInt(
                map['remise'],
              ) ??
              0,

      livraison:
          _convertirEnInt(
                map['livraison'],
              ) ??
              0,

      total:
          _convertirEnInt(
                map['total'],
              ) ??
              0,

      payer:
          map['payer']?.toString() ?? 'Non',

      statut:
          map['statut']?.toString() ?? 'Facture',

      origine:
          map['origine']?.toString() ?? 'Caisse',

      // Date réelle de la facture.
      date: _convertirDate(
        map['date'],
      ),

      dateCreation:
          _convertirDate(
            map['date_creation'],
          ) ??
          DateTime.now(),

      datePaiement:
          _convertirDate(
            map['date_paiement'],
          ),

      dateConfirmation:
          _convertirDate(
            map['date_confirmation'],
          ),

      dateUpdate:
          _convertirDate(
            map['date_update'],
          ),

      produits: produitsMap
          .whereType<Map<String, dynamic>>()
          .map(Achat.fromMap)
          .toList(),
    );
  }

  int get nombreProduits =>
      produits.length;

  Facture copyWith({
    int? id,
    int? idDjango,
    String? nom,
    String? telephone,
    String? ville,
    String? deplacement,
    int? montant,
    int? remise,
    int? livraison,
    int? total,
    String? payer,
    String? statut,
    String? origine,
    DateTime? date,
    DateTime? dateCreation,
    DateTime? datePaiement,
    DateTime? dateConfirmation,
    DateTime? dateUpdate,
    List<Achat>? produits,
  }) {
    return Facture(
      id:
          id ?? this.id,

      idDjango:
          idDjango ?? this.idDjango,

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

      statut:
          statut ?? this.statut,

      origine:
          origine ?? this.origine,

      date:
          date ?? this.date,

      dateCreation:
          dateCreation ?? this.dateCreation,

      datePaiement:
          datePaiement ?? this.datePaiement,

      dateConfirmation:
          dateConfirmation ??
          this.dateConfirmation,

      dateUpdate:
          dateUpdate ?? this.dateUpdate,

      produits:
          produits ?? this.produits,
    );
  }
}

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

DateTime? _convertirDate(
  dynamic valeur,
) {
  if (valeur == null) {
    return null;
  }

  final texte =
      valeur.toString().trim();

  if (texte.isEmpty) {
    return null;
  }

  return DateTime.tryParse(
    texte,
  );
}