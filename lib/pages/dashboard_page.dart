import 'package:flutter/material.dart';

import '../models/dashboard_statistiques.dart';
import '../models/facture.dart';
import '../services/dashboard_statistiques_service.dart';
import '../theme/couleurs.dart';

class DashboardPage extends StatefulWidget {
  final List<Facture> facturesRecentes;

  /// Permet au Dashboard de demander à ApplicationPage
  /// d'afficher une autre page tout en conservant le menu latéral.
  final ValueChanged<int>? onMenuSelectionne;

  const DashboardPage({
    super.key,
    this.facturesRecentes = const [],
    this.onMenuSelectionne,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ============================================================
  // SERVICE STATISTIQUES
  // ============================================================

  late final DashboardStatistiquesService
      _statistiquesService;

  DashboardStatistiques? _statistiques;

  bool _chargementStatistiques = true;

  // ============================================================
  // INITIALISATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    _statistiquesService =
        DashboardStatistiquesService();

    _chargerStatistiques();
  }

  // ============================================================
  // DESTRUCTION
  // ============================================================

  @override
  void dispose() {
    _statistiquesService.fermer();

    super.dispose();
  }

  // ============================================================
  // CHARGEMENT DES STATISTIQUES
  // ============================================================

  Future<void> _chargerStatistiques() async {
    try {
      final statistiques =
          await _statistiquesService.obtenirStatistiques();

      if (!mounted) {
        return;
      }

      setState(() {
        _statistiques = statistiques;
        _chargementStatistiques = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statistiques = const DashboardStatistiques(
          ventes: 0,
          achats: 0,
          commandes: 0,
          telephones: [],
          facturesRecentes: [],
        );

        _chargementStatistiques = false;
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _construireEntete(),

          const SizedBox(height: 28),

          _construireStatistiques(),

          const SizedBox(height: 24),

          _construireContenuPrincipal(context),
        ],
      ),
    );
  }

  // ============================================================
  // ENTÊTE
  // ============================================================

  Widget _construireEntete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Dashboard',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Couleurs.texte,
            letterSpacing: -0.5,
          ),
        ),

        SizedBox(height: 6),

        Text(
          'Vue d’ensemble de votre activité.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: Couleurs.muted,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATISTIQUES
  // ============================================================

  Widget _construireStatistiques() {
    final statistiques = _statistiques;

    final ventes = statistiques?.ventes ?? 0;
    final achats = statistiques?.achats ?? 0;
    final commandes = statistiques?.commandes ?? 0;
    final clients = statistiques?.clients ?? 0;

    return LayoutBuilder(
      builder: (context, contraintes) {
        final largeur = contraintes.maxWidth;

        // --------------------------------------------------------
        // GRANDE FENÊTRE
        // --------------------------------------------------------

        if (largeur >= 1100) {
          return Row(
            children: [
              Expanded(
                child: _carteStatistique(
                  titre: 'Ventes',
                  valeur: _valeurStatistique(
                    '${_formaterMontant(ventes)} FCFA',
                  ),
                  sousTitre: 'Aujourd’hui',
                  icone: Icons.point_of_sale_outlined,
                  couleur: Couleurs.primaire,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: _carteStatistique(
                  titre: 'Achats',
                  valeur: _valeurStatistique(
                    '$achats',
                  ),
                  sousTitre: 'Aujourd’hui',
                  icone: Icons.shopping_bag_outlined,
                  couleur: Couleurs.secondaire,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: _carteStatistique(
                  titre: 'Commandes',
                  valeur: _valeurStatistique(
                    '$commandes',
                  ),
                  sousTitre: 'Aujourd’hui',
                  icone: Icons.shopping_cart_outlined,
                  couleur: Couleurs.information,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: _carteStatistique(
                  titre: 'Clients',
                  valeur: _valeurStatistique(
                    '$clients',
                  ),
                  sousTitre: 'Aujourd’hui',
                  icone: Icons.people_outline,
                  couleur: Couleurs.succes,
                ),
              ),
            ],
          );
        }

        // --------------------------------------------------------
        // FENÊTRE MOYENNE
        // --------------------------------------------------------

        if (largeur >= 650) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _carteStatistique(
                      titre: 'Ventes',
                      valeur: _valeurStatistique(
                        '${_formaterMontant(ventes)} FCFA',
                      ),
                      sousTitre: 'Aujourd’hui',
                      icone: Icons.point_of_sale_outlined,
                      couleur: Couleurs.primaire,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: _carteStatistique(
                      titre: 'Achats',
                      valeur: _valeurStatistique(
                        '$achats',
                      ),
                      sousTitre: 'Aujourd’hui',
                      icone: Icons.shopping_bag_outlined,
                      couleur: Couleurs.secondaire,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _carteStatistique(
                      titre: 'Commandes',
                      valeur: _valeurStatistique(
                        '$commandes',
                      ),
                      sousTitre: 'Aujourd’hui',
                      icone: Icons.shopping_cart_outlined,
                      couleur: Couleurs.information,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: _carteStatistique(
                      titre: 'Clients',
                      valeur: _valeurStatistique(
                        '$clients',
                      ),
                      sousTitre: 'Aujourd’hui',
                      icone: Icons.people_outline,
                      couleur: Couleurs.succes,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        // --------------------------------------------------------
        // PETITE FENÊTRE
        // --------------------------------------------------------

        return Column(
          children: [
            _carteStatistique(
              titre: 'Ventes',
              valeur: _valeurStatistique(
                '${_formaterMontant(ventes)} FCFA',
              ),
              sousTitre: 'Aujourd’hui',
              icone: Icons.point_of_sale_outlined,
              couleur: Couleurs.primaire,
            ),

            const SizedBox(height: 12),

            _carteStatistique(
              titre: 'Achats',
              valeur: _valeurStatistique(
                '$achats',
              ),
              sousTitre: 'Aujourd’hui',
              icone: Icons.shopping_bag_outlined,
              couleur: Couleurs.secondaire,
            ),

            const SizedBox(height: 12),

            _carteStatistique(
              titre: 'Commandes',
              valeur: _valeurStatistique(
                '$commandes',
              ),
              sousTitre: 'Aujourd’hui',
              icone: Icons.shopping_cart_outlined,
              couleur: Couleurs.information,
            ),

            const SizedBox(height: 12),

            _carteStatistique(
              titre: 'Clients',
              valeur: _valeurStatistique(
                '$clients',
              ),
              sousTitre: 'Aujourd’hui',
              icone: Icons.people_outline,
              couleur: Couleurs.succes,
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // VALEUR STATISTIQUE
  // ============================================================

  String _valeurStatistique(String valeur) {
    if (_chargementStatistiques) {
      return '...';
    }

    return valeur;
  }

  // ============================================================
  // CARTE STATISTIQUE
  // ============================================================

  Widget _carteStatistique({
    required String titre,
    required String valeur,
    required String sousTitre,
    required IconData icone,
    required Color couleur,
  }) {
    return Container(
      height: 138,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Couleurs.blanc,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Couleurs.bordure,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: couleur.withValues(
                    alpha: 0.09,
                  ),
                  borderRadius:
                      BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icone,
                  size: 21,
                  color: couleur,
                ),
              ),

              const Spacer(),

              Icon(
                Icons.more_horiz,
                size: 20,
                color: Couleurs.muted.withValues(
                  alpha: 0.7,
                ),
              ),
            ],
          ),

          const Spacer(),

          Text(
            titre,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Couleurs.muted,
            ),
          ),

          const SizedBox(height: 4),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                valeur,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Couleurs.texte,
                ),
              ),

              const SizedBox(width: 8),

              Padding(
                padding: const EdgeInsets.only(
                  bottom: 2,
                ),
                child: Text(
                  sousTitre,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: Couleurs.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENU PRINCIPAL
  // ============================================================

  Widget _construireContenuPrincipal(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        if (contraintes.maxWidth >= 950) {
          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child:
                    _construireFacturesRecentes(
                  context,
                ),
              ),

              const SizedBox(width: 20),

              Expanded(
                flex: 2,
                child:
                    _construireActionsRapides(
                  context,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _construireFacturesRecentes(
              context,
            ),

            const SizedBox(height: 20),

            _construireActionsRapides(
              context,
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // FACTURES RÉCENTES
  // ============================================================

  Widget _construireFacturesRecentes(
    BuildContext context,
  ) {
    // ==========================================================
    // PRIORITÉ AUX FACTURES VENANT DU DASHBOARD
    // ==========================================================
    //
    // Elles viennent directement de l'API serveur.
    //
    // La propriété widget.facturesRecentes est conservée
    // pour ne pas casser les appels existants à DashboardPage.
    //
    // Si l'API n'a encore rien retourné, on utilise éventuellement
    // les factures fournies au constructeur.
    //
    // ==========================================================

    final factures = _statistiques
            ?.facturesRecentes
            .isNotEmpty ==
        true
        ? List<Facture>.from(
            _statistiques!.facturesRecentes,
          )
        : List<Facture>.from(
            widget.facturesRecentes,
          );

    factures.sort(
      (a, b) => b.dateCreation.compareTo(
        a.dateCreation,
      ),
    );

    final cinqDernieres =
        factures.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: Couleurs.blanc,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: Couleurs.bordure,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              18,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Factures récentes',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w600,
                          color:
                              Couleurs.texte,
                        ),
                      ),

                      SizedBox(height: 4),

                      Text(
                        'Les 5 dernières factures.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight:
                              FontWeight.w400,
                          color:
                              Couleurs.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                TextButton(
                  onPressed: () =>
                      _ouvrirFactures(
                    context,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Couleurs.primaire,
                  ),
                  child: const Text(
                    'Voir tout',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color:
                Couleurs.bordureTableau,
          ),

          if (cinqDernieres.isEmpty)
            _construireEtatVide()
          else
            _construireListeFactures(
              cinqDernieres,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // LISTE DES 5 DERNIÈRES FACTURES
  // ============================================================

  Widget _construireListeFactures(
    List<Facture> factures,
  ) {
    return Column(
      children: [
        for (
          int index = 0;
          index < factures.length;
          index++
        ) ...[
          _construireLigneFacture(
            factures[index],
          ),

          if (index != factures.length - 1)
            const Divider(
              height: 1,
              color:
                  Couleurs.bordureTableau,
            ),
        ],
      ],
    );
  }

  // ============================================================
  // LIGNE FACTURE
  // ============================================================

  Widget _construireLigneFacture(
    Facture facture,
  ) {
    final nomClient =
        facture.nom.trim().isEmpty
            ? 'Client'
            : facture.nom.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Couleurs.fond,
              borderRadius:
                  BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 19,
              color: Couleurs.primaire,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  nomClient,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Couleurs.texte,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  _formaterDate(
                    facture.dateCreation,
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w400,
                    color:
                        Couleurs.muted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Text(
            '${_formaterMontant(facture.total)} FCFA',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Couleurs.texte,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ÉTAT VIDE
  // ============================================================

  Widget _construireEtatVide() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 42,
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Couleurs.fond,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 25,
              color: Couleurs.muted,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Aucune facture récente',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Couleurs.texte,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Les dernières factures apparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: Couleurs.muted,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS RAPIDES
  // ============================================================

  Widget _construireActionsRapides(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Couleurs.blanc,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: Couleurs.bordure,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions rapides',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Couleurs.texte,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Accédez rapidement aux principales fonctions.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: Couleurs.muted,
            ),
          ),

          const SizedBox(height: 18),

          _construireAction(
            icone:
                Icons.point_of_sale_outlined,
            titre: 'Ouvrir la caisse',
            sousTitre: 'Effectuer une vente',
            onTap: () =>
                _ouvrirCaisse(context),
          ),

          const SizedBox(height: 10),

          _construireAction(
            icone:
                Icons.receipt_long_outlined,
            titre:
                'Consulter les factures',
            sousTitre:
                'Voir les ventes facturées',
            onTap: () =>
                _ouvrirFactures(context),
          ),

          const SizedBox(height: 10),

          _construireAction(
            icone:
                Icons.inventory_2_outlined,
            titre:
                'Consulter les produits',
            sousTitre:
                'Voir les produits',
            onTap: () =>
                _ouvrirProduits(context),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION
  // ============================================================

  Widget _construireAction({
    required IconData icone,
    required String titre,
    required String sousTitre,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: Couleurs.bordure,
            ),
            borderRadius:
                BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color: Couleurs.fond,
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icone,
                  size: 19,
                  color:
                      Couleurs.primaire,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      titre,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            Couleurs.texte,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      sousTitre,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight:
                            FontWeight.w400,
                        color:
                            Couleurs.muted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right,
                size: 19,
                color: Couleurs.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION — CAISSE
  // ============================================================

  void _ouvrirCaisse(
    BuildContext context,
  ) {
    widget.onMenuSelectionne?.call(1);
  }

  // ============================================================
  // NAVIGATION — FACTURES
  // ============================================================

  void _ouvrirFactures(
    BuildContext context,
  ) {
    widget.onMenuSelectionne?.call(2);
  }

  // ============================================================
  // NAVIGATION — PRODUITS
  // ============================================================

  void _ouvrirProduits(
    BuildContext context,
  ) {
    widget.onMenuSelectionne?.call(3);
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formaterDate(DateTime date) {
    final jour =
        date.day.toString().padLeft(2, '0');

    final mois =
        date.month.toString().padLeft(2, '0');

    final annee =
        date.year.toString();

    final heure =
        date.hour.toString().padLeft(2, '0');

    final minute =
        date.minute.toString().padLeft(2, '0');

    return '$jour/$mois/$annee à $heure:$minute';
  }

  // ============================================================
  // FORMAT MONTANT
  // ============================================================

  String _formaterMontant(num montant) {
    final valeur =
        montant.round().toString();

    final buffer = StringBuffer();

    for (
      int i = 0;
      i < valeur.length;
      i++
    ) {
      if (
        i > 0 &&
        (valeur.length - i) % 3 == 0
      ) {
        buffer.write(' ');
      }

      buffer.write(valeur[i]);
    }

    return buffer.toString();
  }
}