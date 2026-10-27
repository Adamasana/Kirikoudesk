class PointVente {
  final int id;
  final String ville;
  final String quartier;

  const PointVente({
    required this.id,
    required this.ville,
    required this.quartier,
  });

  factory PointVente.fromMap(Map<String, dynamic> map) {
    return PointVente(
      id: map['id'] as int,
      ville: map['ville'] as String? ?? '',
      quartier: map['quartier'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ville': ville,
      'quartier': quartier,
    };
  }

  PointVente copyWith({
    int? id,
    String? ville,
    String? quartier,
  }) {
    return PointVente(
      id: id ?? this.id,
      ville: ville ?? this.ville,
      quartier: quartier ?? this.quartier,
    );
  }
}