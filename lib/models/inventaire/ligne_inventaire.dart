
class LigneInventaire {
  final int? id;
  final int inventaireId;
  final String code;
  final int quantite;

  const LigneInventaire({
    this.id,
    required this.inventaireId,
    required this.code,
    this.quantite = 0,
  });

  factory LigneInventaire.fromMap(Map<String, dynamic> map) {
    return LigneInventaire(
      id: map['id'] as int?,
      inventaireId: map['inventaire_id'] as int,
      code: map['code'] as String,
      quantite: map['quantite'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inventaire_id': inventaireId,
      'code': code,
      'quantite': quantite,
    };
  }

  LigneInventaire copyWith({
    int? id,
    int? inventaireId,
    String? code,
    int? quantite,
  }) {
    return LigneInventaire(
      id: id ?? this.id,
      inventaireId: inventaireId ?? this.inventaireId,
      code: code ?? this.code,
      quantite: quantite ?? this.quantite,
    );
  }
}
