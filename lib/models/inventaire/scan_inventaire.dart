
class ScanInventaire {
  final int? id;
  final int ligneInventaireId;
  final DateTime dateScan;

  const ScanInventaire({
    this.id,
    required this.ligneInventaireId,
    required this.dateScan,
  });

  factory ScanInventaire.fromMap(Map<String, dynamic> map) {
    return ScanInventaire(
      id: map['id'] as int?,
      ligneInventaireId: map['ligne_inventaire_id'] as int,
      dateScan: DateTime.parse(map['date_scan'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ligne_inventaire_id': ligneInventaireId,
      'date_scan': dateScan.toIso8601String(),
    };
  }
}
