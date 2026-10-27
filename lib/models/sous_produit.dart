class SousProduit {
  final int id;
  final int produitId;
  final String couleur;
  final String pointure;
  final String identifiant;
  final String actif;
  final String desactivation;
  final String? numero;

  const SousProduit({
    required this.id,
    required this.produitId,
    required this.couleur,
    required this.pointure,
    required this.identifiant,
    required this.actif,
    required this.desactivation,
    this.numero,
  });

  factory SousProduit.fromMap(Map<String, dynamic> map) {
    return SousProduit(
      id: map['id'] as int,
      produitId: map['produit_id'] as int,
      couleur: map['couleur'] as String? ?? '',
      pointure: map['pointure'] as String? ?? '',
      identifiant: map['identifiant'] as String? ?? '',
      actif: map['actif'] as String? ?? 'Oui',
      desactivation: map['desactivation'] as String? ?? 'Oui',
      numero: map['numero'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'produit_id': produitId,
      'couleur': couleur,
      'pointure': pointure,
      'identifiant': identifiant,
      'actif': actif,
      'desactivation': desactivation,
      'numero': numero,
    };
  }

  SousProduit copyWith({
    int? id,
    int? produitId,
    String? couleur,
    String? pointure,
    String? identifiant,
    String? actif,
    String? desactivation,
    String? numero,
  }) {
    return SousProduit(
      id: id ?? this.id,
      produitId: produitId ?? this.produitId,
      couleur: couleur ?? this.couleur,
      pointure: pointure ?? this.pointure,
      identifiant: identifiant ?? this.identifiant,
      actif: actif ?? this.actif,
      desactivation: desactivation ?? this.desactivation,
      numero: numero ?? this.numero,
    );
  }
}