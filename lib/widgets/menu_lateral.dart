import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../models/session.dart';

class MenuLateral extends StatefulWidget {
  final int indexActif;
  final bool menuOuvert;
  final ValueChanged<int> onMenuSelectionne;
  final VoidCallback onDeconnexion;

  // ==========================================================
  // SYNCHRONISATION GLOBALE
  // ==========================================================

  final Future<void> Function()? onSynchronisationGlobale;

  const MenuLateral({
    super.key,
    required this.indexActif,
    required this.menuOuvert,
    required this.onMenuSelectionne,
    required this.onDeconnexion,
    this.onSynchronisationGlobale,
  });

  @override
  State<MenuLateral> createState() => _MenuLateralState();
}

class _MenuLateralState extends State<MenuLateral> {
  static const double largeurOuverte = 245;

  int? _indexSurvole;

  Session? _session;
  bool _chargementSession = true;

  // ==========================================================
  // SYNCHRONISATION
  // ==========================================================

  bool _synchronisationEnCours = false;

  final List<_ElementMenu> _menus = const [
    _ElementMenu(
      titre: 'Dashboard',
      icone: Icons.dashboard_outlined,
    ),
    _ElementMenu(
      titre: 'Caisse',
      icone: Icons.point_of_sale_outlined,
    ),
    _ElementMenu(
      titre: 'Factures',
      icone: Icons.receipt_long_outlined,
    ),
    _ElementMenu(
      titre: 'Produit',
      icone: Icons.inventory_2_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _chargerSession();
  }

  // ==========================================================
  // SESSION
  // ==========================================================

  Future<void> _chargerSession() async {
    try {
      final session = await Session.fromPreferences();

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _chargementSession = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _session = null;
        _chargementSession = false;
      });
    }
  }

  String _nomUtilisateur() {
    final session = _session;

    if (session == null) {
      return '';
    }

    final prenom = session.prenom.trim();
    final nom = session.nom.trim();

    if (prenom.isNotEmpty && nom.isNotEmpty) {
      return '$prenom $nom';
    }

    if (prenom.isNotEmpty) {
      return prenom;
    }

    if (nom.isNotEmpty) {
      return nom;
    }

    return session.username.trim();
  }

  // ==========================================================
  // SYNCHRONISATION GLOBALE
  // ==========================================================

  Future<void> _lancerSynchronisationGlobale() async {
    if (_synchronisationEnCours) {
      return;
    }

    final callback = widget.onSynchronisationGlobale;

    if (callback == null) {
      return;
    }

    setState(() {
      _synchronisationEnCours = true;
    });

    try {
      await callback();
    } finally {
      if (mounted) {
        setState(() {
          _synchronisationEnCours = false;
        });
      }
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: widget.menuOuvert ? largeurOuverte : 0,
      height: double.infinity,
      color: Couleurs.primaire,

      // Très important :
      //
      // Le contenu interne garde toujours sa largeur de 245 px.
      // Le conteneur extérieur, lui, s'anime de 245 px vers 0 px.
      //
      // Ainsi, pendant la fermeture, les Row internes ne reçoivent
      // plus des contraintes minuscules comme 4.8 px ou 10 px.
      // Ils restent à leur largeur normale et sont simplement
      // découpés par le ClipRect.
      clipBehavior: Clip.hardEdge,

      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: largeurOuverte,
        maxWidth: largeurOuverte,
        child: SizedBox(
          width: largeurOuverte,
          height: double.infinity,
          child: ClipRect(
            child: Column(
              children: [
                _construireEntete(),

                Expanded(
                  child: _construireListeMenus(),
                ),

                _construirePied(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // ENTETE
  // ==========================================================

  Widget _construireEntete() {
    return SizedBox(
      height: 75,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Couleurs.blanc.withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'K',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Couleurs.blanc,
                ),
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Text(
                'KirikouBF',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Couleurs.blanc,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // LISTE DES MENUS
  // ==========================================================

  Widget _construireListeMenus() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        10,
        16,
        10,
        10,
      ),
      child: Column(
        children: List.generate(
          _menus.length,
          (index) => Padding(
            padding: const EdgeInsets.only(
              bottom: 5,
            ),
            child: _construireElementMenu(
              index: index,
              element: _menus[index],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // ELEMENT MENU
  // ==========================================================

  Widget _construireElementMenu({
    required int index,
    required _ElementMenu element,
  }) {
    final estActif = widget.indexActif == index;
    final estSurvole = _indexSurvole == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,

      onEnter: (_) {
        setState(() {
          _indexSurvole = index;
        });
      },

      onExit: (_) {
        setState(() {
          _indexSurvole = null;
        });
      },

      child: GestureDetector(
        onTap: () {
          widget.onMenuSelectionne(index);
        },

        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          curve: Curves.easeOut,
          height: 50,
          width: double.infinity,

          decoration: BoxDecoration(
            color: estActif
                ? Couleurs.secondaire
                : estSurvole
                    ? Couleurs.hover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),

          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              // ------------------------------------------------
              // ICONE
              // ------------------------------------------------

              SizedBox(
                width: 48,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      element.icone,
                      size: 21,
                      color: Couleurs.blanc.withValues(
                        alpha: estActif ? 1 : 0.86,
                      ),
                    ),

                    // Indicateur du menu actif
                    if (estActif)
                      Positioned(
                        left: 0,
                        top: 11,
                        bottom: 11,
                        child: Container(
                          width: 3,
                          decoration:
                              const BoxDecoration(
                            color: Couleurs.blanc,
                            borderRadius:
                                BorderRadius.only(
                              topRight:
                                  Radius.circular(3),
                              bottomRight:
                                  Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 2),

              // ------------------------------------------------
              // TEXTE
              // ------------------------------------------------

              Expanded(
                child: Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    element.titre,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      fontWeight: estActif
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color:
                          Couleurs.blanc.withValues(
                        alpha:
                            estActif ? 1 : 0.92,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // PIED DU MENU
  // ==========================================================

  Widget _construirePied() {
    final nomUtilisateur = _nomUtilisateur();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        10,
        10,
        10,
        14,
      ),
      child: Column(
        children: [
          // ----------------------------------------------------
          // SEPARATION
          // ----------------------------------------------------

          Container(
            height: 1,
            color: Couleurs.blanc.withValues(
              alpha: 0.08,
            ),
          ),

          const SizedBox(height: 10),

          // ----------------------------------------------------
          // UTILISATEUR + SYNCHRONISATION + DECONNEXION
          // ----------------------------------------------------

          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                // ------------------------------------------------
                // ICONE UTILISATEUR
                // ------------------------------------------------

                const SizedBox(
                  width: 38,
                  height: 48,
                  child: Center(
                    child: Icon(
                      Icons.person_outline,
                      size: 21,
                      color: Couleurs.blanc,
                    ),
                  ),
                ),

                // ------------------------------------------------
                // NOM UTILISATEUR
                // ------------------------------------------------

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 4,
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _chargementSession
                              ? '...'
                              : nomUtilisateur.isEmpty
                                  ? 'Utilisateur'
                                  : nomUtilisateur,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight:
                                FontWeight.w600,
                            color: Couleurs.blanc,
                          ),
                        ),

                        const SizedBox(height: 2),

                        const Text(
                          'Connecté',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight:
                                FontWeight.w400,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ------------------------------------------------
                // SYNCHRONISATION
                // ------------------------------------------------

                SizedBox(
                  width: 38,
                  height: 48,
                  child: IconButton(
                    tooltip: 'Synchroniser les données',
                    padding: EdgeInsets.zero,
                    onPressed: _synchronisationEnCours
                        ? null
                        : _lancerSynchronisationGlobale,
                    icon: _synchronisationEnCours
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<
                                      Color>(
                                Couleurs.blanc,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.sync_outlined,
                            size: 20,
                            color: Couleurs.blanc,
                          ),
                  ),
                ),

                // ------------------------------------------------
                // DECONNEXION
                // ------------------------------------------------

                SizedBox(
                  width: 38,
                  height: 48,
                  child: IconButton(
                    tooltip: 'Se déconnecter',
                    padding: EdgeInsets.zero,
                    onPressed: _synchronisationEnCours
                        ? null
                        : widget.onDeconnexion,
                    icon: const Icon(
                      Icons.logout_outlined,
                      size: 20,
                      color: Couleurs.blanc,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MODELE ELEMENT MENU
// ============================================================

class _ElementMenu {
  final String titre;
  final IconData icone;

  const _ElementMenu({
    required this.titre,
    required this.icone,
  });
}