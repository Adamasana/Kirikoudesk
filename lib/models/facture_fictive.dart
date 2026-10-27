class AchatFictif {
  final String produit;
  final String code;
  final double prixUnitaire;
  final int quantite;
  final int stock;
  final double marge;

  const AchatFictif({
    required this.produit,
    required this.code,
    required this.prixUnitaire,
    required this.quantite,
    required this.stock,
    required this.marge,
  });

  double get montant => prixUnitaire * quantite;

  AchatFictif copyWith({
    String? produit,
    String? code,
    double? prixUnitaire,
    int? quantite,
    int? stock,
    double? marge,
  }) {
    return AchatFictif(
      produit: produit ?? this.produit,
      code: code ?? this.code,
      prixUnitaire: prixUnitaire ?? this.prixUnitaire,
      quantite: quantite ?? this.quantite,
      stock: stock ?? this.stock,
      marge: marge ?? this.marge,
    );
  }
}

class FactureFictive {
  final int id;
  final String numero;
  final String nom;
  final String telephone;
  final double montant;
  final double remise;
  final String boutique;
  final String statut;
  final double marge;
  final String dateCreation;
  final List<AchatFictif> produits;

  const FactureFictive({
    required this.id,
    required this.numero,
    required this.nom,
    required this.telephone,
    required this.montant,
    required this.remise,
    required this.boutique,
    required this.statut,
    required this.marge,
    required this.dateCreation,
    required this.produits,
  });

  double get total => montant - remise;

  FactureFictive copyWith({
    int? id,
    String? numero,
    String? nom,
    String? telephone,
    double? montant,
    double? remise,
    String? boutique,
    String? statut,
    double? marge,
    String? dateCreation,
    List<AchatFictif>? produits,
  }) {
    return FactureFictive(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      montant: montant ?? this.montant,
      remise: remise ?? this.remise,
      boutique: boutique ?? this.boutique,
      statut: statut ?? this.statut,
      marge: marge ?? this.marge,
      dateCreation: dateCreation ?? this.dateCreation,
      produits: produits ?? this.produits,
    );
  }
}