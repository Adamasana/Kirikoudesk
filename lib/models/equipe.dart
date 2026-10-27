class Equipe {
  final int id;
  final String nom;
  final int pointDeVenteId;
  final String identifiant;

  const Equipe({
    required this.id,
    required this.nom,
    required this.pointDeVenteId,
    required this.identifiant,
  });

  factory Equipe.fromMap(Map<String, dynamic> map) {
    return Equipe(
      id: map['id'] as int,
      nom: map['nom'] as String? ?? '',
      pointDeVenteId: map['point_de_vente_id'] as int,
      identifiant: map['identifiant'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'point_de_vente_id': pointDeVenteId,
      'identifiant': identifiant,
    };
  }

  Equipe copyWith({
    int? id,
    String? nom,
    int? pointDeVenteId,
    String? identifiant,
  }) {
    return Equipe(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      pointDeVenteId: pointDeVenteId ?? this.pointDeVenteId,
      identifiant: identifiant ?? this.identifiant,
    );
  }
}