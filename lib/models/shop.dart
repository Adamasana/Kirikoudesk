class Shop {
  final int? id;
  final int commandeId;
  final int? articleId;
  final int quantite;
  final String couleur;
  final String pointure;
  final int prix;
  final int montant;
  final String statut;

  const Shop({
    this.id,
    required this.commandeId,
    this.articleId,
    required this.quantite,
    required this.couleur,
    required this.pointure,
    required this.prix,
    required this.montant,
    required this.statut,
  });

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as int?,
      commandeId: map['commande_id'] as int,
      articleId: map['article_id'] as int?,
      quantite: map['quantite'] as int? ?? 1,
      couleur: map['couleur'] as String? ?? '',
      pointure: map['pointure'] as String? ?? '',
      prix: map['prix'] as int? ?? 0,
      montant: map['montant'] as int? ?? 0,
      statut: map['statut'] as String? ?? 'valide',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'commande_id': commandeId,
      'article_id': articleId,
      'quantite': quantite,
      'couleur': couleur,
      'pointure': pointure,
      'prix': prix,
      'montant': montant,
      'statut': statut,
    };
  }

  Shop copyWith({
    int? id,
    int? commandeId,
    int? articleId,
    int? quantite,
    String? couleur,
    String? pointure,
    int? prix,
    int? montant,
    String? statut,
  }) {
    return Shop(
      id: id ?? this.id,
      commandeId: commandeId ?? this.commandeId,
      articleId: articleId ?? this.articleId,
      quantite: quantite ?? this.quantite,
      couleur: couleur ?? this.couleur,
      pointure: pointure ?? this.pointure,
      prix: prix ?? this.prix,
      montant: montant ?? this.montant,
      statut: statut ?? this.statut,
    );
  }
}