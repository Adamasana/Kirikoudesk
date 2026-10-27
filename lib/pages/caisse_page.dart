import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/commande.dart';
import '../models/produit.dart';
import '../models/session.dart';
import '../models/sous_produit.dart';
import '../repositories/commande_repository.dart';
import '../repositories/produit_repository.dart';
import '../repositories/sous_produit_repository.dart';
import '../services/synchronisation/commande_sync_service.dart';
import '../theme/couleurs.dart';
import 'detail_commande_page.dart';

class CaissePage extends StatefulWidget {
  const CaissePage({super.key});

  @override
  CaissePageState createState() => CaissePageState();
}

class CaissePageState extends State<CaissePage> {
  final ProduitRepository _produitRepository =
      ProduitRepository();

  final SousProduitRepository _sousProduitRepository =
      SousProduitRepository();

  final CommandeRepository _commandeRepository =
      CommandeRepository();

  final CommandeSyncService _commandeSyncService =
      CommandeSyncService();

  List<Commande> _commandes = [];
  List<Produit> _produits = [];
  List<SousProduit> _sousProduits = [];

  bool _chargement = true;

  String _recherche = '';

  final TextEditingController _rechercheController =
      TextEditingController();

  // ============================================================
  // SCANNER USB
  // ============================================================

  String _bufferScanner = '';
  DateTime? _dernierCaractereScanner;
  Timer? _timerScanner;
  bool _traitementScan = false;

  @override
  void initState() {
    super.initState();

    HardwareKeyboard.instance.addHandler(
      _gererEvenementScanner,
    );

    _chargerDonnees();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(
      _gererEvenementScanner,
    );

    _timerScanner?.cancel();
    _rechercheController.dispose();
    _commandeSyncService.dispose();

    super.dispose();
  }

  // ============================================================
  // CHARGEMENT
  // ============================================================

