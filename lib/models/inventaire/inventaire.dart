
class Inventaire {
  final int? id;
  final int pointVenteId;
  final int? utilisateurId;
  final DateTime dateCreation;
  final String statut;

  const Inventaire({
    this.id,
    required this.pointVenteId,
    this.utilisateurId,
    required this.dateCreation,
    this.statut = 'en_cours',
  });

  factory Inventaire.fromMap(Map<String, dynamic> map) {
    return Inventaire(
      id: map['id'] as int?,
      pointVenteId: map['point_vente_id'] as int,
      utilisateurId: map['utilisateur_id'] as int?,
      dateCreation: DateTime.parse(map['date_creation'] as String),
      statut: map['statut'] as String? ?? 'en_cours',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'point_vente_id': pointVenteId,
      'utilisateur_id': utilisateurId,
      'date_creation': dateCreation.toIso8601String(),
      'statut': statut,
    };
  }

  Inventaire copyWith({
    int? id,
    int? pointVenteId,
    int? utilisateurId,
    DateTime? dateCreation,
    String? statut,
  }) {
    return Inventaire(
      id: id ?? this.id,
      pointVenteId: pointVenteId ?? this.pointVenteId,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      dateCreation: dateCreation ?? this.dateCreation,
      statut: statut ?? this.statut,
    );
  }
}
