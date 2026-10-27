class ProduitFictif {
  final String code;
  final String nom;
  final double prix;
  final int stock;

  const ProduitFictif({
    required this.code,
    required this.nom,
    required this.prix,
    this.stock = 0,
  });
}