  Future<void> _chargerDonnees() async {
    if (mounted) {
      setState(() {
        _chargement = true;
      });
    }

    try {
      final commandes =
          await _commandeRepository.obtenirCommandesPourCaisse();

      debugPrint('');
      debugPrint('==============================================');
      debugPrint('      COMMANDES AFFICHÉES DANS LA CAISSE');
      debugPrint('==============================================');
      debugPrint(
        'Nombre de commandes : ${commandes.length}',
      );

      for (final commande in commandes) {
        debugPrint(
          'ID=${commande.id} | '
          'ID_LOCAL=${commande.idLocal} | '
          'ID_DJANGO=${commande.idDjango} | '
          'STATUT=${commande.statutLocal} | '
          'SYNC=${commande.syncStatus} | '
          'DATE_CREATION=${commande.dateCreation} | '
          'DATE_VALIDATION=${commande.dateValidation} | '
          'NOM=${commande.nom} | '
          'TOTAL=${commande.total}',
        );
      }

      debugPrint('==============================================');
      debugPrint('');

      final produits =
          await _produitRepository.obtenirTous();

      final sousProduits =
          await _sousProduitRepository.obtenirTous();

      if (!mounted) {
        return;
      }

      setState(() {
        _commandes = commandes;
        _produits = produits;
        _sousProduits = sousProduits;
        _chargement = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'Erreur lors du chargement des données de la caisse : $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _chargement = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de charger les données de la caisse : $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // ACTUALISATION PUBLIQUE
  // ============================================================
  //
  // Cette méthode est appelée par ApplicationPage après
  // une synchronisation globale.
  //
  // Elle force CaissePage à relire SQLite afin que les
  // commandes supprimées après synchronisation disparaissent
  // immédiatement de l'écran.
  //
  // ============================================================

  Future<void> actualiser() async {
    await _chargerDonnees();
  }

  // ============================================================
  // SCANNER USB
  // ============================================================

  bool _gererEvenementScanner(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    final route = ModalRoute.of(context);

    if (route != null && !route.isCurrent) {
      _bufferScanner = '';
      _dernierCaractereScanner = null;
      _timerScanner?.cancel();

      return false;
    }

    final maintenant = DateTime.now();

    if (_dernierCaractereScanner != null) {
      final ecart = maintenant.difference(
        _dernierCaractereScanner!,
      );

      if (ecart > const Duration(milliseconds: 120)) {
        _bufferScanner = '';
      }
    }

    _dernierCaractereScanner = maintenant;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _bufferScanner.trim();

      _bufferScanner = '';
      _dernierCaractereScanner = null;

      if (code.length >= 2) {
        unawaited(
          _traiterScanProduit(code),
        );
      }

      return true;
    }

    final caractere = event.character;

    if (caractere != null &&
        caractere.isNotEmpty &&
        caractere.length == 1 &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      _bufferScanner += caractere;

      _timerScanner?.cancel();

      _timerScanner = Timer(
        const Duration(milliseconds: 180),
        () {
          _bufferScanner = '';
          _dernierCaractereScanner = null;
        },
      );

      return false;
    }

    return false;
  }

  // ============================================================
  // RECHERCHE SOUS-PRODUIT
  // ============================================================

  SousProduit? _trouverSousProduitScanne(
    String code,
  ) {
    final codeNormalise =
        code.trim().toLowerCase();

    for (final sousProduit in _sousProduits) {
      final identifiant =
          sousProduit.identifiant
              .trim()
              .toLowerCase();

      if (identifiant.isNotEmpty &&
          identifiant == codeNormalise) {
        return sousProduit;
      }

      final numero =
          sousProduit.numero
              ?.trim()
              .toLowerCase();

      if (numero != null &&
          numero.isNotEmpty &&
          numero == codeNormalise) {
        return sousProduit;
      }

      if (sousProduit.id.toString() ==
          codeNormalise) {
        return sousProduit;
      }
    }

    return null;
  }

  Produit? _obtenirProduitParent(
    SousProduit sousProduit,
  ) {
    for (final produit in _produits) {
      if (produit.id == sousProduit.produitId) {
        return produit;
      }
    }

    return null;
  }

  // ============================================================
  // POINT DE VENTE
  // ============================================================

  Future<int?> _obtenirPointDeVenteId(
    Session session,
  ) async {
    if (session.pointVenteId != null) {
      return session.pointVenteId;
    }

    if (session.boutiqueId == null) {
      return null;
    }

    final db =
        await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.equipe,
      columns: [
        'point_de_vente_id',
      ],
      where: 'id = ?',
      whereArgs: [
        session.boutiqueId,
      ],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    final valeur =
        resultats.first['point_de_vente_id'];

    if (valeur == null) {
      return null;
    }

    if (valeur is int) {
      return valeur;
    }

    return int.tryParse(
      valeur.toString(),
    );
  }

  // ============================================================
  // TRAITEMENT SCAN
  // ============================================================

  Future<void> _traiterScanProduit(
    String code,
  ) async {
    if (_traitementScan || _chargement) {
      return;
    }

    final sousProduit =
        _trouverSousProduitScanne(code);

    if (sousProduit == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Produit introuvable pour le code scanné : $code',
          ),
        ),
      );

      return;
    }

    final produit =
        _obtenirProduitParent(
      sousProduit,
    );

    if (produit == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le produit parent du sous-produit scanné est introuvable.',
          ),
        ),
      );

      return;
    }

    final session =
        await Session.fromPreferences();

    if (!mounted) {
      return;
    }

    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucune session utilisateur active.',
          ),
        ),
      );

      return;
    }

    final pointDeVenteId =
        await _obtenirPointDeVenteId(
      session,
    );

    if (!mounted) {
      return;
    }

    if (pointDeVenteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le point de vente de l’utilisateur connecté est introuvable.',
          ),
        ),
      );

      return;
    }

    if (session.utilisateurId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’utilisateur connecté ne possède pas d’identifiant local valide.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _traitementScan = true;
    });

    try {
      const nom = 'Particulier';
      const telephone = '+226 00 00 00 00';

      final prix = produit.prixActuel;
      const quantite = 1;

      final montant =
          prix * quantite;

      // --------------------------------------------------------
      // IMPORTANT :
      //
      // dateValidation reste NULL.
      //
      // La commande n'est pas encore validée.
      // Elle sera renseignée par validerLocalement().
      // --------------------------------------------------------

      final commande = Commande(
        id: null,
        idLocal: '',
        idDjango: null,
        userId: null,
        encaissePar:
            session.utilisateurId,
        gestionnaireId: null,
        nom: nom,
        telephone: telephone,
        ville: null,
        deplacement: null,
        montant: montant,
        remise: 0,
        livraison: 0,
        total: montant,
        payer: 'Oui',
        statutLocal: 'Caisse',
        origine: 'Caisse',
        dateCreation:
            DateTime.now(),
        dateValidation: null,
        dateUpdate:
            DateTime.now(),
        syncStatus: 'pending',
        syncDate: null,
        syncErreur: null,
      );

      await _commandeRepository
          .enregistrerAvecArticles(
        commande: commande,
        articles: [
          {
            'article_id':
                sousProduit.id,
            'quantite':
                quantite,
            'prix':
                prix,
            'montant':
                montant,
            'point_de_vente_id':
                pointDeVenteId,
          },
        ],
      );

      if (!mounted) {
        return;
      }

      await _chargerDonnees();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Commande créée : $nom — ${produit.nom}',
          ),
        ),
      );
    } on StockIntrouvableException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } on CaisseTransactionException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de créer la commande : ${e.message}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de créer la commande depuis le scan : $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _traitementScan = false;
        });
      }
    }
  }

  // ============================================================
  // AJOUT COMMANDE
  // ============================================================

  Future<void> _ouvrirAjoutCommande() async {
    final commande =
        await showDialog<Commande>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AjouterCommandeDialog(
          produits: _produits,
          sousProduits: _sousProduits,
          commandeRepository:
              _commandeRepository,
        );
      },
    );

    if (!mounted ||
        commande == null) {
      return;
    }

    await _chargerDonnees();
  }

  // ============================================================
  // OUVRIR DETAIL
  // ============================================================

  Future<void> _ouvrirCommande(
    Commande commande,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DetailCommandePage(
          commande: commande,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _chargerDonnees();
  }

  // ============================================================
  // VALIDATION LOCALE + SYNCHRONISATION
  // ============================================================

  Future<void> _validerCommande(
    Commande commande,
  ) async {
    // ----------------------------------------------------------
    // Une seule validation est autorisée depuis Caisse.
    // ----------------------------------------------------------

    if (commande.statutLocal != 'Caisse') {
      return;
    }

    if (commande.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de valider une commande sans identifiant local.',
          ),
        ),
      );

      return;
    }

    final confirmer =
        await _afficherConfirmation(
      titre: 'Valider la commande',
      message:
          'Cette commande va être validée comme facture.\n\n'
          'Si Internet est disponible, elle sera immédiatement '
          'synchronisée avec le serveur. Sinon, elle restera '
          'en attente et sera synchronisée automatiquement '
          'dès que la connexion sera disponible.',
      icone:
          Icons.check_circle_outline,
      couleur:
          const Color(0xFF34C759),
      texteConfirmation:
          'Valider',
    );

    if (!confirmer ||
        !mounted) {
      return;
    }

    try {
      // --------------------------------------------------------
      // IMPORTANT :
      //
      // Le repository crée ici dateValidation = DateTime.now().
      //
      // C'est donc précisément le moment où l'utilisateur
      // confirme la vente.
      // --------------------------------------------------------

      final commandeValidee =
          await _commandeRepository
              .validerLocalement(
        commande.id!,
      );

      debugPrint(
        'Commande validée localement : '
        'id=${commandeValidee.id} | '
        'idLocal=${commandeValidee.idLocal} | '
        'dateValidation=${commandeValidee.dateValidation}',
      );

      if (!mounted) {
        return;
      }

      await _chargerDonnees();

      if (!mounted) {
        return;
      }

      // --------------------------------------------------------
      // Tentative de synchronisation immédiate.
      // --------------------------------------------------------

      try {
        await _commandeSyncService
            .synchroniserCommande(
          commandeValidee,
        );

        if (!mounted) {
          return;
        }

        await _chargerDonnees();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Facture synchronisée avec succès.',
            ),
          ),
        );
      } on CommandeSyncException catch (e) {
        // ------------------------------------------------------
        // IMPORTANT :
        //
        // La validation locale a réussi.
        //
        // Même si Internet échoue, la commande reste :
        //
        // statut_local = Facture
        // sync_status  = pending
        // date_validation = heure réelle de validation
        //
        // Elle pourra être synchronisée plus tard.
        // ------------------------------------------------------

        debugPrint(
          'Synchronisation différée : ${e.message}',
        );

        if (!mounted) {
          return;
        }

        await _chargerDonnees();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Facture enregistrée localement. '
              'La synchronisation sera réessayée automatiquement.',
            ),
          ),
        );
      }
    } on CaisseTransactionException catch (e) {
      if (!mounted) {
        return;
      }

      await _chargerDonnees();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de valider la commande localement : '
            '${e.message}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      await _chargerDonnees();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de valider la commande localement : $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // ANNULATION / SUPPRESSION
  // ============================================================

  Future<void> _annulerCommande(
    Commande commande,
  ) async {
    if (commande.id == null) {
      return;
    }

    final estCaisse =
        commande.statutLocal ==
            'Caisse';

    final estFactureEnAttente =
        commande.statutLocal ==
                'Facture' &&
            commande.syncStatus !=
                'synced' &&
            commande.idDjango ==
                null;

    if (!estCaisse &&
        !estFactureEnAttente) {
      return;
    }

    // ==========================================================
    // SUPPRESSION D'UNE COMMANDE EN CAISSE
    // ==========================================================

    if (estCaisse) {
      final confirmer =
          await _afficherConfirmation(
        titre:
            'Supprimer la commande',
        message:
            'Cette commande n’est pas encore validée.\n\n'
            'Elle sera définitivement supprimée de la caisse '
            'et le stock local correspondant sera restauré.',
        icone:
            Icons.delete_outline,
        couleur:
            const Color(0xFFFF3B30),
        texteConfirmation:
            'Supprimer',
      );

      if (!confirmer ||
          !mounted) {
        return;
      }

      try {
        await _commandeRepository
            .supprimerAvecRestaurationStock(
          commande.id!,
        );

        if (!mounted) {
          return;
        }

        await _chargerDonnees();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Commande supprimée.',
            ),
          ),
        );
      } catch (e) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Impossible de supprimer la commande : $e',
            ),
          ),
        );
      }

      return;
    }

    // ==========================================================
    // ANNULATION D'UNE VALIDATION LOCALE
    // ==========================================================

    final confirmer =
        await _afficherConfirmation(
      titre:
          'Annuler la validation',
      message:
          'Cette facture n’a pas encore été synchronisée avec le serveur.\n\n'
          'La validation sera annulée et la commande reviendra '
          'à l’état Caisse.\n\n'
          'Le stock ne sera pas restauré, car la commande '
          'reste active dans la caisse.',
      icone:
          Icons.undo,
      couleur:
          const Color(0xFFFF3B30),
      texteConfirmation:
          'Annuler la validation',
    );

    if (!confirmer ||
        !mounted) {
      return;
    }

    try {
      await _commandeRepository
          .annulerValidationLocale(
        commande.id!,
      );

      if (!mounted) {
        return;
      }

      await _chargerDonnees();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Validation annulée. La commande est de nouveau en caisse.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’annuler la validation : $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DIALOGUE DE CONFIRMATION
  // ============================================================

  Future<bool> _afficherConfirmation({
    required String titre,
    required String message,
    required IconData icone,
    required Color couleur,
    required String texteConfirmation,
  }) async {
    final resultat =
        await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor:
              Couleurs.blanc,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              12.0,
            ),
          ),
          child: SizedBox(
            width: 460.0,
            child: Padding(
              padding:
                  const EdgeInsets.all(
                24.0,
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42.0,
                        height: 42.0,
                        decoration:
                            BoxDecoration(
                          color:
                              couleur.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            10.0,
                          ),
                        ),
                        child: Icon(
                          icone,
                          size: 21.0,
                          color: couleur,
                        ),
                      ),
                      const SizedBox(
                        width: 12.0,
                      ),
                      Expanded(
                        child: Text(
                          titre,
                          style:
                              const TextStyle(
                            fontSize: 18.0,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                Couleurs.texte,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 18.0,
                  ),
                  Text(
                    message,
                    style:
                        const TextStyle(
                      fontSize: 14.0,
                      height: 1.5,
                      color:
                          Couleurs.muted,
                    ),
                  ),
                  const SizedBox(
                    height: 24.0,
                  ),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pop(false);
                        },
                        style:
                            TextButton.styleFrom(
                          foregroundColor:
                              Couleurs.muted,
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 11.0,
                          ),
                        ),
                        child:
                            const Text(
                          'Annuler',
                        ),
                      ),
                      const SizedBox(
                        width: 8.0,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pop(true);
                        },
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              couleur,
                          foregroundColor:
                              Couleurs.blanc,
                          elevation: 0.0,
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 18.0,
                            vertical: 11.0,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              8.0,
                            ),
                          ),
                        ),
                        child: Text(
                          texteConfirmation,
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
  // RECHERCHE
  // ============================================================

  List<Commande> get _commandesFiltrees {
    final recherche =
        _recherche
            .trim()
            .toLowerCase();

    if (recherche.isEmpty) {
      return _commandes;
    }

    return _commandes.where(
      (commande) {
        final texteRecherche = [
          commande.id?.toString() ??
              '',
          commande.idLocal,
          commande.nom,
          commande.telephone,
          commande.ville ?? '',
          commande.statutLocal,
          commande.origine,
        ].join(' ').toLowerCase();

        return texteRecherche.contains(
          recherche,
        );
      },
    ).toList();
  }

  String _formatMontant(
    num montant,
  ) {
    return '${montant.toStringAsFixed(0)} FCFA';
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
      body: Padding(
        padding:
            const EdgeInsets.all(
          24.0,
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Caisse',
                  style:
                      TextStyle(
                    fontSize: 24.0,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Couleurs.texte,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 280.0,
                  height: 40.0,
                  child:
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
                          'Rechercher...',
                      prefixIcon:
                          const Icon(
                        Icons.search,
                        size: 19.0,
                      ),
                      suffixIcon:
                          _recherche
                                  .isNotEmpty
                              ? IconButton(
                                  icon:
                                      const Icon(
                                    Icons.close,
                                    size:
                                        18.0,
                                  ),
                                  onPressed:
                                      () {
                                    _rechercheController
                                        .clear();

                                    setState(
                                      () {
                                        _recherche =
                                            '';
                                      },
                                    );
                                  },
                                )
                              : null,
                      filled:
                          true,
                      fillColor:
                          Couleurs.blanc,
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal:
                            12.0,
                        vertical:
                            0.0,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          8.0,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Couleurs.bordure,
                        ),
                      ),
                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          8.0,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Couleurs.bordure,
                        ),
                      ),
                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          8.0,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Couleurs.primaire,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 12.0,
                ),
                SizedBox(
                  height: 40.0,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        _ouvrirAjoutCommande,
                    icon:
                        const Icon(
                      Icons.add,
                      size: 18.0,
                    ),
                    label:
                        const Text(
                      'Nouvelle commande',
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Couleurs.primaire,
                      foregroundColor:
                          Couleurs.blanc,
                      elevation:
                          0.0,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal:
                            16.0,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          8.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20.0,
            ),
            Expanded(
              child: _chargement
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : _commandesFiltrees
                          .isEmpty
                      ? _buildEtatVide()
                      : _buildTable(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ETAT VIDE
  // ============================================================

  Widget _buildEtatVide() {
    return Container(
      width:
          double.infinity,
      decoration:
          BoxDecoration(
        color:
            Couleurs.blanc,
        borderRadius:
            BorderRadius.circular(
          12.0,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE5E5EA,
          ),
        ),
        boxShadow:
            const [
          BoxShadow(
            color:
                Color(0x08000000),
            blurRadius:
                2.0,
            offset:
                Offset(0.0, 1.0),
          ),
        ],
      ),
      child:
          const Center(
        child:
            Text(
          'Aucune commande trouvée.',
          style:
              TextStyle(
            color:
                Couleurs.muted,
            fontSize:
                14.0,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TABLE
  // ============================================================

  Widget _buildTable() {
    final commandes =
        _commandesFiltrees;

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints contraintes,
      ) {
        const double largeurMinimum =
            850.0;

        final largeurTableau =
            contraintes.maxWidth >
                    largeurMinimum
                ? contraintes.maxWidth
                : largeurMinimum;

        return Container(
          width:
              double.infinity,
          decoration:
              BoxDecoration(
            color:
                Couleurs.blanc,
            borderRadius:
                BorderRadius.circular(
              12.0,
            ),
            border:
                Border.all(
              color:
                  const Color(
                0xFFE5E5EA,
              ),
            ),
            boxShadow:
                const [
              BoxShadow(
                color:
                    Color(0x08000000),
                blurRadius:
                    2.0,
                offset:
                    Offset(0.0, 1.0),
              ),
            ],
          ),
          child:
              ClipRRect(
            borderRadius:
                BorderRadius.circular(
              12.0,
            ),
            child:
                SingleChildScrollView(
              scrollDirection:
                  Axis.horizontal,
              child:
                  SizedBox(
                width:
                    largeurTableau,
                child:
                    Column(
                  children: [
                    Container(
                      height:
                          50.0,
                      color:
                          Couleurs.blanc,
                      child:
                          const Row(
                        children: [
                          _EnteteCell(
                            texte:
                                'No',
                            flex:
                                70,
                          ),
                          _EnteteCell(
                            texte:
                                'Nom',
                            flex:
                                180,
                          ),
                          _EnteteCell(
                            texte:
                                'Montant',
                            flex:
                                130,
                          ),
                          _EnteteCell(
                            texte:
                                'Remise',
                            flex:
                                110,
                          ),
                          _EnteteCell(
                            texte:
                                'Total',
                            flex:
                                130,
                          ),
                          _EnteteCell(
                            texte:
                                'Actions',
                            flex:
                                230,
                            centrer:
                                true,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height:
                          1.0,
                      color:
                          const Color(
                        0xFFE5E5EA,
                      ),
                    ),
                    Expanded(
                      child:
                          ListView.separated(
                        padding:
                            EdgeInsets.zero,
                        itemCount:
                            commandes.length,
                        separatorBuilder:
                            (_, __) {
                          return Container(
                            height:
                                1.0,
                            color:
                                const Color(
                              0xFFEEEEEE,
                            ),
                          );
                        },
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          final commande =
                              commandes[index];

                          final peutAnnuler =
                              commande.statutLocal ==
                                      'Caisse' ||
                                  (
                                    commande.statutLocal ==
                                        'Facture' &&
                                    commande.syncStatus !=
                                        'synced' &&
                                    commande.idDjango ==
                                        null
                                  );

                          return _LigneCommande(
                            commande:
                                commande,
                            formatMontant:
                                _formatMontant,
                            onOuvrir:
                                () {
                              _ouvrirCommande(
                                commande,
                              );
                            },
                            onValider:
                                commande.statutLocal ==
                                        'Caisse'
                                    ? () {
                                        _validerCommande(
                                          commande,
                                        );
                                      }
                                    : null,
                            onAnnuler:
                                peutAnnuler
                                    ? () {
                                        _annulerCommande(
                                          commande,
                                        );
                                      }
                                    : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// LIGNE COMMANDE
// ================================================================

class _LigneCommande
    extends StatefulWidget {
  final Commande commande;

  final String Function(num)
      formatMontant;

  final VoidCallback onOuvrir;

  final VoidCallback? onValider;

  final VoidCallback? onAnnuler;

  const _LigneCommande({
    required this.commande,
    required this.formatMontant,
    required this.onOuvrir,
    required this.onValider,
    required this.onAnnuler,
  });

  @override
  State<_LigneCommande> createState() =>
      _LigneCommandeState();
}

class _LigneCommandeState
    extends State<_LigneCommande> {
  bool _survol = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    return MouseRegion(
      cursor:
          SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _survol = true;
        });
      },
      onExit: (_) {
        setState(() {
          _survol = false;
        });
      },
      child: Material(
        color: _survol
            ? const Color(
                0xFFF8F8FA,
              )
            : Couleurs.blanc,
        child: InkWell(
          onTap:
              widget.onOuvrir,
          hoverColor:
              const Color(
            0xFFF8F8FA,
          ),
          splashColor:
              Couleurs.primaire.withValues(
            alpha: 0.04,
          ),
          highlightColor:
              Couleurs.primaire.withValues(
            alpha: 0.025,
          ),
          child: SizedBox(
            height:
                62.0,
            child: Row(
              children: [
                _CorpsCell(
                  texte:
                      '${widget.commande.id ?? ''}',
                  flex:
                      70,
                  poids:
                      FontWeight.w600,
                  couleur:
                      const Color(
                    0xFF1D1D1F,
                  ),
                ),
                _CorpsCell(
                  texte:
                      widget.commande.nom.isEmpty
                          ? '-'
                          : widget.commande.nom,
                  flex:
                      180,
                  poids:
                      FontWeight.w500,
                  couleur:
                      const Color(
                    0xFF6E6E73,
                  ),
                ),
                _CorpsCell(
                  texte:
                      widget.formatMontant(
                    widget.commande.montant,
                  ),
                  flex:
                      130,
                  couleur:
                      const Color(
                    0xFF6E6E73,
                  ),
                  nowrap:
                      true,
                ),
                _CorpsCell(
                  texte:
                      widget.formatMontant(
                    widget.commande.remise,
                  ),
                  flex:
                      110,
                  couleur:
                      const Color(
                    0xFF6E6E73,
                  ),
                  nowrap:
                      true,
                ),
                _CorpsCell(
                  texte:
                      widget.formatMontant(
                    widget.commande.total,
                  ),
                  flex:
                      130,
                  couleur:
                      const Color(
                    0xFF6E6E73,
                  ),
                  nowrap:
                      true,
                ),
                Expanded(
                  flex:
                      230,
                  child:
                      GestureDetector(
                    onTap:
                        () {},
                    child:
                        Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal:
                            22.0,
                      ),
                      child:
                          Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          _ActionButton(
                            tooltip:
                                'Valider la commande',
                            icon:
                                Icons.check,
                            backgroundColor:
                                const Color(
                              0xFF34C759,
                            ),
                            onPressed:
                                widget.onValider,
                          ),
                          const SizedBox(
                            width:
                                4.0,
                          ),
                          _ActionButton(
                            tooltip:
                                'Supprimer la commande',
                            icon:
                                Icons.close,
                            backgroundColor:
                                const Color(
                              0xFFFF3B30,
                            ),
                            onPressed:
                                widget.onAnnuler,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ACTION BUTTON
// ================================================================

class _ActionButton
    extends StatelessWidget {
  final String tooltip;

  final IconData icon;

  final Color backgroundColor;

  final VoidCallback? onPressed;

  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final actif =
        onPressed != null;

    return Tooltip(
      message:
          tooltip,
      child:
          Material(
        color:
            actif
                ? backgroundColor
                : backgroundColor.withValues(
                    alpha:
                        0.35,
                  ),
        borderRadius:
            BorderRadius.circular(
          7.0,
        ),
        child:
            InkWell(
          borderRadius:
              BorderRadius.circular(
            7.0,
          ),
          onTap:
              onPressed,
          child:
              SizedBox(
            width:
                34.0,
            height:
                34.0,
            child:
                Center(
              child:
                  Icon(
                icon,
                size:
                    15.0,
                color:
                    Couleurs.blanc,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ENTETE CELL
// ================================================================

class _EnteteCell
    extends StatelessWidget {
  final String texte;

  final int flex;

  final bool centrer;

  const _EnteteCell({
    required this.texte,
    required this.flex,
    this.centrer = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Expanded(
      flex:
          flex,
      child:
          SizedBox(
        height:
            50.0,
        child:
            Padding(
          padding:
              EdgeInsets.only(
            left:
                centrer
                    ? 0.0
                    : 18.0,
            right:
                centrer
                    ? 0.0
                    : 18.0,
          ),
          child:
              Align(
            alignment:
                centrer
                    ? Alignment.center
                    : Alignment.centerLeft,
            child:
                Text(
              texte,
              style:
                  const TextStyle(
                fontSize:
                    16.0,
                fontWeight:
                    FontWeight.w900,
                color:
                    Couleurs.primaire,
                letterSpacing:
                    -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// CORPS CELL
// ================================================================

class _CorpsCell
    extends StatelessWidget {
  final String texte;

  final int flex;

  final FontWeight poids;

  final Color couleur;

  final bool nowrap;

  const _CorpsCell({
    required this.texte,
    required this.flex,
    this.poids =
        FontWeight.w400,
    this.couleur =
        const Color(
      0xFF3A3A3C,
    ),
    this.nowrap = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Expanded(
      flex:
          flex,
      child:
          SizedBox(
        height:
            62.0,
        child:
            Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal:
                18.0,
          ),
          child:
              Align(
            alignment:
                Alignment.centerLeft,
            child:
                Text(
              texte,
              maxLines:
                  1,
              overflow:
                  TextOverflow.ellipsis,
              softWrap:
                  !nowrap,
              style:
                  TextStyle(
                fontSize:
                    14.0,
                height:
                    1.35,
                fontWeight:
                    poids,
                color:
                    couleur,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// AJOUTER COMMANDE
// ================================================================

class AjouterCommandeDialog
    extends StatefulWidget {
  final List<Produit> produits;

  final List<SousProduit>
      sousProduits;

  final CommandeRepository
      commandeRepository;

  const AjouterCommandeDialog({
    super.key,
    required this.produits,
    required this.sousProduits,
    required this.commandeRepository,
  });

  @override
  State<AjouterCommandeDialog> createState() =>
      _AjouterCommandeDialogState();
}

class _AjouterCommandeDialogState
    extends State<AjouterCommandeDialog> {
  final TextEditingController
      _produitController =
      TextEditingController();

  final TextEditingController
      _quantiteController =
      TextEditingController(
    text:
        '1',
  );

  final TextEditingController
      _montantController =
      TextEditingController();

  final TextEditingController
      _nomController =
      TextEditingController();

  final TextEditingController
      _telephoneController =
      TextEditingController();

  SousProduit?
      _sousProduitSelectionne;

  Produit?
      _produitSelectionne;

  bool _afficherSuggestions =
      false;

  bool _enregistrement =
      false;

  @override
  void dispose() {
    _produitController.dispose();
    _quantiteController.dispose();
    _montantController.dispose();
    _nomController.dispose();
    _telephoneController.dispose();

    super.dispose();
  }

  Produit? _obtenirProduitParent(
    SousProduit sousProduit,
  ) {
    for (final produit
        in widget.produits) {
      if (produit.id ==
          sousProduit.produitId) {
        return produit;
      }
    }

    return null;
  }

  List<SousProduit>
      get _sousProduitsFiltres {
    final recherche =
        _produitController.text
            .trim()
            .toLowerCase();

    final sousProduitsDisponibles =
        widget.sousProduits.toList();

    if (recherche.isEmpty) {
      return sousProduitsDisponibles;
    }

    return sousProduitsDisponibles.where(
      (sousProduit) {
        final produit =
            _obtenirProduitParent(
          sousProduit,
        );

        final texte = [
          produit?.nom ?? '',
          sousProduit.couleur,
          sousProduit.pointure,
          sousProduit.identifiant,
          sousProduit.numero ?? '',
          sousProduit.id.toString(),
        ].join(' ').toLowerCase();

        return texte.contains(
          recherche,
        );
      },
    ).toList();
  }

  void _selectionnerSousProduit(
    SousProduit sousProduit,
  ) {
    final produit =
        _obtenirProduitParent(
      sousProduit,
    );

    if (produit == null) {
      _afficherErreur(
        'Le produit parent de ce sous-produit est introuvable.',
      );

      return;
    }

    setState(() {
      _sousProduitSelectionne =
          sousProduit;

      _produitSelectionne =
          produit;

      _produitController.text =
          _texteSousProduit(
        sousProduit,
        produit,
      );

      _afficherSuggestions =
          false;
    });

    _mettreAJourMontant();
  }

  String _texteSousProduit(
    SousProduit sousProduit,
    Produit produit,
  ) {
    final elements =
        <String>[
      produit.nom,
    ];

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

    if (sousProduit.numero !=
            null &&
        sousProduit.numero!
            .trim()
            .isNotEmpty) {
      elements.add(
        sousProduit.numero!,
      );
    }

    return elements.join(
      ' - ',
    );
  }

  void _mettreAJourMontant() {
    final produit =
        _produitSelectionne;

    if (produit == null) {
      _montantController.clear();
      return;
    }

    final quantite =
        int.tryParse(
              _quantiteController.text.trim(),
            ) ??
            1;

    final montant =
        produit.prixActuel *
            quantite.toDouble();

    _montantController.text =
        montant.toStringAsFixed(
      0,
    );
  }

  int _obtenirQuantite() {
    final quantite =
        int.tryParse(
      _quantiteController.text.trim(),
    );

    if (quantite == null ||
        quantite <= 0) {
      return 0;
    }

    return quantite;
  }

  Future<int?> _obtenirPointDeVenteId(
    Session session,
  ) async {
    if (session.pointVenteId !=
        null) {
      return session.pointVenteId;
    }

    if (session.boutiqueId ==
        null) {
      return null;
    }

    final db =
        await DatabaseHelper.obtenirBase();

    final resultats =
        await db.query(
      DatabaseTables.equipe,
      columns: [
        'point_de_vente_id',
      ],
      where:
          'id = ?',
      whereArgs: [
        session.boutiqueId,
      ],
      limit:
          1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    final valeur =
        resultats.first[
            'point_de_vente_id'];

    if (valeur == null) {
      return null;
    }

    if (valeur is int) {
      return valeur;
    }

    return int.tryParse(
      valeur.toString(),
    );
  }

  Future<void> _confirmer() async {
    if (_enregistrement) {
      return;
    }

    final sousProduit =
        _sousProduitSelectionne;

    final produit =
        _produitSelectionne;

    if (sousProduit == null ||
        produit == null) {
      _afficherErreur(
        'Veuillez sélectionner un sous-produit.',
      );

      return;
    }

    final quantite =
        _obtenirQuantite();

    if (quantite <= 0) {
      _afficherErreur(
        'La quantité doit être supérieure à zéro.',
      );

      return;
    }

    final nom =
        _nomController.text.trim();

    final telephone =
        _telephoneController.text.trim();

    if (nom.isEmpty) {
      _afficherErreur(
        'Veuillez renseigner le nom du client.',
      );

      return;
    }

    if (telephone.isEmpty) {
      _afficherErreur(
        'Veuillez renseigner le téléphone du client.',
      );

      return;
    }

    final session =
        await Session.fromPreferences();

    if (!mounted) {
      return;
    }

    if (session == null) {
      _afficherErreur(
        'Aucune session utilisateur active.',
      );

      return;
    }

    final pointDeVenteId =
        await _obtenirPointDeVenteId(
      session,
    );

    if (!mounted) {
      return;
    }

    if (pointDeVenteId == null) {
      _afficherErreur(
        'Le point de vente de l’utilisateur connecté est introuvable. '
        'Vérifiez que son équipe possède bien un point de vente local.',
      );

      return;
    }

    if (session.utilisateurId <= 0) {
      _afficherErreur(
        'L’utilisateur connecté ne possède pas '
        'd’identifiant local valide.\n\n'
        'Veuillez vous déconnecter puis vous reconnecter '
        'afin d’enregistrer votre compte localement.',
      );

      return;
    }

    setState(() {
      _enregistrement = true;
    });

    try {
      final prix =
          produit.prixActuel;

      final montant =
          prix * quantite;

      // --------------------------------------------------------
      // Une nouvelle commande est créée en Caisse.
      //
      // dateValidation reste NULL.
      // --------------------------------------------------------

      final commande = Commande(
        id: null,
        idLocal: '',
        idDjango: null,
        userId: null,
        encaissePar:
            session.utilisateurId,
        gestionnaireId: null,
        nom: nom,
        telephone: telephone,
        ville: null,
        deplacement: null,
        montant:
            montant,
        remise: 0,
        livraison: 0,
        total:
            montant,
        payer:
            'Oui',
        statutLocal:
            'Caisse',
        origine:
            'Caisse',
        dateCreation:
            DateTime.now(),
        dateValidation:
            null,
        dateUpdate:
            DateTime.now(),
        syncStatus:
            'pending',
        syncDate:
            null,
        syncErreur:
            null,
      );

      final commandeEnregistree =
          await widget.commandeRepository
              .enregistrerAvecArticles(
        commande:
            commande,
        articles: [
          {
            'article_id':
                sousProduit.id,
            'quantite':
                quantite,
            'prix':
                prix,
            'montant':
                montant,
            'point_de_vente_id':
                pointDeVenteId,
          },
        ],
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        commandeEnregistree,
      );
    } on StockIntrouvableException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _enregistrement =
            false;
      });

      _afficherErreur(
        e.message,
      );
    } on CaisseTransactionException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _enregistrement =
            false;
      });

      _afficherErreur(
        e.message,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _enregistrement =
            false;
      });

      _afficherErreur(
        'Impossible d’enregistrer la commande localement.\n\n$e',
      );
    }
  }

  void _afficherErreur(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    showDialog<void>(
      context:
          context,
      builder:
          (context) {
        return AlertDialog(
          title:
              const Text(
            'Impossible d’enregistrer',
          ),
          content:
              Text(
            message,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop();
              },
              child:
                  const Text(
                'Fermer',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD DIALOG
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Dialog(
      backgroundColor:
          Couleurs.blanc,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          12.0,
        ),
      ),
      child:
          SizedBox(
        width:
            620.0,
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            24.0,
          ),
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Nouvelle commande',
                style:
                    TextStyle(
                  fontSize:
                      20.0,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Couleurs.texte,
                ),
              ),
              const SizedBox(
                height:
                    24.0,
              ),
              _buildChampProduit(),
              const SizedBox(
                height:
                    16.0,
              ),
              Row(
                children: [
                  Expanded(
                    child:
                        _buildChamp(
                      controller:
                          _quantiteController,
                      label:
                          'Quantité',
                      hint:
                          'Quantité',
                      keyboardType:
                          TextInputType.number,
                      onChanged:
                          (_) {
                        _mettreAJourMontant();
                      },
                    ),
                  ),
                  const SizedBox(
                    width:
                        16.0,
                  ),
                  Expanded(
                    child:
                        _buildChamp(
                      controller:
                          _montantController,
                      label:
                          'Montant',
                      hint:
                          'Montant',
                      readOnly:
                          true,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height:
                    16.0,
              ),
              Row(
                children: [
                  Expanded(
                    child:
                        _buildChamp(
                      controller:
                          _nomController,
                      label:
                          'Nom',
                      hint:
                          'Nom du client',
                    ),
                  ),
                  const SizedBox(
                    width:
                        16.0,
                  ),
                  Expanded(
                    child:
                        _buildChamp(
                      controller:
                          _telephoneController,
                      label:
                          'Téléphone',
                      hint:
                          'Téléphone',
                      keyboardType:
                          TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height:
                    28.0,
              ),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _enregistrement
                            ? null
                            : () {
                                Navigator.of(
                                  context,
                                ).pop();
                              },
                    child:
                        const Text(
                      'Annuler',
                    ),
                  ),
                  const SizedBox(
                    width:
                        12.0,
                  ),
                  ElevatedButton(
                    onPressed:
                        _enregistrement
                            ? null
                            : _confirmer,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Couleurs.primaire,
                      foregroundColor:
                          Couleurs.blanc,
                      elevation:
                          0.0,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal:
                            20.0,
                        vertical:
                            12.0,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          8.0,
                        ),
                      ),
                    ),
                    child:
                        _enregistrement
                            ? const SizedBox(
                                width:
                                    18.0,
                                height:
                                    18.0,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2.0,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                    Couleurs.blanc,
                                  ),
                                ),
                              )
                            : const Text(
                                'Enregistrer',
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

  // ============================================================
  // CHAMP PRODUIT
  // ============================================================

  Widget _buildChampProduit() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Produit',
          style:
              TextStyle(
            fontSize:
                13.0,
            fontWeight:
                FontWeight.w600,
            color:
                Couleurs.texte,
          ),
        ),
        const SizedBox(
          height:
              7.0,
        ),
        TextField(
          controller:
              _produitController,
          onTap: () {
            setState(() {
              _afficherSuggestions =
                  true;
            });
          },
          onChanged:
              (_) {
            setState(() {
              _afficherSuggestions =
                  true;

              _sousProduitSelectionne =
                  null;

              _produitSelectionne =
                  null;
            });

            _mettreAJourMontant();
          },
          decoration:
              InputDecoration(
            hintText:
                'Rechercher un produit...',
            prefixIcon:
                const Icon(
              Icons.inventory_2_outlined,
              size:
                  19.0,
            ),
            suffixIcon:
                _sousProduitSelectionne !=
                        null
                    ? IconButton(
                        tooltip:
                            'Effacer',
                        onPressed:
                            () {
                          setState(
                            () {
                              _produitController
                                  .clear();

                              _sousProduitSelectionne =
                                  null;

                              _produitSelectionne =
                                  null;

                              _afficherSuggestions =
                                  true;
                            },
                          );

                          _mettreAJourMontant();
                        },
                        icon:
                            const Icon(
                          Icons.close,
                          size:
                              18.0,
                        ),
                      )
                    : null,
            filled:
                true,
            fillColor:
                Couleurs.blanc,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal:
                  12.0,
              vertical:
                  12.0,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8.0,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Couleurs.bordure,
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8.0,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Couleurs.bordure,
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8.0,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Couleurs.primaire,
              ),
            ),
          ),
        ),
        if (_afficherSuggestions)
          _buildSuggestions(),
      ],
    );
  }

  // ============================================================
  // SUGGESTIONS
  // ============================================================

  Widget _buildSuggestions() {
    final suggestions =
        _sousProduitsFiltres;

    return Container(
      margin:
          const EdgeInsets.only(
        top:
            4.0,
      ),
      constraints:
          const BoxConstraints(
        maxHeight:
            230.0,
      ),
      decoration:
          BoxDecoration(
        color:
            Couleurs.blanc,
        borderRadius:
            BorderRadius.circular(
          8.0,
        ),
        border:
            Border.all(
          color:
              Couleurs.bordure,
        ),
        boxShadow:
            const [
          BoxShadow(
            blurRadius:
                12.0,
            offset:
                Offset(
              0.0,
              4.0,
            ),
            color:
                Color(
              0x18000000,
            ),
          ),
        ],
      ),
      child:
          suggestions.isEmpty
              ? const Padding(
                  padding:
                      EdgeInsets.all(
                    16.0,
                  ),
                  child:
                      Text(
                    'Aucun sous-produit trouvé.',
                    style:
                        TextStyle(
                      color:
                          Couleurs.muted,
                      fontSize:
                          13.0,
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap:
                      true,
                  itemCount:
                      suggestions.length,
                  separatorBuilder:
                      (_, __) =>
                          const Divider(
                    height:
                        1.0,
                    color:
                        Couleurs.bordure,
                  ),
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final sousProduit =
                        suggestions[index];

                    final produit =
                        _obtenirProduitParent(
                      sousProduit,
                    );

                    if (produit == null) {
                      return const SizedBox.shrink();
                    }

                    return InkWell(
                      onTap:
                          () {
                        _selectionnerSousProduit(
                          sousProduit,
                        );
                      },
                      child:
                          Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal:
                              12.0,
                          vertical:
                              10.0,
                        ),
                        child:
                            Row(
                          children: [
                            Container(
                              width:
                                  34.0,
                              height:
                                  34.0,
                              decoration:
                                  BoxDecoration(
                                color:
                                    Couleurs.fond,
                                borderRadius:
                                    BorderRadius.circular(
                                  7.0,
                                ),
                              ),
                              child:
                                  const Icon(
                                Icons.inventory_2_outlined,
                                size:
                                    18.0,
                                color:
                                    Couleurs.primaire,
                              ),
                            ),
                            const SizedBox(
                              width:
                                  10.0,
                            ),
                            Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    produit.nom,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          13.0,
                                      fontWeight:
                                          FontWeight.w600,
                                      color:
                                          Couleurs.texte,
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        3.0,
                                  ),
                                  Text(
                                    [
                                      if (sousProduit
                                          .couleur
                                          .trim()
                                          .isNotEmpty)
                                        sousProduit.couleur,
                                      if (sousProduit
                                          .pointure
                                          .trim()
                                          .isNotEmpty)
                                        sousProduit.pointure,
                                      if (sousProduit.numero !=
                                              null &&
                                          sousProduit.numero!
                                              .trim()
                                              .isNotEmpty)
                                        sousProduit.numero!,
                                    ].join(
                                      ' • ',
                                    ),
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          12.0,
                                      color:
                                          Couleurs.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              width:
                                  12.0,
                            ),
                            Text(
                              '${produit.prixActuel.toStringAsFixed(0)} FCFA',
                              style:
                                  const TextStyle(
                                fontSize:
                                    12.0,
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    Couleurs.primaire,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // ============================================================
  // CHAMP GENERIQUE
  // ============================================================

  Widget _buildChamp({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool readOnly =
        false,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              const TextStyle(
            fontSize:
                13.0,
            fontWeight:
                FontWeight.w600,
            color:
                Couleurs.texte,
          ),
        ),
        const SizedBox(
          height:
              7.0,
        ),
        TextField(
          controller:
              controller,
          keyboardType:
              keyboardType,
          readOnly:
              readOnly,
          onChanged:
              onChanged,
          decoration:
              InputDecoration(
            hintText:
                hint,
            filled:
                true,
            fillColor:
                readOnly
                    ? Couleurs.fond
                    : Couleurs.blanc,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal:
                  12.0,
              vertical:
                  12.0,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8.0,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Couleurs.bordure,
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8.0,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Couleurs.bordure,
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                8.0,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Couleurs.primaire,
              ),
            ),
          ),
        ),
      ],
    );
  }
}