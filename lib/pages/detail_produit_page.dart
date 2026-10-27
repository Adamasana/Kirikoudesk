import 'package:flutter/material.dart';

import '../models/point_vente.dart';
import '../models/produit.dart';
import '../models/stock.dart';
import '../models/sous_produit.dart';
import '../repositories/point_vente_repository.dart';
import '../repositories/stock_repository.dart';
import '../repositories/sous_produit_repository.dart';

class DetailProduitPage extends StatefulWidget {
  final Produit produit;

  const DetailProduitPage({
    super.key,
    required this.produit,
  });

  @override
  State<DetailProduitPage> createState() => _DetailProduitPageState();
}

class _DetailProduitPageState extends State<DetailProduitPage> {
  static const Color primaire = Color(0xFF0D2666);
  static const Color secondaire = Color(0xFF25427F);
  static const Color textePrincipal = Color(0xFF1D1D1F);
  static const Color muet = Color(0xFF6E6E73);
  static const Color bordure = Color(0xFFE8E8ED);
  static const Color bordureTableau = Color(0xFFEEEEEE);
  static const Color fond = Color(0xFFF7F8FA);
  static const Color blanc = Colors.white;
  static const Color fondLigneAlternee = Color(0xFFF8F9FA); // Couleur alternée très douce

  final PointVenteRepository _pointVenteRepository = PointVenteRepository();
  final SousProduitRepository _sousProduitRepository = SousProduitRepository();
  final StockRepository _stockRepository = StockRepository();

  List<SousProduit> _sousProduits = [];
  List<PointVente> _pointsVente = [];
  List<Stock> _stocks = [];

  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      setState(() {
        _chargement = true;
        _erreur = null;
      });

      final resultats = await Future.wait([
        _sousProduitRepository.obtenirParProduit(
          widget.produit.id,
        ),
        _pointVenteRepository.obtenirTous(),
        _stockRepository.obtenirTous(),
      ]);

      if (!mounted) return;

      setState(() {
        _sousProduits = resultats[0] as List<SousProduit>;
        _pointsVente = resultats[1] as List<PointVente>;
        _stocks = resultats[2] as List<Stock>;
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

  int _obtenirQuantite(
    int sousProduitId,
    int pointVenteId,
  ) {
    for (final stock in _stocks) {
      if (stock.sousProduitId == sousProduitId &&
          stock.pointDeVenteId == pointVenteId) {
        return stock.quantite;
      }
    }

    return 0;
  }

  String _nomPointVente(PointVente pointVente) {
    if (pointVente.quartier.trim().isEmpty) {
      return pointVente.ville;
    }

    return '${pointVente.ville} - ${pointVente.quartier}';
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
    return Scaffold(
      backgroundColor: fond,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          32,
          28,
          32,
          28,
        ),
        child: Column(
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          tooltip: 'Retour',
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 24,
            color: textePrincipal,
          ),
          style: IconButton.styleFrom(
            backgroundColor: blanc,
            side: const BorderSide(
              color: bordure,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(width: 16),

        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.produit.affichage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: textePrincipal,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 4,
                children: [
                  _informationProduit(
                    'Code',
                    widget.produit.nom,
                  ),
                  _informationProduit(
                    'Prix',
                    '${_formaterPrix(widget.produit.prixActuel)} FCFA',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        IconButton(
          onPressed: _chargerDonnees,
          tooltip: 'Actualiser',
          icon: const Icon(
            Icons.refresh_rounded,
            size: 21,
          ),
          color: secondaire,
          style: IconButton.styleFrom(
            backgroundColor: blanc,
            side: const BorderSide(
              color: bordure,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _informationProduit(
    String libelle,
    String valeur,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$libelle : ',
          style: const TextStyle(
            fontSize: 14,
            color: muet,
          ),
        ),
        Text(
          valeur,
          style: const TextStyle(
            fontSize: 14,
            color: textePrincipal,
            fontWeight: FontWeight.w600,
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
              'Impossible de charger les détails du produit.',
              textAlign: TextAlign.center,
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
              onPressed: _chargerDonnees,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_sousProduits.isEmpty) {
      return _construireEtatVide();
    }

    return LayoutBuilder(
      builder: (context, contraintes) {
        final largeurDisponible = contraintes.maxWidth;

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
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                overscroll: false,
              ),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _construireTableau(
                    largeurDisponible,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _construireTableau(double largeurDisponible) {
    const double largeurMinimumTableau = 900;

    final largeurTableau = largeurDisponible > largeurMinimumTableau
        ? largeurDisponible
        : largeurMinimumTableau;

    return SizedBox(
      width: largeurTableau,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: _construireLargeursColonnes(),
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
              _celluleEntete('Couleur'),
              _celluleEntete('Pointure'),
              ..._pointsVente.map(
                (pointVente) => _celluleEntete(
                  _nomPointVente(pointVente),
                ),
              ),
            ],
          ),
          ..._sousProduits.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final sousProduit = entry.value;

              // Alternance de couleur : pair = blanc, impair = fondLigneAlternée
              final couleurFond = index.isEven ? blanc : fondLigneAlternee;

              return TableRow(
                decoration: BoxDecoration(
                  color: couleurFond,
                ),
                children: [
                  _celluleValeur(
                    sousProduit.identifiant,
                    gras: true,
                    couleurFond: couleurFond,
                  ),
                  _celluleValeur(
                    sousProduit.couleur,
                    couleurFond: couleurFond,
                  ),
                  _celluleValeur(
                    sousProduit.pointure,
                    couleurFond: couleurFond,
                  ),
                  ..._pointsVente.map(
                    (pointVente) {
                      final quantite = _obtenirQuantite(
                        sousProduit.id,
                        pointVente.id,
                      );

                      return _celluleQuantite(
                        quantite,
                        couleurFond: couleurFond,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Map<int, TableColumnWidth> _construireLargeursColonnes() {
    final largeurs = <int, TableColumnWidth>{
      0: const FlexColumnWidth(1.25),
      1: const FlexColumnWidth(1),
      2: const FlexColumnWidth(1),
    };

    for (int i = 0; i < _pointsVente.length; i++) {
      largeurs[i + 3] = const FlexColumnWidth(1.25);
    }

    return largeurs;
  }

  Widget _celluleEntete(String valeur) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 62,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      alignment: Alignment.center,
      child: Text(
        valeur,
        textAlign: TextAlign.center,
        softWrap: true,
        style: const TextStyle(
          color: blanc,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _celluleValeur(
    String valeur, {
    bool gras = false,
    Color couleurFond = blanc,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 68,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      alignment: Alignment.center,
      color: couleurFond,
      child: Text(
        valeur.trim().isEmpty ? '-' : valeur,
        textAlign: TextAlign.center,
        softWrap: true,
        style: TextStyle(
          color: textePrincipal,
          fontSize: 14,
          fontWeight: gras ? FontWeight.w600 : FontWeight.w400,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _celluleQuantite(
    int quantite, {
    Color couleurFond = blanc,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 68,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      alignment: Alignment.center,
      color: couleurFond,
      child: Text(
        quantite.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: textePrincipal,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _construireEtatVide() {
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
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.layers_outlined,
              size: 48,
              color: Color(0xFFB0B0B5),
            ),
            SizedBox(height: 14),
            Text(
              'Aucun sous-produit disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textePrincipal,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Ce produit ne possède encore aucun sous-produit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muet,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}