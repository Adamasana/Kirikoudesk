class Utilisateur {
  final int id;
  final int? userId;
  final int? boutiqueId;
  final String telephone;
  final String adresse;
  final String statut;
  final String post;
  final String? numero;

  const Utilisateur({
    required this.id,
    this.userId,
    this.boutiqueId,
    required this.telephone,
    required this.adresse,
    required this.statut,
    required this.post,
    this.numero,
  });

  factory Utilisateur.fromMap(Map<String, dynamic> map) {
    return Utilisateur(
      id: map['id'] as int,
      userId: map['user_id'] as int?,
      boutiqueId: map['boutique_id'] as int?,
      telephone: map['telephone'] as String? ?? '',
      adresse: map['adresse'] as String? ?? '',
      statut: map['statut'] as String? ?? '',
      post: map['post'] as String? ?? '',
      numero: map['numero'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'boutique_id': boutiqueId,
      'telephone': telephone,
      'adresse': adresse,
      'statut': statut,
      'post': post,
      'numero': numero,
    };
  }

  Utilisateur copyWith({
    int? id,
    int? userId,
    int? boutiqueId,
    String? telephone,
    String? adresse,
    String? statut,
    String? post,
    String? numero,
  }) {
    return Utilisateur(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      telephone: telephone ?? this.telephone,
      adresse: adresse ?? this.adresse,
      statut: statut ?? this.statut,
      post: post ?? this.post,
      numero: numero ?? this.numero,
    );
  }
}