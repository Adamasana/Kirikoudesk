class Produit {
  final int id;
  final String affichage;
  final String nom;
  final int prix;
  final int prixEvenement;
  final String promo;
  final String nouveau;
  final String liquidation;
  final String actif;
  final String desactivation;
  final DateTime? date;

  const Produit({
    required this.id,
    required this.affichage,
    required this.nom,
    required this.prix,
    required this.prixEvenement,
    required this.promo,
    required this.nouveau,
    required this.liquidation,
    required this.actif,
    required this.desactivation,
    this.date,
  });

  factory Produit.fromMap(Map<String, dynamic> map) {
    return Produit(
      id: map['id'] as int,
      affichage: map['affichage'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      prix: map['prix'] as int? ?? 0,
      prixEvenement: map['prix_evenement'] as int? ?? 0,
      promo: map['promo'] as String? ?? 'Non',
      nouveau: map['nouveau'] as String? ?? 'Non',
      liquidation: map['liquidation'] as String? ?? 'Non',
      actif: map['actif'] as String? ?? 'Oui',
      desactivation: map['desactivation'] as String? ?? 'Oui',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'affichage': affichage,
      'nom': nom,
      'prix': prix,
      'prix_evenement': prixEvenement,
      'promo': promo,
      'nouveau': nouveau,
      'liquidation': liquidation,
      'actif': actif,
      'desactivation': desactivation,
      'date': date?.toIso8601String(),
    };
  }

  Produit copyWith({
    int? id,
    String? affichage,
    String? nom,
    int? prix,
    int? prixEvenement,
    String? promo,
    String? nouveau,
    String? liquidation,
    String? actif,
    String? desactivation,
    DateTime? date,
  }) {
    return Produit(
      id: id ?? this.id,
      affichage: affichage ?? this.affichage,
      nom: nom ?? this.nom,
      prix: prix ?? this.prix,
      prixEvenement: prixEvenement ?? this.prixEvenement,
      promo: promo ?? this.promo,
      nouveau: nouveau ?? this.nouveau,
      liquidation: liquidation ?? this.liquidation,
      actif: actif ?? this.actif,
      desactivation: desactivation ?? this.desactivation,
      date: date ?? this.date,
    );
  }

  int get prixActuel {
    if (promo == 'Oui' || liquidation == 'Oui') {
      return prixEvenement;
    }

    return prix;
  }
}