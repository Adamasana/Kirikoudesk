import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/database/database_helper.dart';
import 'pages/connexion_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/caisse_page.dart';
import 'pages/factures_page.dart';
import 'pages/produit_page.dart';
import 'repositories/authentification_repository.dart';
import 'services/synchronisation/donnees_reference_service.dart';
import 'services/synchronisation/synchronisation_globale_service.dart';
import 'widgets/menu_lateral.dart';
import 'theme/couleurs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  await DatabaseHelper.obtenirBase();

  runApp(const KirikouBF());
}

class KirikouBF extends StatelessWidget {
  const KirikouBF({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KirikouBF',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Couleurs.fond,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Couleurs.primaire,
        ),
      ),
      home: const DemarragePage(),
    );
  }
}

class DemarragePage extends StatefulWidget {
  const DemarragePage({super.key});

  @override
  State<DemarragePage> createState() => _DemarragePageState();
}

class _DemarragePageState extends State<DemarragePage> {
  final AuthentificationRepository _authentificationRepository =
      AuthentificationRepository();

  @override
  void initState() {
    super.initState();
    _verifierSession();
  }

  Future<void> _verifierSession() async {
    final session =
        await _authentificationRepository.obtenirSession();

    if (!mounted) return;

    if (session != null && session.token.isNotEmpty) {
      try {
        final service = DonneesReferenceService();

        await service.synchroniser();

        await service.afficherDonneesLocales();

        service.fermer();
      } catch (e) {
        debugPrint(
          'Erreur synchronisation référentiels : $e',
        );
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ApplicationPage(),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ConnexionPage(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _authentificationRepository.fermer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Couleurs.fond,
      body: Center(
        child: CircularProgressIndicator(
          color: Couleurs.primaire,
        ),
      ),
    );
  }
}

class ApplicationPage extends StatefulWidget {
  const ApplicationPage({super.key});

  @override
  State<ApplicationPage> createState() => _ApplicationPageState();
}

class _ApplicationPageState extends State<ApplicationPage> {
  int _indexActif = 0;
  bool _menuOuvert = true;

  // ============================================================
  // CLÉ DE LA PAGE CAISSE
  // ============================================================
  //
  // Cette clé permet au main de demander directement à
  // CaissePage de relire les données locales après une
  // synchronisation globale.
  //
  final GlobalKey<CaissePageState> _caissePageKey =
      GlobalKey<CaissePageState>();

  final List<String> _titres = const [
    'Dashboard',
    'Caisse',
    'Factures',
    'Produit',
  ];

  final List<String> _sousTitres = const [
    'Vue d’ensemble de votre activité.',
    'Gérez vos ventes.',
    'Consultez et gérez vos factures.',
    'Gérez vos produits.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleurs.fond,
      body: LayoutBuilder(
        builder: (context, contraintes) {
          final largeur = contraintes.maxWidth;
          final petitEcran = largeur <= 768;

          if (petitEcran) {
            return _construireVersionMobile();
          }

          return _construireVersionDesktop();
        },
      ),
    );
  }

  // ============================================================
  // VERSION DESKTOP
  // ============================================================

  Widget _construireVersionDesktop() {
    return Row(
      children: [
        MenuLateral(
          indexActif: _indexActif,
          menuOuvert: _menuOuvert,
          onMenuSelectionne: _selectionnerMenu,
          onDeconnexion: _seDeconnecter,
          onSynchronisationGlobale:
              _synchroniserGlobalement,
        ),

        Expanded(
          child: _construireZonePrincipale(),
        ),
      ],
    );
  }

  // ============================================================
  // VERSION MOBILE
  // ============================================================

  Widget _construireVersionMobile() {
    return Stack(
      children: [
        _construireZonePrincipale(),

        if (_menuOuvert)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _menuOuvert = false;
                });
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: _menuOuvert ? 0 : -245,
          top: 0,
          bottom: 0,
          width: 245,
          child: MenuLateral(
            indexActif: _indexActif,
            menuOuvert: true,
            onMenuSelectionne: _selectionnerMenu,
            onDeconnexion: _seDeconnecter,
            onSynchronisationGlobale:
                _synchroniserGlobalement,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ZONE PRINCIPALE
  // ============================================================

  Widget _construireZonePrincipale() {
    return Column(
      children: [
        _construireEntete(),

        Expanded(
          child: _construirePageActuelle(),
        ),
      ],
    );
  }

  // ============================================================
  // ENTÊTE
  // ============================================================

  Widget _construireEntete() {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Couleurs.blanc,
        border: Border(
          bottom: BorderSide(
            color: Couleurs.bordure,
          ),
        ),
      ),
      child: Row(
        children: [
          _construireBoutonMenu(),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titres[_indexActif],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Couleurs.texte,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  _sousTitres[_indexActif],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: Couleurs.muted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Aucune nouvelle notification.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                    ),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none_outlined,
              size: 21,
              color: Couleurs.muted,
            ),
          ),

          const SizedBox(width: 4),

          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Couleurs.fond,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_outline,
              size: 19,
              color: Couleurs.primaire,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOUTON MENU
  // ============================================================

  Widget _construireBoutonMenu() {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Couleurs.fond,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _menuOuvert = !_menuOuvert;
            });
          },
          child: Center(
            child: Icon(
              _menuOuvert
                  ? Icons.menu_open_outlined
                  : Icons.menu_outlined,
              size: 21,
              color: Couleurs.texte,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PAGE ACTUELLE
  // ============================================================

  Widget _construirePageActuelle() {
    switch (_indexActif) {
      case 0:
        return DashboardPage(
          onMenuSelectionne: _selectionnerMenu,
        );

      case 1:
        return CaissePage(
          key: _caissePageKey,
        );

      case 2:
        return const FacturesPage();

      case 3:
        return const ProduitPage();

      default:
        return DashboardPage(
          onMenuSelectionne: _selectionnerMenu,
        );
    }
  }

  // ============================================================
  // SÉLECTION MENU
  // ============================================================

  void _selectionnerMenu(int index) {
    setState(() {
      _indexActif = index;
    });

    if (MediaQuery.of(context).size.width <= 768) {
      setState(() {
        _menuOuvert = false;
      });
    }
  }

  // ============================================================
  // SYNCHRONISATION GLOBALE
  // ============================================================
  //
  // Cette méthode est appelée directement par le bouton
  // de synchronisation du MenuLateral.
  //
  // Elle utilise SynchronisationGlobaleService.
  //
  // Après une synchronisation réussie, on demande directement
  // à CaissePage de relire SQLite.
  //
  // Cela permet notamment de faire disparaître immédiatement
  // les commandes qui viennent d'être synchronisées puis
  // supprimées localement.
  //
  // ============================================================

  Future<void> _synchroniserGlobalement() async {
    final service = SynchronisationGlobaleService();

    try {
      final resultat = await service.synchroniser();

      if (!mounted) {
        return;
      }

      final total = resultat.totalCommandes;

      final synchronisees =
          resultat.commandesSynchronisees;

      final dejaSynchronisees =
          resultat.commandesDejaSynchronisees;

      final erreurs =
          resultat.nombreErreurs;

      String message;

      if (total == 0) {
        message =
            'Synchronisation terminée. '
            'Aucune commande en attente.';
      } else if (erreurs > 0) {
        message =
            'Synchronisation terminée : '
            '$synchronisees synchronisée(s), '
            '$dejaSynchronisees déjà synchronisée(s), '
            '$erreurs erreur(s).';
      } else {
        message =
            'Synchronisation terminée : '
            '$synchronisees commande(s) synchronisée(s).';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Inter',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // ----------------------------------------------------------
      // RAFRAÎCHISSEMENT RÉEL DE LA CAISSE
      // ----------------------------------------------------------
      //
      // Si CaissePage est actuellement affichée, on lui demande
      // directement de recharger ses données depuis SQLite.
      //
      // Cela est différent d'un simple setState() ici :
      // le State de CaissePage possède déjà sa liste _commandes,
      // donc il faut appeler sa méthode actualiser().
      //
      if (_indexActif == 1) {
        await _caissePageKey.currentState?.actualiser();
      }
    } on SynchronisationGlobaleException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
            style: const TextStyle(
              fontFamily: 'Inter',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur pendant la synchronisation : $e',
            style: const TextStyle(
              fontFamily: 'Inter',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      service.fermer();
    }
  }

  // ============================================================
  // DÉCONNEXION
  // ============================================================

  Future<void> _seDeconnecter() async {
    final authentificationRepository =
        AuthentificationRepository();

    await authentificationRepository.deconnecter();

    authentificationRepository.fermer();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const ConnexionPage(),
      ),
      (route) => false,
    );
  }
}