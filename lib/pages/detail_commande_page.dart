import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/commande.dart';
import '../models/produit.dart';
import '../models/session.dart';
import '../models/shop.dart';
import '../models/sous_produit.dart';
import '../models/stock.dart';
import '../repositories/commande_repository.dart';
import '../repositories/produit_repository.dart';
import '../repositories/sous_produit_repository.dart';
import '../repositories/stock_repository.dart';
import '../theme/couleurs.dart';

class DetailCommandePage extends StatefulWidget {
  final Commande commande;

  const DetailCommandePage({
    super.key,
    required this.commande,
  });

  @override
  State<DetailCommandePage> createState() =>
      _DetailCommandePageState();
}

class _DetailCommandePageState
    extends State<DetailCommandePage> {
  final CommandeRepository _commandeRepository =
      CommandeRepository();

  final ProduitRepository _produitRepository =
      ProduitRepository();

  final SousProduitRepository _sousProduitRepository =
      SousProduitRepository();

  final StockRepository _stockRepository =
      StockRepository();

  final TextEditingController _numeroController =
      TextEditingController();

  final TextEditingController _nomController =
      TextEditingController();

  final TextEditingController _telephoneController =
      TextEditingController();

  final TextEditingController _remiseController =
      TextEditingController();

  List<Shop> _shops = [];

  List<SousProduit> _sousProduitsDisponibles = [];

  final Map<int, Produit> _produitsParId = {};
  final Map<int, SousProduit> _sousProduitsParId = {};
  final Map<int, Stock?> _stocksParSousProduit = {};

  bool _chargement = true;
  bool _operationEnCours = false;

  String? _erreur;

  String _bufferScanner = '';
  DateTime? _dernierCaractereScanner;
  Timer? _timerScanner;
  bool _traitementScan = false;

  int get _montant {
    return _shops.fold<int>(
      0,
      (total, shop) => total + shop.montant,
    );
  }

  int get _remise {
    return int.tryParse(
          _remiseController.text
              .replaceAll(' ', '')
              .replaceAll(',', ''),
        ) ??
        0;
  }

  int get _livraison {
    return widget.commande.livraison;
  }

  int get _total {
    final total = _montant - _remise + _livraison;

    return total < 0 ? 0 : total;
  }

  int get _nombreProduits {
    return _shops.length;
  }

  @override
  void initState() {
    super.initState();

    _numeroController.text = widget.commande.idLocal;
    _nomController.text = widget.commande.nom;
    _telephoneController.text = widget.commande.telephone;
    _remiseController.text = widget.commande.remise.toString();

    _chargerDonnees();

    HardwareKeyboard.instance.addHandler(
      _gererEvenementScanner,
    );
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _nomController.dispose();
    _telephoneController.dispose();
    _remiseController.dispose();

    HardwareKeyboard.instance.removeHandler(
      _gererEvenementScanner,
    );

    _timerScanner?.cancel();

    super.dispose();
  }

  // ============================================================
  // SCANNER USB
  // ============================================================

  bool _gererEvenementScanner(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    final maintenant = DateTime.now();

    if (_dernierCaractereScanner != null) {
      final delai = maintenant.difference(
        _dernierCaractereScanner!,
      );

      if (delai.inMilliseconds > 120) {
        _bufferScanner = '';
      }
    }

    _dernierCaractereScanner = maintenant;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _bufferScanner.trim();

      _bufferScanner = '';
      _timerScanner?.cancel();

      if (code.isNotEmpty) {
        _traiterScanProduit(code);
      }

      return true;
    }

    final caractere = event.character;

    if (caractere == null || caractere.isEmpty) {
      return false;
    }

    _bufferScanner += caractere;

    _timerScanner?.cancel();

    _timerScanner = Timer(
      const Duration(milliseconds: 180),
      () {
        _bufferScanner = '';
      },
    );

    return false;
  }

  Future<void> _traiterScanProduit(String code) async {
    if (_traitementScan ||
        _chargement ||
        _operationEnCours) {
      return;
    }

    final codeNettoye = code.trim();

    if (codeNettoye.isEmpty) {
      return;
    }

    setState(() {
      _traitementScan = true;
    });

    try {
      final sousProduit =
          _trouverSousProduitScanne(codeNettoye);

      if (sousProduit == null) {
        _afficherErreur(
          'Sous-produit introuvable pour le code scanné : $codeNettoye',
        );
        return;
      }

      final produit =
          _produitsParId[sousProduit.produitId];

      if (produit == null) {
        _afficherErreur(
          'Le produit associé au sous-produit scanné est introuvable.',
        );
        return;
      }

      final selection =
          _ProduitCommandeSelection(
        sousProduit: sousProduit,
        quantite: 1,
        prix: produit.prixActuel,
      );

      await _ajouterShop(selection);
    } finally {
      if (mounted) {
        setState(() {
          _traitementScan = false;
        });
      }
    }
  }

  SousProduit? _trouverSousProduitScanne(String code) {
    final recherche = code.trim().toLowerCase();

    if (recherche.isEmpty) {
      return null;
    }

    for (final sousProduit in _sousProduitsDisponibles) {
      if (sousProduit.identifiant.trim().toLowerCase() ==
          recherche) {
        return sousProduit;
      }

      final numero =
          sousProduit.numero?.trim().toLowerCase();

      if (numero != null &&
          numero.isNotEmpty &&
          numero == recherche) {
        return sousProduit;
      }

      if (sousProduit.id.toString() == recherche) {
        return sousProduit;
      }
    }

    return null;
  }

  // ============================================================
  // CHARGEMENT
  // ============================================================

  Future<void> _chargerDonnees() async {
    final commandeId = widget.commande.id;

    if (commandeId == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _chargement = false;
        _erreur =
            'Cette commande ne possède pas d’identifiant local.';
      });

      return;
    }

    try {
      final produits =
          await _produitRepository.obtenirTous();

      final sousProduits =
          await _sousProduitRepository.obtenirTous();

      final shops =
          await _commandeRepository
              .obtenirShopsParCommande(
        commandeId,
      );

      final shopsModel =
          shops.map(Shop.fromMap).toList();

      _produitsParId.clear();
      _sousProduitsParId.clear();
      _stocksParSousProduit.clear();

      for (final produit in produits) {
        _produitsParId[produit.id] = produit;
      }

      for (final sousProduit in sousProduits) {
        _sousProduitsParId[sousProduit.id] =
            sousProduit;
      }

      final pointDeVenteId =
          await _obtenirPointDeVenteId();

      for (final shop in shopsModel) {
        final articleId = shop.articleId;

        if (articleId == null) {
          continue;
        }

        final sousProduit =
            _sousProduitsParId[articleId];

        if (sousProduit == null) {
          continue;
        }

        final stock =
            await _stockRepository
                .obtenirParPointVenteEtSousProduit(
          pointDeVenteId: pointDeVenteId,
          sousProduitId: sousProduit.id,
        );

        _stocksParSousProduit[
            sousProduit.id] = stock;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _sousProduitsDisponibles =
            sousProduits;

        _shops = shopsModel;

        _chargement = false;

        _erreur = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _chargement = false;
        _erreur =
            'Impossible de charger le détail de la commande.';
      });

      _afficherErreur(
        'Impossible de charger le détail de la commande.',
      );
    }
  }

  Future<int> _obtenirPointDeVenteId() async {
    final session =
        await Session.fromPreferences();

    if (session == null) {
      throw const CaisseTransactionException(
        'La session de l’utilisateur connecté est introuvable.',
      );
    }

    final pointDeVenteId =
        session.pointVenteId;

    if (pointDeVenteId == null) {
      throw const CaisseTransactionException(
        'Le point de vente de l’utilisateur connecté est introuvable.',
      );
    }

    return pointDeVenteId;
  }

  Future<void> _rechargerDonnees() async {
    final commandeId = widget.commande.id;

    if (!mounted || commandeId == null) {
      return;
    }

    try {
      final shops =
          await _commandeRepository
              .obtenirShopsParCommande(
        commandeId,
      );

      final shopsModel =
          shops.map(Shop.fromMap).toList();

      final nouveauxSousProduits =
          <int, SousProduit>{};

      final nouveauxStocks =
          <int, Stock?>{};

      final pointDeVenteId =
          await _obtenirPointDeVenteId();

      for (final shop in shopsModel) {
        final articleId = shop.articleId;

        if (articleId == null) {
          continue;
        }

        final sousProduit =
            await _sousProduitRepository
                .obtenirParId(
          articleId,
        );

        if (sousProduit == null) {
          continue;
        }

        nouveauxSousProduits[
            sousProduit.id] = sousProduit;

        final stock =
            await _stockRepository
                .obtenirParPointVenteEtSousProduit(
          pointDeVenteId: pointDeVenteId,
          sousProduitId: sousProduit.id,
        );

        nouveauxStocks[
            sousProduit.id] = stock;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _shops = shopsModel;

        _sousProduitsParId
          ..clear()
          ..addAll(nouveauxSousProduits);

        _stocksParSousProduit
          ..clear()
          ..addAll(nouveauxStocks);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(
        'Impossible de recharger la commande.',
      );
    }
  }

  // ============================================================
  // AJOUTER UN SHOP
  // ============================================================

  Future<void> _ouvrirPopupAjouterAchat() async {
    if (_operationEnCours) {
      return;
    }

    final resultat =
        await showDialog<_ProduitCommandeSelection>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _AjouterAchatDialog(
          sousProduits:
              _sousProduitsDisponibles,
          produitsParId:
              _produitsParId,
        );
      },
    );

    if (resultat == null) {
      return;
    }

    await _ajouterShop(resultat);
  }

  Future<void> _ajouterShop(
    _ProduitCommandeSelection selection,
  ) async {
    final commandeId =
        widget.commande.id;

    if (commandeId == null) {
      _afficherErreur(
        'La commande ne possède pas d’identifiant local.',
      );

      return;
    }

    setState(() {
      _operationEnCours = true;
    });

    try {
      await _commandeRepository.ajouterShop(
        commandeId: commandeId,
        articleId:
            selection.sousProduit.id,
        quantite:
            selection.quantite,
        couleur:
            selection.sousProduit.couleur,
        pointure:
            selection.sousProduit.pointure,
        prix:
            selection.prix,
        statut: 'valide',
      );

      await _rechargerDonnees();

      if (!mounted) {
        return;
      }

      _afficherSucces(
        'Produit ajouté à la commande.',
      );
    } on StockIntrouvableException catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(e.message);
    } on CaisseTransactionException catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(
        'Impossible d’ajouter le produit à la commande.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _operationEnCours = false;
        });
      }
    }
  }

  // ============================================================
  // SUPPRIMER UN SHOP
  // ============================================================

  Future<void> _supprimerShop(
    Shop shop,
  ) async {
    final shopId = shop.id;

    if (shopId == null) {
      return;
    }

    final confirmer =
        await _afficherConfirmation(
      titre: 'Confirmer la suppression',
      message:
          'Sûr de vouloir supprimer ce produit de la commande ?',
      texteAction: 'Confirmer',
      danger: true,
    );

    if (!confirmer) {
      return;
    }

    setState(() {
      _operationEnCours = true;
    });

    try {
      await _commandeRepository
          .supprimerShopEtRestaurerStock(
        shopId: shopId,
      );

      await _rechargerDonnees();

      if (!mounted) {
        return;
      }

      _afficherSucces(
        'Produit supprimé et stock restauré.',
      );
    } on StockIntrouvableException catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(e.message);
    } on CaisseTransactionException catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(
        'Impossible de supprimer le produit.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _operationEnCours = false;
        });
      }
    }
  }

  // ============================================================
  // ENREGISTRER LES INFORMATIONS
  // ============================================================

  Future<void> _validerCommande() async {
    if (_operationEnCours) {
      return;
    }

    final commandeId =
        widget.commande.id;

    if (commandeId == null) {
      _afficherErreur(
        'La commande ne possède pas d’identifiant local.',
      );

      return;
    }

    final nom =
        _nomController.text.trim();

    final telephone =
        _telephoneController.text.trim();

    final remise =
        int.tryParse(
          _remiseController.text
              .replaceAll(' ', '')
              .replaceAll(',', ''),
        ) ??
        0;

    if (nom.isEmpty) {
      _afficherErreur(
        'Le nom du client est obligatoire.',
      );

      return;
    }

    if (telephone.isEmpty) {
      _afficherErreur(
        'Le téléphone du client est obligatoire.',
      );

      return;
    }

    if (remise < 0) {
      _afficherErreur(
        'La remise ne peut pas être négative.',
      );

      return;
    }

    final confirmer =
        await _afficherConfirmation(
      titre: 'Confirmation',
      message:
          'Sûr de vouloir valider cette commande ?',
      texteAction: 'Confirmer',
    );

    if (!confirmer) {
      return;
    }

    setState(() {
      _operationEnCours = true;
    });

    try {
      await _commandeRepository
          .mettreAJourInformations(
        commandeId: commandeId,
        nom: nom,
        telephone: telephone,
        remise: remise,
      );

      await _rechargerDonnees();

      if (!mounted) {
        return;
      }

      _afficherSucces(
        'Commande mise à jour.',
      );
    } on CaisseTransactionException catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(
        'Impossible de mettre à jour la commande.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _operationEnCours = false;
        });
      }
    }
  }

  // ============================================================
  // SUPPRIMER LA COMMANDE
  // ============================================================

  Future<void> _supprimerCommande() async {
    if (_operationEnCours) {
      return;
    }

    final commandeId =
        widget.commande.id;

    if (commandeId == null) {
      _afficherErreur(
        'La commande ne possède pas d’identifiant local.',
      );

      return;
    }

    final confirmer =
        await _afficherConfirmation(
      titre: 'Confirmer la suppression',
      message:
          'Sûr de vouloir supprimer cette commande ?',
      texteAction: 'Confirmer',
      danger: true,
    );

    if (!confirmer) {
      return;
    }

    setState(() {
      _operationEnCours = true;
    });

    try {
      await _commandeRepository
          .supprimerAvecRestaurationStock(
        commandeId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on StockIntrouvableException catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(e.message);
    } on CaisseTransactionException catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _afficherErreur(
        'Impossible de supprimer la commande.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _operationEnCours = false;
        });
      }
    }
  }

  // ============================================================
  // FACTURE
  // ============================================================

  void _ouvrirFacture() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La génération de la facture sera disponible prochainement.',
        ),
      ),
    );
  }

  // ============================================================
  // DIALOGUE CONFIRMATION
  // ============================================================

  Future<bool> _afficherConfirmation({
    required String titre,
    required String message,
    required String texteAction,
    bool danger = false,
  }) async {
    final resultat =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 430,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(
                          color: danger
                              ? Colors.red
                                  .withValues(
                                  alpha: 0.08,
                                )
                              : Couleurs
                                  .primaire
                                  .withValues(
                                  alpha: 0.08,
                                ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                        child: Icon(
                          danger
                              ? Icons
                                  .delete_outline_rounded
                              : Icons
                                  .help_outline_rounded,
                          color: danger
                              ? Colors.red
                                  .shade600
                              : Couleurs
                                  .primaire,
                          size: 21,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Text(
                          titre,
                          style:
                              const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color:
                          Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop(false);
                        },
                        style:
                            TextButton.styleFrom(
                          foregroundColor:
                              Colors.grey
                                  .shade700,
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        child:
                            const Text(
                          'Annuler',
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop(true);
                        },
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              danger
                                  ? Colors
                                      .red
                                      .shade600
                                  : Couleurs
                                      .primaire,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              8,
                            ),
                          ),
                        ),
                        child: Text(
                          texteAction,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return resultat ?? false;
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  void _afficherErreur(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              Colors.red.shade700,
        ),
      );
  }

  void _afficherSucces(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // FORMATAGE
  // ============================================================

  String _formaterMontant(
    int montant,
  ) {
    final texte =
        montant.toString();

    final buffer =
        StringBuffer();

    for (
      int i = 0;
      i < texte.length;
      i++
    ) {
      final position =
          texte.length - i;

      buffer.write(
        texte[i],
      );

      if (
          position > 1 &&
          position % 3 == 1) {
        buffer.write(' ');
      }
    }

    return buffer.toString();
  }

  String _obtenirNomProduit(
    Shop shop,
  ) {
    final articleId =
        shop.articleId;

    if (articleId == null) {
      return 'Produit inconnu';
    }

    final sousProduit =
        _sousProduitsParId[articleId];

    if (sousProduit == null) {
      return 'Produit inconnu';
    }

    final produit =
        _produitsParId[
            sousProduit.produitId];

    if (produit == null) {
      return 'Produit inconnu';
    }

    return produit.nom;
  }

  String _obtenirCodeProduit(
    Shop shop,
  ) {
    final articleId =
        shop.articleId;

    if (articleId == null) {
      return '-';
    }

    final sousProduit =
        _sousProduitsParId[articleId];

    if (sousProduit == null) {
      return '-';
    }

    final identifiant =
        sousProduit.identifiant.trim();

    if (identifiant.isNotEmpty) {
      return identifiant;
    }

    final numero =
        sousProduit.numero;

    if (numero != null &&
        numero.trim().isNotEmpty) {
      return numero;
    }

    return '-';
  }

  int _obtenirStock(
    Shop shop,
  ) {
    final articleId =
        shop.articleId;

    if (articleId == null) {
      return 0;
    }

    final stock =
        _stocksParSousProduit[
            articleId];

    if (stock == null) {
      return 0;
    }

    return stock.quantite;
  }

  String _obtenirVariante(
    Shop shop,
  ) {
    final elements =
        <String>[];

    if (shop.couleur
        .trim()
        .isNotEmpty) {
      elements.add(
        shop.couleur,
      );
    }

    if (shop.pointure
        .trim()
        .isNotEmpty) {
      elements.add(
        shop.pointure,
      );
    }

    if (elements.isEmpty) {
      return '-';
    }

    return elements.join(
      ' / ',
    );
  }

  Color _couleurStock(
    int stock,
  ) {
    if (stock <= 0) {
      return Colors.red.shade600;
    }

    if (stock <= 5) {
      return Colors.orange.shade700;
    }

    return Colors.green.shade600;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Couleurs.fond,
      body: SafeArea(
        child:
            _construireContenu(),
      ),
    );
  }

  Widget _construireContenu() {
    if (_chargement) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_erreur != null &&
        _shops.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .error_outline_rounded,
              size: 44,
              color:
                  Colors.red.shade400,
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              _erreur!,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 14,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            ElevatedButton.icon(
              onPressed:
                  _chargerDonnees,
              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
              ),
              label:
                  const Text(
                'Réessayer',
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final largeur =
            constraints.maxWidth;

        return SingleChildScrollView(
          padding:
              EdgeInsets.all(
            largeur <= 768
                ? 16
                : 24,
          ),
          child: Column(
            children: [
              _construireEntete(),
              const SizedBox(
                height: 24,
              ),
              _construireCarteInformations(),
              const SizedBox(
                height: 24,
              ),
              _construireSectionProduitsEtResume(
                largeur,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // ENTETE
  // ============================================================

  Widget _construireEntete() {
    return Stack(
      alignment:
          Alignment.center,
      children: [
        Align(
          alignment:
              Alignment.centerLeft,
          child: IconButton(
            onPressed:
                _operationEnCours
                    ? null
                    : () {
                        Navigator.of(
                          context,
                        ).pop();
                      },
            tooltip:
                'Retour',
            icon:
                const Icon(
              Icons
                  .arrow_back_rounded,
              size: 22,
            ),
          ),
        ),
        Column(
          children: [
            const Text(
              'Détail commande',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 34,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xff1d1d1f),
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              'Gérez votre commande',
              style: TextStyle(
                fontSize: 14,
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // INFORMATIONS
  // ============================================================

  Widget _construireCarteInformations() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xffe5e5ea),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons
                    .manage_accounts_outlined,
                size: 20,
                color:
                    Couleurs.primaire,
              ),
              const SizedBox(
                width: 8,
              ),
              const Text(
                'Informations de la commande',
                style:
                    TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 22,
          ),
          LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final largeur =
                  constraints.maxWidth;

              if (largeur < 800) {
                return Column(
                  children: [
                    _construireChamp(
                      label:
                          'Numéro de commande',
                      controller:
                          _numeroController,
                      enabled: false,
                      icon: Icons
                          .receipt_long_outlined,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    _construireChamp(
                      label:
                          'Nom & Prénom',
                      controller:
                          _nomController,
                      icon: Icons
                          .person_outline_rounded,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    _construireChamp(
                      label:
                          'Téléphone',
                      controller:
                          _telephoneController,
                      icon: Icons
                          .phone_outlined,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    _construireChamp(
                      label:
                          'Remise',
                      controller:
                          _remiseController,
                      keyboardType:
                          TextInputType.number,
                      icon: Icons
                          .discount_outlined,
                      suffixText:
                          'FCFA',
                      onChanged:
                          (_) {
                        setState(
                          () {},
                        );
                      },
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Expanded(
                    child:
                        _construireChamp(
                      label:
                          'Numéro de commande',
                      controller:
                          _numeroController,
                      enabled: false,
                      icon: Icons
                          .receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child:
                        _construireChamp(
                      label:
                          'Nom & Prénom',
                      controller:
                          _nomController,
                      icon: Icons
                          .person_outline_rounded,
                    ),
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child:
                        _construireChamp(
                      label:
                          'Téléphone',
                      controller:
                          _telephoneController,
                      icon: Icons
                          .phone_outlined,
                    ),
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child:
                        _construireChamp(
                      label:
                          'Remise',
                      controller:
                          _remiseController,
                      keyboardType:
                          TextInputType.number,
                      icon: Icons
                          .discount_outlined,
                      suffixText:
                          'FCFA',
                      onChanged:
                          (_) {
                        setState(
                          () {},
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(
            height: 20,
          ),
          SizedBox(
            width: 190,
            height: 45,
            child:
                ElevatedButton.icon(
              onPressed:
                  _operationEnCours
                      ? null
                      : _validerCommande,
              icon:
                  const Icon(
                Icons
                    .check_rounded,
                size: 18,
              ),
              label:
                  const Text(
                'Valider',
              ),
              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    Colors.green
                        .shade600,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construireChamp({
    required String label,
    required TextEditingController
        controller,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? suffixText,
    ValueChanged<String>?
        onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color:
                Colors.grey.shade700,
            fontWeight:
                FontWeight.w600,
          ),
        ),
        const SizedBox(
          height: 7,
        ),
        TextField(
          controller:
              controller,
          enabled:
              enabled,
          keyboardType:
              keyboardType,
          onChanged:
              onChanged,
          style:
              const TextStyle(
            fontSize: 13,
          ),
          decoration:
              InputDecoration(
            prefixIcon:
                Icon(
              icon,
              size: 19,
              color:
                  Colors.grey.shade600,
            ),
            suffixText:
                suffixText,
            filled: true,
            fillColor:
                enabled
                    ? Colors.white
                    : Colors.grey.shade100,
            contentPadding:
                const EdgeInsets
                    .symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(0xffe5e5ea),
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(0xffe5e5ea),
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              borderSide:
                  BorderSide(
                color:
                    Couleurs.primaire,
              ),
            ),
            disabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(0xffe5e5ea),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PRODUITS + RESUME
  // ============================================================

  Widget _construireSectionProduitsEtResume(
    double largeur,
  ) {
    if (largeur <= 992) {
      return Column(
        children: [
          _construireCarteProduits(),
          const SizedBox(
            height: 20,
          ),
          _construireResume(),
        ],
      );
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 8,
          child:
              _construireCarteProduits(),
        ),
        const SizedBox(
          width: 20,
        ),
        Expanded(
          flex: 4,
          child:
              _construireResume(),
        ),
      ],
    );
  }

  // ============================================================
  // PRODUITS
  // ============================================================

  Widget _construireCarteProduits() {
    return Container(
      width:
          double.infinity,
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xffe5e5ea),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                if (constraints.maxWidth <
                    600) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons
                                .shopping_basket_outlined,
                            size: 19,
                            color:
                                Couleurs
                                    .primaire,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          const Expanded(
                            child: Text(
                              'Produits',
                              style:
                                  TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                          ),
                          _construireBadgeNombreProduits(),
                        ],
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            _construireBoutonAjouter(),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Icon(
                      Icons
                          .shopping_basket_outlined,
                      size: 19,
                      color:
                          Couleurs
                              .primaire,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    const Text(
                      'Produits',
                      style:
                          TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    _construireBadgeNombreProduits(),
                    const Spacer(),
                    _construireBoutonAjouter(),
                  ],
                );
              },
            ),
          ),
          const Divider(
            height: 1,
          ),
          if (_shops.isEmpty)
            _construireEtatVideProduits()
          else
            _construireTableProduits(),
        ],
      ),
    );
  }

  Widget _construireBadgeNombreProduits() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color: const Color(
          0xfff1f3f7,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        '$_nombreProduits produit${_nombreProduits > 1 ? 's' : ''}',
        style: TextStyle(
          fontSize: 11,
          color:
              Colors.grey.shade700,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }

  Widget _construireBoutonAjouter() {
    return SizedBox(
      height: 42,
      child:
          ElevatedButton.icon(
        onPressed:
            _operationEnCours
                ? null
                : _ouvrirPopupAjouterAchat,
        icon:
            const Icon(
          Icons.add_rounded,
          size: 18,
        ),
        label:
            const Text(
          'Ajouter un achat',
        ),
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              Couleurs.primaire,
          foregroundColor:
              Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 18,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _construireEtatVideProduits() {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration:
                  BoxDecoration(
                color: Colors.grey
                    .shade100,
                shape:
                    BoxShape.circle,
              ),
              child: Icon(
                Icons
                    .shopping_basket_outlined,
                size: 27,
                color:
                    Colors.grey.shade400,
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              'Aucun produit',
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w600,
                color:
                    Colors.grey.shade700,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Text(
              'Ajoutez un produit pour commencer la commande.',
              style: TextStyle(
                fontSize: 12,
                color:
                    Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construireTableProduits() {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        return SingleChildScrollView(
          scrollDirection:
              Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < 700
                ? 700
                : constraints.maxWidth,
            child: Column(
              children: [
                _construireEnteteTable(),
                ..._shops.map(
                  _construireLigneProduit,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _construireEnteteTable() {
    return Container(
      height: 52,
      color:
          const Color(0xfff7f8fa),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Produits',
              style:
                  TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xff6e6e73),
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Prix unitaire',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xff6e6e73),
              ),
            ),
          ),
          const Expanded(
            flex: 1,
            child: Text(
              'Quantité',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xff6e6e73),
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Total',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xff6e6e73),
              ),
            ),
          ),
          const Expanded(
            flex: 1,
            child: Text(
              'Stock',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xff6e6e73),
              ),
            ),
          ),
          const SizedBox(
            width: 54,
            child: Text(''),
          ),
        ],
      ),
    );
  }

  Widget _construireLigneProduit(
    Shop shop,
  ) {
    final nomProduit =
        _obtenirNomProduit(shop);

    final codeProduit =
        _obtenirCodeProduit(shop);

    final variante =
        _obtenirVariante(shop);

    final stock =
        _obtenirStock(shop);

    return Container(
      height: 67,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration:
          const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Color(0xffeeeeee),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  nomProduit,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  '$codeProduit • $variante',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${_formaterMontant(shop.prix)} FCFA',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              shop.quantite.toString(),
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${_formaterMontant(shop.montant)} FCFA',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              stock.toString(),
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color:
                    _couleurStock(stock),
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 54,
            child: Center(
              child: SizedBox(
                width: 34,
                height: 34,
                child:
                    IconButton(
                  tooltip:
                      'Annuler',
                  padding:
                      EdgeInsets.zero,
                  onPressed:
                      _operationEnCours
                          ? null
                          : () {
                              _supprimerShop(
                                shop,
                              );
                            },
                  style:
                      IconButton.styleFrom(
                    backgroundColor:
                        Colors.red
                            .withValues(
                      alpha: 0.08,
                    ),
                    foregroundColor:
                        Colors.red
                            .shade600,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        7,
                      ),
                    ),
                  ),
                  icon:
                      const Icon(
                    Icons.close_rounded,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESUME
  // ============================================================

  Widget _construireResume() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xffe5e5ea),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons
                    .receipt_long_outlined,
                size: 20,
                color:
                    Couleurs.primaire,
              ),
              const SizedBox(
                width: 8,
              ),
              const Text(
                'Commande',
                style:
                    TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 24,
          ),
          _construireLigneResume(
            'Date de création',
            _formaterDate(
              widget.commande
                  .dateCreation,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          _construireLigneResume(
            'Montant',
            '${_formaterMontant(_montant)} FCFA',
          ),
          const SizedBox(
            height: 14,
          ),
          _construireLigneResume(
            'Remise',
            '${_formaterMontant(_remise)} FCFA',
          ),
          const SizedBox(
            height: 18,
          ),
          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xfff7f8fa),
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total',
                    style:
                        TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_formaterMontant(_total)} FCFA',
                  style:
                      TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Couleurs.primaire,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 22,
          ),
          Row(
            children: [
              Expanded(
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _operationEnCours
                          ? null
                          : _ouvrirFacture,
                  icon:
                      const Icon(
                    Icons
                        .receipt_long_outlined,
                    size: 17,
                  ),
                  label:
                      const Text(
                    'Facture',
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Couleurs
                            .primaire,
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    minimumSize:
                        const Size(
                      0,
                      42,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _operationEnCours
                          ? null
                          : _supprimerCommande,
                  icon:
                      const Icon(
                    Icons
                        .delete_outline_rounded,
                    size: 17,
                  ),
                  label:
                      const Text(
                    'Supprimer',
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors.red
                            .shade600,
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    minimumSize:
                        const Size(
                      0,
                      42,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construireLigneResume(
    String libelle,
    String valeur,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            libelle,
            style: TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(
          width: 12,
        ),
        Flexible(
          child: Text(
            valeur,
            textAlign:
                TextAlign.right,
            style:
                const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formaterDate(
    DateTime date,
  ) {
    final jour =
        date.day.toString().padLeft(
              2,
              '0',
            );

    final mois =
        date.month.toString().padLeft(
              2,
              '0',
            );

    final annee =
        date.year.toString();

    final heure =
        date.hour.toString().padLeft(
              2,
              '0',
            );

    final minute =
        date.minute.toString().padLeft(
              2,
              '0',
            );

    return '$jour/$mois/$annee à $heure:$minute';
  }
}

// ============================================================================
// SELECTION D'UN SOUS-PRODUIT
// ============================================================================

class _ProduitCommandeSelection {
  final SousProduit sousProduit;
  final int quantite;
  final int prix;

  const _ProduitCommandeSelection({
    required this.sousProduit,
    required this.quantite,
    required this.prix,
  });
}

// ============================================================================
// POPUP AJOUTER ACHAT
// ============================================================================

class _AjouterAchatDialog
    extends StatefulWidget {
  final List<SousProduit> sousProduits;
  final Map<int, Produit> produitsParId;

  const _AjouterAchatDialog({
    required this.sousProduits,
    required this.produitsParId,
  });

  @override
  State<_AjouterAchatDialog> createState() =>
      _AjouterAchatDialogState();
}

class _AjouterAchatDialogState
    extends State<_AjouterAchatDialog> {
  final TextEditingController
      _rechercheController =
      TextEditingController();

  final TextEditingController
      _quantiteController =
      TextEditingController(
    text: '1',
  );

  SousProduit? _sousProduitSelectionne;

  String _recherche = '';

  @override
  void dispose() {
    _rechercheController.dispose();
    _quantiteController.dispose();

    super.dispose();
  }

  // ============================================================
  // FILTRE
  // ============================================================

  List<SousProduit>
      get _sousProduitsFiltres {
    final recherche =
        _recherche.trim().toLowerCase();

    final sousProduitsActifs =
        widget.sousProduits.where(
      (sousProduit) {
        final actif =
            sousProduit.actif
                .trim()
                .toLowerCase();

        return actif.isEmpty ||
            actif == 'oui' ||
            actif == 'true' ||
            actif == '1';
      },
    ).toList();

    if (recherche.isEmpty) {
      return sousProduitsActifs;
    }

    return sousProduitsActifs.where(
      (sousProduit) {
        final produit =
            widget.produitsParId[
                sousProduit.produitId];

        final nomProduit =
            produit?.nom
                .toLowerCase() ??
            '';

        final couleur =
            sousProduit.couleur
                .toLowerCase();

        final pointure =
            sousProduit.pointure
                .toLowerCase();

        final identifiant =
            sousProduit.identifiant
                .toLowerCase();

        final numero =
            sousProduit.numero
                    ?.toLowerCase() ??
                '';

        return nomProduit.contains(
                  recherche,
                ) ||
            couleur.contains(
              recherche,
            ) ||
            pointure.contains(
              recherche,
            ) ||
            identifiant.contains(
              recherche,
            ) ||
            numero.contains(
              recherche,
            ) ||
            sousProduit.id
                .toString()
                .contains(
                  recherche,
                );
      },
    ).toList();
  }

  // ============================================================
  // INFORMATIONS
  // ============================================================

  String _obtenirNomProduit(
    SousProduit sousProduit,
  ) {
    final produit =
        widget.produitsParId[
            sousProduit.produitId];

    if (produit == null) {
      return 'Produit inconnu';
    }

    return produit.nom;
  }

  String _descriptionSousProduit(
    SousProduit sousProduit,
  ) {
    final elements =
        <String>[];

    if (sousProduit.couleur
        .trim()
        .isNotEmpty) {
      elements.add(
        sousProduit.couleur,
      );
    }

    if (sousProduit.pointure
        .trim()
        .isNotEmpty) {
      elements.add(
        sousProduit.pointure,
      );
    }

    if (sousProduit.identifiant
        .trim()
        .isNotEmpty) {
      elements.add(
        sousProduit.identifiant,
      );
    }

    if (elements.isEmpty) {
      return 'Sous-produit #${sousProduit.id}';
    }

    return elements.join(
      ' • ',
    );
  }

  String _obtenirCodeSousProduit(
    SousProduit sousProduit,
  ) {
    final identifiant =
        sousProduit.identifiant.trim();

    if (identifiant.isNotEmpty) {
      return identifiant;
    }

    final numero =
        sousProduit.numero;

    if (numero != null &&
        numero.trim().isNotEmpty) {
      return numero;
    }

    return 'ID ${sousProduit.id}';
  }

  int _obtenirPrix(
    SousProduit sousProduit,
  ) {
    final produit =
        widget.produitsParId[
            sousProduit.produitId];

    if (produit == null) {
      return 0;
    }

    return produit.prixActuel;
  }

  String _formaterMontant(
    int montant,
  ) {
    final texte =
        montant.toString();

    final buffer =
        StringBuffer();

    for (
      int i = 0;
      i < texte.length;
      i++
    ) {
      final position =
          texte.length - i;

      buffer.write(
        texte[i],
      );

      if (
          position > 1 &&
          position % 3 == 1) {
        buffer.write(' ');
      }
    }

    return buffer.toString();
  }

  // ============================================================
  // SELECTION
  // ============================================================

  void _selectionnerSousProduit(
    SousProduit sousProduit,
  ) {
    setState(() {
      _sousProduitSelectionne =
          sousProduit;
    });
  }

  // ============================================================
  // CONFIRMATION
  // ============================================================

  void _confirmer() {
    final sousProduit =
        _sousProduitSelectionne;

    final quantite =
        int.tryParse(
          _quantiteController.text
              .trim(),
        );

    if (sousProduit == null) {
      _afficherErreur(
        'Veuillez sélectionner un sous-produit.',
      );

      return;
    }

    if (quantite == null ||
        quantite < 1) {
      _afficherErreur(
        'La quantité doit être supérieure à 0.',
      );

      return;
    }

    final produit =
        widget.produitsParId[
            sousProduit.produitId];

    if (produit == null) {
      _afficherErreur(
        'Le produit associé à ce sous-produit est introuvable.',
      );

      return;
    }

    Navigator.of(context).pop(
      _ProduitCommandeSelection(
        sousProduit:
            sousProduit,
        quantite:
            quantite,
        prix:
            produit.prixActuel,
      ),
    );
  }

  // ============================================================
  // ERREUR
  // ============================================================

  void _afficherErreur(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(message),
          backgroundColor:
              Colors.red.shade700,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final sousProduit =
        _sousProduitSelectionne;

    final prix =
        sousProduit == null
            ? 0
            : _obtenirPrix(
                sousProduit,
              );

    final quantite =
        int.tryParse(
              _quantiteController.text
                  .trim(),
            ) ??
            0;

    final montant =
        prix * quantite;

    return Dialog(
      backgroundColor:
          Colors.white,
      insetPadding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ),
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 850,
          maxHeight: 700,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              // --------------------------------------------------
              // TITRE
              // --------------------------------------------------

              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                        BoxDecoration(
                      color: Couleurs
                          .primaire
                          .withValues(
                        alpha: 0.08,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        9,
                      ),
                    ),
                    child:
                        Icon(
                      Icons
                          .shopping_basket_outlined,
                      color:
                          Couleurs
                              .primaire,
                      size: 21,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  const Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Ajouter un achat',
                          style:
                              TextStyle(
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                        SizedBox(
                          height: 3,
                        ),
                        Text(
                          'Sélectionnez un sous-produit et indiquez la quantité.',
                          style:
                              TextStyle(
                            fontSize:
                                12,
                            color:
                                Color(
                              0xff6e6e73,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    tooltip:
                        'Fermer',
                    icon:
                        const Icon(
                      Icons
                          .close_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              // --------------------------------------------------
              // RECHERCHE
              // --------------------------------------------------

              TextField(
                controller:
                    _rechercheController,
                onChanged:
                    (value) {
                  setState(() {
                    _recherche =
                        value;
                  });
                },
                decoration:
                    InputDecoration(
                  hintText:
                      'Rechercher un produit, une couleur, une pointure ou un code...',
                  prefixIcon:
                      const Icon(
                    Icons
                        .search_rounded,
                    size: 20,
                  ),
                  filled: true,
                  fillColor:
                      const Color(
                    0xfff7f8fa,
                  ),
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      8,
                    ),
                    borderSide:
                        const BorderSide(
                      color:
                          Color(
                        0xffe5e5ea,
                      ),
                    ),
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      8,
                    ),
                    borderSide:
                        const BorderSide(
                      color:
                          Color(
                        0xffe5e5ea,
                      ),
                    ),
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      8,
                    ),
                    borderSide:
                        BorderSide(
                      color:
                          Couleurs
                              .primaire,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              // --------------------------------------------------
              // LISTE DES SOUS-PRODUITS
              // --------------------------------------------------

              Expanded(
                child:
                    _construireListeSousProduits(),
              ),

              const SizedBox(
                height: 16,
              ),

              // --------------------------------------------------
              // SELECTION + QUANTITE + MONTANT
              // --------------------------------------------------

              if (sousProduit != null)
                _construireSelection(
                  sousProduit,
                  prix,
                  quantite,
                  montant,
                ),

              const SizedBox(
                height: 18,
              ),

              // --------------------------------------------------
              // ACTIONS
              // --------------------------------------------------

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    style:
                        TextButton.styleFrom(
                      foregroundColor:
                          Colors.grey
                              .shade700,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child:
                        const Text(
                      'Annuler',
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        _confirmer,
                    icon:
                        const Icon(
                      Icons
                          .check_rounded,
                      size: 18,
                    ),
                    label:
                        const Text(
                      'Confirmer',
                    ),
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          Couleurs
                              .primaire,
                      foregroundColor:
                          Colors.white,
                      elevation: 0,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construireListeSousProduits() {
    final produits =
        _sousProduitsFiltres;

    if (produits.isEmpty) {
      return Container(
        width:
            double.infinity,
        decoration:
            BoxDecoration(
          color:
              const Color(0xfff7f8fa),
          borderRadius:
              BorderRadius.circular(
            8,
          ),
          border:
              Border.all(
            color:
                const Color(0xffe5e5ea),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons
                    .inventory_2_outlined,
                size: 35,
                color:
                    Colors.grey.shade400,
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                'Aucun sous-produit trouvé.',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration:
          BoxDecoration(
        border:
            Border.all(
          color:
              const Color(0xffe5e5ea),
        ),
        borderRadius:
            BorderRadius.circular(
          8,
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 14,
            ),
            decoration:
                const BoxDecoration(
              color:
                  Color(0xfff7f8fa),
              borderRadius:
                  BorderRadius.only(
                topLeft:
                    Radius.circular(
                  8,
                ),
                topRight:
                    Radius.circular(
                  8,
                ),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Produit',
                    style:
                        TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(
                        0xff6e6e73,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Code',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(
                        0xff6e6e73,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Prix',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(
                        0xff6e6e73,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 42,
                ),
              ],
            ),
          ),
          Expanded(
            child:
                ListView.separated(
              itemCount:
                  produits.length,
              separatorBuilder:
                  (_, __) =>
                      const Divider(
                height: 1,
              ),
              itemBuilder:
                  (
                context,
                index,
              ) {
                final sousProduit =
                    produits[index];

                final produit =
                    widget
                        .produitsParId[
                            sousProduit
                                .produitId];

                final selectionne =
                    _sousProduitSelectionne
                            ?.id ==
                        sousProduit.id;

                final prix =
                    produit
                            ?.prixActuel ??
                        0;

                return InkWell(
                  onTap: () {
                    _selectionnerSousProduit(
                      sousProduit,
                    );
                  },
                  child:
                      Container(
                    constraints:
                        const BoxConstraints(
                      minHeight:
                          62,
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    color: selectionne
                        ? Couleurs
                            .primaire
                            .withValues(
                            alpha:
                                0.05,
                          )
                        : Colors.white,
                    child:
                        Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child:
                              Row(
                            children: [
                              Icon(
                                selectionne
                                    ? Icons
                                        .radio_button_checked_rounded
                                    : Icons
                                        .radio_button_off_rounded,
                                size:
                                    19,
                                color: selectionne
                                    ? Couleurs
                                        .primaire
                                    : Colors
                                        .grey
                                        .shade400,
                              ),
                              const SizedBox(
                                width:
                                    10,
                              ),
                              Expanded(
                                child:
                                    Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      produit?.nom ??
                                          'Produit inconnu',
                                      maxLines:
                                          1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            12,
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                      ),
                                    ),
                                    const SizedBox(
                                      height:
                                          3,
                                    ),
                                    Text(
                                      _descriptionSousProduit(
                                        sousProduit,
                                      ),
                                      maxLines:
                                          1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          TextStyle(
                                        fontSize:
                                            10,
                                        color: Colors
                                            .grey
                                            .shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child:
                              Text(
                            _obtenirCodeSousProduit(
                              sousProduit,
                            ),
                            textAlign:
                                TextAlign
                                    .center,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              fontSize:
                                  10,
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child:
                              Text(
                            '${_formaterMontant(prix)} FCFA',
                            textAlign:
                                TextAlign
                                    .center,
                            style:
                                const TextStyle(
                              fontSize:
                                  11,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width:
                              42,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _construireSelection(
    SousProduit sousProduit,
    int prix,
    int quantite,
    int montant,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color: Couleurs
            .primaire
            .withValues(
          alpha: 0.04,
        ),
        borderRadius:
            BorderRadius.circular(
          8,
        ),
        border:
            Border.all(
          color: Couleurs
              .primaire
              .withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .center,
        children: [
          Icon(
            Icons
                .inventory_2_outlined,
            size: 21,
            color:
                Couleurs.primaire,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  _obtenirNomProduit(
                    sousProduit,
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  _descriptionSousProduit(
                    sousProduit,
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          SizedBox(
            width: 115,
            child: TextField(
              controller:
                  _quantiteController,
              keyboardType:
                  TextInputType.number,
              onChanged:
                  (_) {
                setState(
                  () {},
                );
              },
              decoration:
                  InputDecoration(
                labelText:
                    'Quantité',
                isDense: true,
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    7,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Container(
            width: 150,
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(
                7,
              ),
              border:
                  Border.all(
                color:
                    const Color(
                  0xffe5e5ea,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Montant',
                  style:
                      TextStyle(
                    fontSize: 10,
                    color: Colors
                        .grey
                        .shade600,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  '${_formaterMontant(montant)} FCFA',
                  style:
                      TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Couleurs
                            .primaire,
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