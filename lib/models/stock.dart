class Stock {
  final int id;
  final int pointDeVenteId;
  final int? sousProduitId;
  final int quantite;

  const Stock({
    required this.id,
    required this.pointDeVenteId,
    this.sousProduitId,
    required this.quantite,
  });

  factory Stock.fromMap(Map<String, dynamic> map) {
    return Stock(
      id: map['id'] as int,
      pointDeVenteId: map['point_de_vente_id'] as int,
      sousProduitId: map['sous_produit_id'] as int?,
      quantite: map['quantite'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'point_de_vente_id': pointDeVenteId,
      'sous_produit_id': sousProduitId,
      'quantite': quantite,
    };
  }

  Stock copyWith({
    int? id,
    int? pointDeVenteId,
    int? sousProduitId,
    int? quantite,
  }) {
    return Stock(
      id: id ?? this.id,
      pointDeVenteId: pointDeVenteId ?? this.pointDeVenteId,
      sousProduitId: sousProduitId ?? this.sousProduitId,
      quantite: quantite ?? this.quantite,
    );
  }
}