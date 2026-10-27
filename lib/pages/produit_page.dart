import 'package:flutter/material.dart';

import '../models/produit.dart';
import '../repositories/produit_repository.dart';
import 'detail_produit_page.dart';

class ProduitPage extends StatefulWidget {
  const ProduitPage({super.key});

  @override
  State<ProduitPage> createState() => _ProduitPageState();
}

class _ProduitPageState extends State<ProduitPage> {
  static const Color primaire = Color(0xFF0D2666);
  static const Color textePrincipal = Color(0xFF1D1D1F);
  static const Color muet = Color(0xFF6E6E73);
  static const Color bordure = Color(0xFFE8E8ED);
  static const Color bordureTableau = Color(0xFFEEEEEE);
  static const Color fond = Color(0xFFF7F8FA);
  static const Color blanc = Colors.white;

  final ProduitRepository _produitRepository = ProduitRepository();
  final TextEditingController _rechercheController =
      TextEditingController();

  List<Produit> _produits = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();

    _chargerProduits();

    _rechercheController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _chargerProduits() async {
    try {
      setState(() {
        _chargement = true;
        _erreur = null;
      });

      final produits = await _produitRepository.obtenirTous();

      if (!mounted) return;

      setState(() {
        _produits = produits;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _chargement = false;
        _erreur = e.toString();
      });
    }
  }

  List<Produit> get _produitsFiltres {
    final recherche = _rechercheController.text.trim().toLowerCase();

    if (recherche.isEmpty) {
      return _produits;
    }

    return _produits.where((produit) {
      final code = produit.nom.toLowerCase();
      final nom = produit.affichage.toLowerCase();
      final prix = produit.prixActuel.toString();

      return code.contains(recherche) ||
          nom.contains(recherche) ||
          prix.contains(recherche);
    }).toList();
  }

  void _ouvrirDetail(Produit produit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailProduitPage(
          produit: produit,
        ),
      ),
    );
  }

  String _formaterPrix(int prix) {
    final textePrix = prix.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < textePrix.length; i++) {
      if (i > 0 && (textePrix.length - i) % 3 == 0) {
        buffer.write(' ');
      }

      buffer.write(textePrix[i]);
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: fond,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _construireEntete(),
            const SizedBox(height: 28),
            Expanded(
              child: _construireContenu(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construireEntete() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Produits',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: textePrincipal,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: 5),
              Padding(
                padding: EdgeInsets.only(left: 48),
                child: Text(
                  'Gérez vos produits',
                  style: TextStyle(
                    fontSize: 15,
                    color: muet,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 340,
          height: 48,
          child: TextField(
            controller: _rechercheController,
            style: const TextStyle(
              fontSize: 14,
              color: textePrincipal,
            ),
            decoration: InputDecoration(
              hintText: 'Rechercher',
              hintStyle: const TextStyle(
                color: muet,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 21,
                color: muet,
              ),
              suffixIcon: _rechercheController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _rechercheController.clear();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: muet,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: blanc,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: bordure,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: bordure,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: primaire,
                  width: 1.3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _afficherAjoutProduit,
            icon: const Icon(
              Icons.add_rounded,
              size: 20,
            ),
            label: const Text(
              'Ajouter un produit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaire,
              foregroundColor: blanc,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construireContenu() {
    if (_chargement) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaire,
        ),
      );
    }

    if (_erreur != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Impossible de charger les produits.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textePrincipal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _erreur!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: muet,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _chargerProduits,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final produits = _produitsFiltres;

    if (produits.isEmpty) {
      return _construireEtatVide();
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: blanc,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E5EA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, contraintes) {
            return Scrollbar(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _construireTableau(
                    produits,
                    contraintes.maxWidth,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _construireTableau(
    List<Produit> produits,
    double largeurDisponible,
  ) {
    const double largeurMinimum = 820;

    final double largeurTableau =
        largeurDisponible < largeurMinimum
            ? largeurMinimum
            : largeurDisponible;

    return SizedBox(
      width: largeurTableau,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(2.6),
          2: FlexColumnWidth(1.2),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(
            color: bordureTableau,
            width: 1,
          ),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: primaire,
            ),
            children: [
              _celluleEntete('Code'),
              _celluleEntete('Nom'),
              _celluleEntete('Prix'),
            ],
          ),
          ...produits.map(
            (produit) => TableRow(
              children: [
                _celluleProduit(
                  produit.nom,
                  onTap: () => _ouvrirDetail(produit),
                ),
                _celluleProduit(
                  produit.affichage,
                  onTap: () => _ouvrirDetail(produit),
                ),
                _celluleProduit(
                  '${_formaterPrix(produit.prixActuel)} FCFA',
                  onTap: () => _ouvrirDetail(produit),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _celluleEntete(String valeur) {
    return SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            valeur,
            style: const TextStyle(
              color: blanc,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _celluleProduit(
    String valeur, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              style: const TextStyle(
                color: textePrincipal,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construireEtatVide() {
    final rechercheActive =
        _rechercheController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: blanc,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E5EA),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rechercheActive
                  ? Icons.search_off_rounded
                  : Icons.inventory_2_outlined,
              size: 48,
              color: const Color(0xFFB0B0B5),
            ),
            const SizedBox(height: 14),
            Text(
              rechercheActive
                  ? 'Aucun produit trouvé'
                  : 'Aucun produit disponible',
              style: const TextStyle(
                color: textePrincipal,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (rechercheActive) ...[
              const SizedBox(height: 6),
              const Text(
                'Essayez avec un autre terme de recherche.',
                style: TextStyle(
                  color: muet,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _afficherAjoutProduit() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un produit'),
          content: const Text(
            'La création des produits sera connectée au backend prochainement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}