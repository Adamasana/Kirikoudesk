
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/session.dart';
import '../services/inventaire/inventaire_service.dart';
import '../services/inventaire/scanner_usb_controller.dart';
import '../theme/couleurs.dart';

class InventairePage extends StatefulWidget {
  final bool estVisible;

  const InventairePage({
    super.key,
    this.estVisible = true,
  });

  @override
  State<InventairePage> createState() => _InventairePageState();
}

class _InventairePageState extends State<InventairePage> {
  final InventaireService _service = InventaireService();

  ScannerUsbController? _scanner;

  int? _inventaireId;
  int? _pointVenteId;
  int? _utilisateurId;

  int _totalScans = 0;

  List<Map<String, dynamic>> _scans = [];

  bool _chargement = true;
  bool _enregistrement = false;
  bool _suppressionEnCours = false;
  bool _annulationEnCours = false;
  bool _operationFichierEnCours = false;
  bool _validationEnCours = false;

  String? _erreur;

  // ============================================================
  // FORME COMMUNE À TOUS LES BOUTONS
  // ============================================================

  static const double _rayonBouton = 7;

  static final OutlinedBorder _formeBouton =
      RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_rayonBouton),
  );

  // Style explicite des boutons secondaires des popups.
  ButtonStyle _styleBoutonSecondairePopup({
    Color couleurTexte = Couleurs.texte,
    Color couleurBordure = Couleurs.bordure,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: couleurTexte,
      side: BorderSide(
        color: couleurBordure,
        width: 1,
      ),
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 10,
      ),
      shape: _formeBouton,
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // Style explicite des boutons principaux des popups.
  ButtonStyle _styleBoutonPrincipalPopup({
    Color couleur = Couleurs.primaire,
  }) {
    return FilledButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: couleur,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 10,
      ),
      shape: _formeBouton,
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ============================================================
  // THÈME DES BOUTONS DE LA PAGE
  // ============================================================

  ThemeData _themeBoutons(BuildContext context) {
    final theme = Theme.of(context);

    final style = ButtonStyle(
      shape: WidgetStatePropertyAll(_formeBouton),
    );

    return theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: style,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: style,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: style,
      ),
      textButtonTheme: TextButtonThemeData(
        style: style,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: style,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  // ============================================================
  // GESTION DE LA VISIBILITÉ
  // ============================================================

  @override
  void didUpdateWidget(covariant InventairePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.estVisible == widget.estVisible) {
      return;
    }

    if (!widget.estVisible) {
      _desactiverScanner();
    } else {
      if (_inventaireId != null &&
          !_annulationEnCours &&
          !_validationEnCours) {
        _activerScanner();
      }
    }
  }

  // ============================================================
  // INITIALISATION
  // ============================================================

  Future<void> _initialiser() async {
    try {
      final session = await Session.fromPreferences();

      if (session == null || session.token.isEmpty) {
        throw Exception('Session utilisateur introuvable.');
      }

      if (session.pointVenteId == null ||
          session.pointVenteId! <= 0) {
        throw Exception(
          'Aucun point de vente associé à cette session.',
        );
      }

      if (session.utilisateurId <= 0) {
        throw Exception(
          'Identifiant utilisateur local invalide.',
        );
      }

      _pointVenteId = session.pointVenteId;
      _utilisateurId = session.utilisateurId;

      final inventaire = await _service.obtenirSessionEnCours(
        pointVenteId: _pointVenteId!,
      );

      if (!mounted) return;

      if (inventaire != null && inventaire.id != null) {
        _inventaireId = inventaire.id;

        await _actualiserScans();

        if (!mounted) return;

        if (widget.estVisible) {
          _activerScanner();
        }
      }
    } catch (e) {
      if (mounted) {
        _erreur = e
            .toString()
            .replaceFirst('Exception: ', '');
      }
    } finally {
      if (mounted) {
        setState(() {
          _chargement = false;
        });
      }
    }
  }

  // ============================================================
  // ACTIVER LE SCANNER USB
  // ============================================================

  void _activerScanner() {
    if (!mounted ||
        !widget.estVisible ||
        _inventaireId == null ||
        _annulationEnCours ||
        _validationEnCours) {
      return;
    }

    _desactiverScanner();

    _scanner = ScannerUsbController(
      onCodeScanne: _traiterScan,
      estActif: () {
        return mounted &&
            widget.estVisible &&
            !_annulationEnCours &&
            !_validationEnCours &&
            ModalRoute.of(context)?.isCurrent != false &&
            _inventaireId != null;
      },
      onErreur: (erreur) {
        if (!mounted || !widget.estVisible) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur scan : $erreur'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );

    _scanner!.demarrer();
  }

  // ============================================================
  // DÉSACTIVER LE SCANNER USB
  // ============================================================

  void _desactiverScanner() {
    _scanner?.dispose();
    _scanner = null;
  }

  // ============================================================
  // DÉMARRER UN NOUVEL INVENTAIRE
  // ============================================================

  Future<void> _demarrerNouvelInventaire() async {
    if (_inventaireId != null ||
        _operationFichierEnCours ||
        _pointVenteId == null) {
      return;
    }

    setState(() {
      _operationFichierEnCours = true;
      _erreur = null;
    });

    try {
      final id = await _service.demarrerInventaire(
        pointVenteId: _pointVenteId!,
        utilisateurId: _utilisateurId,
      );

      if (!mounted) return;

      setState(() {
        _inventaireId = id;
        _scans = [];
        _totalScans = 0;
      });

      if (widget.estVisible) {
        _activerScanner();
      }
    } catch (e) {
      if (!mounted) return;

      await _rechargerSessionExistante();

      if (!mounted) return;

      _afficherMessage(
        'Impossible de démarrer l’inventaire : $e',
        erreur: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _operationFichierEnCours = false;
        });
      }
    }
  }

  // ============================================================
  // RECHARGER UNE SESSION EXISTANTE
  // ============================================================

  Future<void> _rechargerSessionExistante() async {
    final pointVenteId = _pointVenteId;

    if (pointVenteId == null) return;

    try {
      final inventaire = await _service.obtenirSessionEnCours(
        pointVenteId: pointVenteId,
      );

      if (!mounted) return;

      if (inventaire != null && inventaire.id != null) {
        setState(() {
          _inventaireId = inventaire.id;
        });

        await _actualiserScans();

        if (mounted &&
            widget.estVisible &&
            !_validationEnCours) {
          _activerScanner();
        }
      }
    } catch (e) {
      debugPrint(
        'Erreur récupération inventaire existant : $e',
      );
    }
  }

  // ============================================================
  // TRAITEMENT D'UN SCAN
  // ============================================================

  Future<void> _traiterScan(String code) async {
    final inventaireId = _inventaireId;

    if (!mounted ||
        !widget.estVisible ||
        inventaireId == null ||
        _annulationEnCours ||
        _validationEnCours) {
      return;
    }

    setState(() {
      _enregistrement = true;
    });

    try {
      await _service.enregistrerScan(
        inventaireId: inventaireId,
        code: code,
      );

      if (!mounted) return;

      if (_inventaireId != inventaireId) return;

      await _actualiserScans();
    } catch (e) {
      if (!mounted || !widget.estVisible) return;

      _afficherMessage(
        'Impossible d’enregistrer le scan : $e',
        erreur: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _enregistrement = false;
        });
      }
    }
  }

  // ============================================================
  // ACTUALISER LES SCANS
  // ============================================================

  Future<void> _actualiserScans() async {
    final inventaireId = _inventaireId;

    if (inventaireId == null) return;

    final resultats =
        await _service.obtenirScans(inventaireId);

    final total =
        await _service.compterScans(inventaireId);

    if (!mounted || _inventaireId != inventaireId) {
      return;
    }

    setState(() {
      _scans = resultats;
      _totalScans = total;
    });
  }

  // ============================================================
  // CONFIRMATION DE VALIDATION
  // ============================================================

  Future<String?> _confirmerValidation() async {
    String? typeInventaire;

    final typeChoisi = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: Couleurs.primaire,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Valider l’inventaire',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Couleurs.texte,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vous êtes sur le point de valider cet inventaire.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.5,
                      color: Couleurs.texte,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Type d’inventaire',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Couleurs.texte,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Inventaire total : les produits absents seront
                  // considérés comme ayant une quantité nulle.
                  RadioListTile<String>(
                    value: 'total',
                    groupValue: typeInventaire,
                    onChanged: (value) {
                      setDialogState(() {
                        typeInventaire = value;
                      });
                    },
                    activeColor: Couleurs.primaire,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Inventaire total',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Couleurs.texte,
                      ),
                    ),
                    subtitle: const Text(
                      'Les produits absents seront considérés comme '
                      'n’ayant aucun stock.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        height: 1.4,
                        color: Couleurs.muted,
                      ),
                    ),
                  ),

                  // Inventaire partiel : les produits absents
                  // conserveront leur stock actuel.
                  RadioListTile<String>(
                    value: 'partiel',
                    groupValue: typeInventaire,
                    onChanged: (value) {
                      setDialogState(() {
                        typeInventaire = value;
                      });
                    },
                    activeColor: Couleurs.primaire,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Inventaire partiel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Couleurs.texte,
                      ),
                    ),
                    subtitle: const Text(
                      'Les produits absents conserveront leur stock actuel.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        height: 1.4,
                        color: Couleurs.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Couleurs.fond,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: Couleurs.bordure,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.qr_code_scanner,
                          color: Couleurs.primaire,
                          size: 25,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Nombre total de scans',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Couleurs.muted,
                            ),
                          ),
                        ),
                        Text(
                          '$_totalScans',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Couleurs.primaire,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Après confirmation, les données seront envoyées au '
                    'serveur et traitées. Cette opération ne pourra plus '
                    'être annulée depuis cet écran.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.5,
                      color: Couleurs.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Voulez-vous continuer ?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Couleurs.texte,
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                16,
              ),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  style: _styleBoutonSecondairePopup(),
                  child: const Text('Retour'),
                ),
                FilledButton.icon(
                  onPressed: typeInventaire == null
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            typeInventaire,
                          );
                        },
                  icon: const Icon(
                    Icons.cloud_upload_outlined,
                    size: 18,
                  ),
                  label: const Text('Confirmer'),
                  style: _styleBoutonPrincipalPopup(),
                ),
              ],
            );
          },
        );
      },
    );

    return typeChoisi;
  }

  // ============================================================
  // VALIDER L'INVENTAIRE AUPRÈS DE DJANGO
  // ============================================================

  Future<void> _validerInventaire() async {
    final inventaireId = _inventaireId;
    final pointVenteId = _pointVenteId;

    if (_validationEnCours ||
        _enregistrement ||
        _suppressionEnCours ||
        _annulationEnCours ||
        _operationFichierEnCours ||
        inventaireId == null ||
        pointVenteId == null ||
        _scans.isEmpty) {
      return;
    }

    final typeInventaire = await _confirmerValidation();

    if (!mounted || typeInventaire == null) return;

    if (_validationEnCours ||
        _enregistrement ||
        _suppressionEnCours ||
        _annulationEnCours ||
        _operationFichierEnCours ||
        _inventaireId != inventaireId ||
        _scans.isEmpty) {
      return;
    }

    setState(() {
      _validationEnCours = true;
      _erreur = null;
    });

    _desactiverScanner();

    try {
      await _service.validerInventaire(
        inventaireId: inventaireId,
        pointVenteId: pointVenteId,
        typeInventaire: typeInventaire,
      );

      if (!mounted) return;

      setState(() {
        _inventaireId = null;
        _scans = [];
        _totalScans = 0;
        _enregistrement = false;
      });

      _afficherMessage(
        'Inventaire validé avec succès auprès de Django.',
      );
    } catch (e) {
      if (!mounted) return;

      _afficherMessage(
        'Échec de la validation : $e\n'
        'Les scans ont été conservés. Vous pouvez réessayer.',
        erreur: true,
      );

      await _rechargerSessionExistante();
    } finally {
      if (mounted) {
        setState(() {
          _validationEnCours = false;
        });

        if (_inventaireId != null && widget.estVisible) {
          _activerScanner();
        }
      }
    }
  }

  // ============================================================
  // IMPORTER UN FICHIER JSON
  // ============================================================

  Future<void> _importerJson() async {
    if (_inventaireId != null ||
        _operationFichierEnCours ||
        _pointVenteId == null) {
      return;
    }

    setState(() {
      _operationFichierEnCours = true;
      _erreur = null;
    });

    try {
      final resultat = await FilePicker.pickFiles(
        dialogTitle: 'Sélectionner un inventaire JSON',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (!mounted) return;

      if (resultat == null || resultat.files.isEmpty) {
        return;
      }

      final fichier = resultat.files.single;
      final bytes = fichier.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw FormatException(
          'Impossible de lire le fichier sélectionné.',
        );
      }

      final contenu = utf8.decode(bytes);
      final donnees = jsonDecode(contenu);

      if (donnees is! Map<String, dynamic>) {
        throw FormatException(
          'Le contenu du fichier JSON est invalide.',
        );
      }

      if (donnees['format'] != InventaireService.formatJson) {
        throw FormatException(
          'Ce fichier ne correspond pas au format '
          'd’inventaire KirikouBF.',
        );
      }

      if (donnees['version'] != InventaireService.versionJson) {
        throw FormatException(
          'La version de ce fichier JSON n’est pas prise en charge.',
        );
      }

      final scansJson = donnees['scans'];

      if (scansJson is! List || scansJson.isEmpty) {
        throw FormatException(
          'Le fichier ne contient aucun scan.',
        );
      }

      for (final element in scansJson) {
        if (element is! Map) {
          throw FormatException(
            'Une ligne du fichier JSON est invalide.',
          );
        }

        final code = element['code'];
        final quantite = element['quantite'];

        if (code is! String || code.trim().isEmpty) {
          throw FormatException(
            'Un code du fichier JSON est vide ou invalide.',
          );
        }

        if (quantite is! int || quantite <= 0) {
          throw FormatException(
            'La quantité du code "$code" est invalide.',
          );
        }
      }

      if (!mounted) return;

      final confirmer = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Importer cet inventaire ?'),
            content: Text(
              'Le fichier "${fichier.name}" contient '
              '${scansJson.length} ligne(s) de codes regroupés.\n\n'
              'Les quantités seront transformées en scans '
              'individuels et affichées dans l’inventaire.\n\n'
              'Continuer ?',
            ),
            actions: [
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
                style: _styleBoutonSecondairePopup(),
                child: const Text('Retour'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
                style: _styleBoutonPrincipalPopup(),
                child: const Text('Importer'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmer != true) return;

      final id = await _service.importerInventaire(
        pointVenteId: _pointVenteId!,
        utilisateurId: _utilisateurId,
        scansJson: scansJson,
      );

      if (!mounted) return;

      setState(() {
        _inventaireId = id;
      });

      await _actualiserScans();

      if (!mounted) return;

      if (widget.estVisible) {
        _activerScanner();
      }

      _afficherMessage(
        'Inventaire importé avec succès : $_totalScans scan(s).',
      );
    } catch (e) {
      if (!mounted) return;

      _afficherMessage(
        'Erreur lors de l’importation : $e',
        erreur: true,
      );

      await _rechargerSessionExistante();
    } finally {
      if (mounted) {
        setState(() {
          _operationFichierEnCours = false;
        });
      }
    }
  }

  // ============================================================
  // EXPORTER UN FICHIER JSON
  // ============================================================

  Future<void> _exporterJson() async {
    final inventaireId = _inventaireId;

    if (inventaireId == null ||
        _operationFichierEnCours ||
        _annulationEnCours) {
      return;
    }

    setState(() {
      _operationFichierEnCours = true;
    });

    try {
      final donnees =
          await _service.exporterInventaire(inventaireId);

      final contenu = const JsonEncoder.withIndent('  ')
          .convert(donnees);

      final maintenant = DateTime.now();

      final nomFichier =
          'inventaire_${maintenant.year}'
          '${maintenant.month.toString().padLeft(2, '0')}'
          '${maintenant.day.toString().padLeft(2, '0')}_'
          '${maintenant.hour.toString().padLeft(2, '0')}'
          '${maintenant.minute.toString().padLeft(2, '0')}'
          '${maintenant.second.toString().padLeft(2, '0')}.json';

      final chemin = await FilePicker.saveFile(
        dialogTitle: 'Exporter l’inventaire',
        fileName: nomFichier,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(contenu)),
      );

      if (!mounted) return;

      if (chemin != null) {
        _afficherMessage(
          'Inventaire exporté avec succès.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _afficherMessage(
        'Erreur lors de l’exportation : $e',
        erreur: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _operationFichierEnCours = false;
        });
      }
    }
  }

  // ============================================================
  // SUPPRIMER UN SCAN
  // ============================================================

  Future<void> _supprimerScan(int scanId) async {
    if (_suppressionEnCours ||
        _annulationEnCours ||
        _validationEnCours ||
        _operationFichierEnCours) {
      return;
    }

    setState(() {
      _suppressionEnCours = true;
    });

    try {
      await _service.supprimerScan(scanId);

      await _actualiserScans();
    } catch (e) {
      if (!mounted) return;

      _afficherMessage(
        'Erreur lors de la suppression : $e',
        erreur: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _suppressionEnCours = false;
        });
      }
    }
  }

  // ============================================================
  // ANNULER L'INVENTAIRE
  // ============================================================

  Future<void> _annulerInventaire() async {
    if (_annulationEnCours ||
        _validationEnCours ||
        _operationFichierEnCours) {
      return;
    }

    final confirmer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Annuler l’inventaire ?'),
          content: const Text(
            'Tous les scans de cet inventaire seront '
            'supprimés définitivement. '
            'Voulez-vous continuer ?',
          ),
          actions: [
            OutlinedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              style: _styleBoutonSecondairePopup(),
              child: const Text('Retour'),
            ),
            FilledButton(
              style: _styleBoutonPrincipalPopup(
                couleur: Couleurs.danger,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmer != true) return;

    final id = _inventaireId;

    if (id == null) return;

    setState(() {
      _annulationEnCours = true;
    });

    _desactiverScanner();

    try {
      await _service.annulerInventaire(id);

      final sessionRestante =
          await _service.obtenirSessionEnCours(
        pointVenteId: _pointVenteId!,
      );

      if (sessionRestante != null) {
        throw StateError(
          'Une session active existe encore après l’annulation. '
          'Identifiant : ${sessionRestante.id}.',
        );
      }

      if (!mounted) return;

      setState(() {
        _inventaireId = null;
        _scans = [];
        _totalScans = 0;
        _enregistrement = false;
      });

      _afficherMessage('Inventaire annulé.');
    } catch (e) {
      if (!mounted) return;

      _afficherMessage(
        'Erreur lors de l’annulation : $e',
        erreur: true,
      );

      await _rechargerSessionExistante();
    } finally {
      if (mounted) {
        setState(() {
          _annulationEnCours = false;
        });

        if (_inventaireId != null && widget.estVisible) {
          _activerScanner();
        }
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _afficherMessage(
    String message, {
    bool erreur = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            erreur ? Couleurs.danger : null,
      ),
    );
  }

  @override
  void dispose() {
    _desactiverScanner();
    super.dispose();
  }

  // ============================================================
  // CONSTRUCTION
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _themeBoutons(context),
      child: Builder(
        builder: (context) {
          if (_chargement) {
            return const Center(
              child: CircularProgressIndicator(
                color: Couleurs.primaire,
              ),
            );
          }

          if (_erreur != null && _inventaireId == null) {
            return _construireErreur();
          }

          if (_inventaireId == null) {
            return _construireAccueil();
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _construireBarreInformations(),
                const SizedBox(height: 20),
                Expanded(
                  child: _construireGrilleScans(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ÉCRAN D'ACCUEIL SANS SESSION
  // ============================================================

  Widget _construireAccueil() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Couleurs.blanc,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Couleurs.bordure,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Couleurs.primaire.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  size: 34,
                  color: Couleurs.primaire,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Gestion des inventaires',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Couleurs.texte,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Démarrez un nouvel inventaire ou '
                'reprenez un inventaire depuis un fichier JSON.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Couleurs.muted,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: _operationFichierEnCours
                      ? null
                      : _demarrerNouvelInventaire,
                  icon: const Icon(
                    Icons.add,
                    size: 19,
                  ),
                  label: const Text(
                    'Nouvel inventaire',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Couleurs.primaire,
                    shape: _formeBouton,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _operationFichierEnCours
                      ? null
                      : _importerJson,
                  icon: const Icon(
                    Icons.upload_file,
                    size: 19,
                  ),
                  label: const Text(
                    'Importer un fichier JSON',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Couleurs.primaire,
                    side: const BorderSide(
                      color: Couleurs.primaire,
                    ),
                    shape: _formeBouton,
                  ),
                ),
              ),
              if (_operationFichierEnCours) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(
                  color: Couleurs.primaire,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ÉCRAN D'ERREUR
  // ============================================================

  Widget _construireErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 42,
              color: Couleurs.danger,
            ),
            const SizedBox(height: 12),
            Text(
              _erreur!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Couleurs.texte,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _chargement = true;
                  _erreur = null;
                });

                _initialiser();
              },
              style: FilledButton.styleFrom(
                shape: _formeBouton,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BARRE D'INFORMATIONS
  // ============================================================

  Widget _construireBarreInformations() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Couleurs.blanc,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Couleurs.bordure,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Couleurs.primaire.withValues(
                alpha: 0.08,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              color: Couleurs.primaire,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventaire en cours',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Couleurs.texte,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scannez les codes avec votre lecteur USB.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Couleurs.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _construireCompteur(),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _operationFichierEnCours ||
                    _annulationEnCours ||
                    _validationEnCours
                ? null
                : _exporterJson,
            icon: const Icon(
              Icons.download,
              size: 17,
            ),
            label: const Text('Exporter JSON'),
            style: OutlinedButton.styleFrom(
              shape: _formeBouton,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _validationEnCours ||
                    _enregistrement ||
                    _suppressionEnCours ||
                    _annulationEnCours ||
                    _operationFichierEnCours ||
                    _scans.isEmpty
                ? null
                : _validerInventaire,
            icon: _validationEnCours
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.check_circle_outline,
                    size: 17,
                  ),
            label: Text(
              _validationEnCours
                  ? 'Validation...'
                  : 'Valider',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Couleurs.primaire,
              shape: _formeBouton,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _annulationEnCours ||
                    _validationEnCours ||
                    _operationFichierEnCours
                ? null
                : _annulerInventaire,
            icon: const Icon(
              Icons.close,
              size: 17,
            ),
            label: const Text('Annuler'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Couleurs.danger,
              side: const BorderSide(
                color: Couleurs.danger,
              ),
              shape: _formeBouton,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPTEUR
  // ============================================================

  Widget _construireCompteur() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Couleurs.fond,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$_totalScans',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Couleurs.primaire,
            ),
          ),
          const Text(
            'SCANS',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Couleurs.muted,
            ),
          ),
          if (_enregistrement)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Couleurs.primaire,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // GRILLE DES SCANS
  // ============================================================

  Widget _construireGrilleScans() {
    if (_scans.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Couleurs.blanc,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Couleurs.bordure,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2,
              size: 64,
              color: Couleurs.muted.withValues(
                alpha: 0.35,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'En attente du premier scan',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Couleurs.texte,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Les codes scannés apparaîtront ici.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Couleurs.muted,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 68,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _scans.length,
      itemBuilder: (context, index) {
        final scan = _scans[index];

        return _construireCarteScan(
          id: scan['id'] as int,
          code: scan['code']?.toString() ?? '',
        );
      },
    );
  }

  // ============================================================
  // CARTE D'UN SCAN
  // ============================================================

  Widget _construireCarteScan({
    required int id,
    required String code,
  }) {
    return Container(
      padding: const EdgeInsets.only(
        left: 13,
        right: 5,
      ),
      decoration: BoxDecoration(
        color: Couleurs.blanc,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Couleurs.bordure,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.qr_code_2,
            size: 21,
            color: Couleurs.primaire,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Couleurs.texte,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Supprimer ce scan',
            visualDensity: VisualDensity.compact,
            onPressed: _suppressionEnCours ||
                    _annulationEnCours ||
                    _validationEnCours
                ? null
                : () => _supprimerScan(id),
            style: IconButton.styleFrom(
              shape: _formeBouton,
            ),
            icon: const Icon(
              Icons.close,
              size: 17,
              color: Couleurs.danger,
            ),
          ),
        ],
      ),
    );
  }
}
