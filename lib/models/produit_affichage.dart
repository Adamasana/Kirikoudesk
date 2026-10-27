class ProduitAffichage {
  final int id;
  final String code;
  final String nom;
  final int prixAchat;
  final int prixVente;
  final int quantite;

  const ProduitAffichage({
    required this.id,
    required this.code,
    required this.nom,
    required this.prixAchat,
    required this.prixVente,
    required this.quantite,
  });
}