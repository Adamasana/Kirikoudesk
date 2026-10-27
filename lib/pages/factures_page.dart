import 'package:flutter/material.dart';

import '../models/facture.dart';
import '../repositories/facture_repository.dart';
import '../services/synchronisation/facture_sync_service.dart';
import '../theme/couleurs.dart';

class FacturesPage extends StatefulWidget {
  const FacturesPage({super.key});

  @override
  State<FacturesPage> createState() => _FacturesPageState();
}

class _FacturesPageState extends State<FacturesPage> {
  final TextEditingController _rechercheController =
      TextEditingController();

  final ScrollController _tableScrollController =
      ScrollController();

  final FactureRepository _factureRepository =
      const FactureRepository();

  final FactureSyncService _factureSyncService =
      FactureSyncService();

  List<Facture> _factures = [];

  String _recherche = '';

  bool _chargement = true;
  bool _synchronisationEnCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();

    _rechercheController.addListener(
      _mettreAJourRecherche,
    );

    _chargerFactures();
  }

  // ============================================================
  // CHARGEMENT DES FACTURES
  // ============================================================

  Future<void> _chargerFactures() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final factures =
          await _factureRepository.obtenirDerniers30Jours();

      if (!mounted) {
        return;
      }

      setState(() {
        _factures = factures;
        _chargement = false;
      });

      /*
       * Les données locales sont affichées immédiatement.
       *
       * La synchronisation distante se fait ensuite en arrière-plan.
       * Ainsi, une absence d'Internet ne bloque pas l'utilisation
       * de la page.
       */
      _synchroniserFactures();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _chargement = false;
        _erreur =
            'Impossible de charger les factures locales.';
      });
    }
  }

  // ============================================================
  // SYNCHRONISATION
  // ============================================================

  Future<void> _synchroniserFactures() async {
    if (_synchronisationEnCours) {
      return;
    }

    _synchronisationEnCours = true;

    try {
      await _factureSyncService.synchroniser();

      final factures =
          await _factureRepository.obtenirDerniers30Jours();

      if (!mounted) {
        return;
      }

      setState(() {
        _factures = factures;
      });
    } catch (_) {
      /*
       * Une erreur de synchronisation ne doit pas effacer
       * les données locales déjà disponibles.
       */
    } finally {
      _synchronisationEnCours = false;
    }
  }

  // ============================================================
  // RECHERCHE
  // ============================================================

  void _mettreAJourRecherche() {
    final nouvelleRecherche =
        _rechercheController.text.trim();

    if (nouvelleRecherche == _recherche) {
      return;
    }

    setState(() {
      _recherche = nouvelleRecherche;
    });

    _rechercherFactures(nouvelleRecherche);
  }

  Future<void> _rechercherFactures(
    String recherche,
  ) async {
    try {
      final factures =
          await _factureRepository.rechercher(
        recherche,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _factures = factures;
        _erreur = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erreur =
            'Impossible d’effectuer la recherche.';
      });
    }
  }

  @override
  void dispose() {
    _rechercheController.removeListener(
      _mettreAJourRecherche,
    );

    _rechercheController.dispose();
    _tableScrollController.dispose();

    _factureSyncService.dispose();

    super.dispose();
  }

  // ============================================================
  // FORMATAGE MONTANT
  // ============================================================

  String _formatMontant(int montant) {
    final valeur = montant.toString();

    final resultat = StringBuffer();

    for (int i = 0; i < valeur.length; i++) {
      final position = valeur.length - i;

      resultat.write(valeur[i]);

      if (position > 1 && position % 3 == 1) {
        resultat.write(' ');
      }
    }

    return resultat.toString();
  }

  // ============================================================
  // FORMATAGE DATE
  // ============================================================

  String _formaterDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    final jour =
        date.day.toString().padLeft(2, '0');

    final mois =
        date.month.toString().padLeft(2, '0');

    return '$jour/$mois/${date.year}';
  }

  // ============================================================
  // DATE FACTURE
  // ============================================================

  String _obtenirDateFacture(Facture facture) {
    return _formaterDate(
      facture.date ?? facture.dateCreation,
    );
  }

  // ============================================================
  // DETAILS
  // ============================================================

  void _ouvrirDetails(
    Facture facture,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _DetailsFactureDialog(
          facture: facture,
          formatMontant: _formatMontant,
          formaterDate: _obtenirDateFacture,
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleurs.fond,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, contraintes) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: contraintes.maxHeight,
                ),
                child: Padding(
                  padding: _obtenirPadding(
                    contraintes.maxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      _construireEntete(
                        contraintes.maxWidth,
                      ),
                      const SizedBox(height: 24),
                      _construireContenu(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // PADDING
  // ============================================================

  EdgeInsets _obtenirPadding(
    double largeur,
  ) {
    if (largeur <= 480) {
      return const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 12,
      );
    }

    if (largeur <= 768) {
      return const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      );
    }

    if (largeur <= 992) {
      return const EdgeInsets.all(18);
    }

    return const EdgeInsets.all(24);
  }

  // ============================================================
  // ENTETE
  // ============================================================

  Widget _construireEntete(
    double largeur,
  ) {
    final estMobile = largeur <= 768;

    final blocTitre = Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Factures',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: largeur <= 360
                ? 28
                : largeur <= 480
                    ? 30
                    : largeur <= 768
                        ? 32
                        : 34,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: const Color(0xFF171717),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(
            top: 5,
          ),
          child: Text(
            'Consultez vos factures',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w400,
              color: Color(0xFF777777),
            ),
          ),
        ),
      ],
    );

    final blocRecherche = SizedBox(
      width: estMobile
          ? double.infinity
          : largeur <= 992
              ? 280
              : 340,
      height: 48,
      child: TextField(
        controller: _rechercheController,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFF222222),
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher',
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: Color(0xFF999999),
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: Color(0xFF777777),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFFDEDEDE),
            ),
          ),
          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Couleurs.primaire,
            ),
          ),
        ),
      ),
    );

    if (estMobile) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          blocTitre,
          const SizedBox(height: 16),
          blocRecherche,
        ],
      );
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Expanded(
          child: blocTitre,
        ),
        const SizedBox(width: 25),
        blocRecherche,
      ],
    );
  }

  // ============================================================
  // CONTENU
  // ============================================================

  Widget _construireContenu() {
    if (_chargement) {
      return _construireChargement();
    }

    if (_erreur != null &&
        _factures.isEmpty) {
      return _construireErreur();
    }

    if (_factures.isEmpty) {
      return _construireEtatVide();
    }

    return _construireTableau(
      _factures,
    );
  }

  // ============================================================
  // CHARGEMENT
  // ============================================================

  Widget _construireChargement() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 330,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE5E5EA),
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Couleurs.primaire,
        ),
      ),
    );
  }

  // ============================================================
  // ERREUR
  // ============================================================

  Widget _construireErreur() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 330,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE5E5EA),
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 42,
            color: Couleurs.danger,
          ),
          const SizedBox(height: 16),
          Text(
            _erreur!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: Couleurs.muted,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _chargerFactures,
            style:
                ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor:
                  Couleurs.primaire,
              foregroundColor:
                  Colors.white,
            ),
            child: const Text(
              'Réessayer',
              style: TextStyle(
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLEAU
  // ============================================================

  Widget _construireTableau(
    List<Facture> factures,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE5E5EA),
        ),
        borderRadius:
            BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior:
          Clip.antiAlias,
      child: LayoutBuilder(
        builder: (
          context,
          contraintes,
        ) {
          return Table(
            columnWidths: const {
              0: FlexColumnWidth(1.05),
              1: FlexColumnWidth(1.45),
              2: FlexColumnWidth(1.15),
              3: FlexColumnWidth(1.05),
              4: FlexColumnWidth(1.15),
              5: FlexColumnWidth(1.45),
              6: FlexColumnWidth(1.10),
            },
            defaultVerticalAlignment:
                TableCellVerticalAlignment
                    .middle,
            children: [
              _construireEnteteTableau(),
              ...factures.map(
                _construireLigneTableau,
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // ENTETE TABLEAU
  // ============================================================

  TableRow _construireEnteteTableau() {
    const titres = [
      'No',
      'Nom',
      'Montant',
      'Remise',
      'Total',
      'Origine',
      'Date',
    ];

    return TableRow(
      decoration:
          const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E5EA),
            width: 1,
          ),
        ),
      ),
      children:
          titres.asMap().entries.map(
        (entry) {
          final index = entry.key;
          final titre = entry.value;

          return Container(
            height: 50,
            padding: EdgeInsets.only(
              left: index == 0
                  ? 22
                  : 18,
              right: index == 6
                  ? 22
                  : 18,
            ),
            alignment:
                Alignment.centerLeft,
            child: Text(
              titre,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                height: 1,
                fontWeight:
                    FontWeight.w900,
                letterSpacing: -0.1,
                color:
                    Couleurs.primaire,
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // LIGNE TABLEAU
  // ============================================================

  TableRow _construireLigneTableau(
    Facture facture,
  ) {
    final cellules = [
      _celluleTexte(
        facture,
        facture.idDjango?.toString() ??
            '-',
        fontWeight:
            FontWeight.w600,
        color: Couleurs.texte,
      ),
      _celluleTexte(
        facture,
        facture.nom,
        fontWeight:
            FontWeight.w500,
        color: Couleurs.muted,
      ),
      _celluleTexte(
        facture,
        '${_formatMontant(facture.montant)} FCFA',
        color: Couleurs.muted,
        nowrap: true,
      ),
      _celluleTexte(
        facture,
        '${_formatMontant(facture.remise)} FCFA',
        color: Couleurs.muted,
        nowrap: true,
      ),
      _celluleTexte(
        facture,
        '${_formatMontant(facture.total)} FCFA',
        color: Couleurs.muted,
        nowrap: true,
      ),
      _celluleTexte(
        facture,
        facture.origine,
        color: Couleurs.muted,
      ),
      _celluleTexte(
        facture,
        _obtenirDateFacture(facture),
        color: Couleurs.muted,
        nowrap: true,
      ),
    ];

    return TableRow(
      decoration:
          const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFEEEEEE),
            width: 1,
          ),
        ),
      ),
      children: cellules,
    );
  }

  // ============================================================
  // CELLULE TEXTE
  // ============================================================

  Widget _celluleTexte(
    Facture facture,
    String texte, {
    Color color = Couleurs.texte,
    FontWeight fontWeight =
        FontWeight.w400,
    bool nowrap = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _ouvrirDetails(facture),
        hoverColor:
            const Color(0xFFF8F8FA),
        child: Container(
          height: 62,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 18,
          ),
          alignment:
              Alignment.centerLeft,
          child: Text(
            texte,
            maxLines: 1,
            overflow: nowrap
                ? TextOverflow.clip
                : TextOverflow.ellipsis,
            softWrap: !nowrap,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.35,
              fontWeight: fontWeight,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ETAT VIDE
  // ============================================================

  Widget _construireEtatVide() {
    return Container(
      width: double.infinity,
      constraints:
          const BoxConstraints(
        minHeight: 330,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(
            0xFFE5E5EA,
          ),
        ),
        borderRadius:
            BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFF1F3F8),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            alignment:
                Alignment.center,
            child: const Icon(
              Icons.receipt_long,
              size: 27,
              color:
                  Couleurs.primaire,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Aucune facture disponible',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 21,
              height: 1.3,
              fontWeight:
                  FontWeight.w600,
              letterSpacing: -0.3,
              color:
                  Couleurs.texte,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            "Vous n'avez encore aucune facture.\n"
            'Pour créer une facture,',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              height: 1.6,
              fontWeight:
                  FontWeight.w400,
              color:
                  Color(0xFF777777),
            ),
          ),
          const Text(
            'validez une commande depuis la Caisse.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              height: 1.6,
              fontWeight:
                  FontWeight.w600,
              color:
                  Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// POPUP DE DETAILS
// ============================================================

class _DetailsFactureDialog
    extends StatelessWidget {
  final Facture facture;

  final String Function(int)
      formatMontant;

  final String Function(Facture)
      formaterDate;

  const _DetailsFactureDialog({
    required this.facture,
    required this.formatMontant,
    required this.formaterDate,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor:
          Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 460,
        ),
        child: Container(
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 60,
                offset:
                    Offset(0, 20),
              ),
            ],
          ),
          clipBehavior:
              Clip.antiAlias,
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              _construireEntete(
                context,
              ),
              _construireCorps(),
              _construirePied(
                context,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ENTETE POPUP
  // ============================================================

  Widget _construireEntete(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 19,
      ),
      decoration:
          const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Color(0xFFEEEEEE),
          ),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Détails de la facture',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 19,
                fontWeight:
                    FontWeight.w600,
                letterSpacing:
                    -0.2,
                color:
                    Couleurs.texte,
              ),
            ),
          ),
          _boutonFermer(context),
        ],
      ),
    );
  }

  // ============================================================
  // BOUTON FERMER
  // ============================================================

  Widget _boutonFermer(
    BuildContext context,
  ) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color:
            const Color(0xFFF5F5F7),
        borderRadius:
            BorderRadius.circular(
          8,
        ),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            8,
          ),
          onTap: () =>
              Navigator.of(
            context,
          ).pop(),
          child: const Icon(
            Icons.close,
            size: 19,
            color:
                Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CORPS
  // ============================================================

  Widget _construireCorps() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _ligneInformation(
            'ID Django',
            facture.idDjango
                    ?.toString() ??
                '-',
          ),
          _ligneInformation(
            'Client',
            facture.nom,
          ),
          _ligneInformation(
            'Téléphone',
            facture.telephone,
          ),
          _ligneInformation(
            'Origine',
            facture.origine,
          ),
          _ligneInformation(
            'Ville',
            facture.ville ?? '-',
          ),
          _ligneInformation(
            'Date',
            formaterDate(facture),
          ),
          _ligneInformation(
            'Montant',
            '${formatMontant(facture.montant)} FCFA',
          ),
          _ligneInformation(
            'Remise',
            '${formatMontant(facture.remise)} FCFA',
          ),
          _ligneInformation(
            'Livraison',
            '${formatMontant(facture.livraison)} FCFA',
          ),
          _ligneInformation(
            'Total',
            '${formatMontant(facture.total)} FCFA',
          ),
          const SizedBox(height: 16),
          const Text(
            'Produits',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight:
                  FontWeight.w600,
              color:
                  Couleurs.texte,
            ),
          ),
          const SizedBox(height: 8),
          if (facture.produits.isEmpty)
            const Text(
              'Aucun produit.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color:
                    Couleurs.muted,
              ),
            )
          else
            ...facture.produits.map(
              (achat) => Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 8,
                ),
                child: Text(
                  '${achat.produit.isEmpty ? achat.identifiant : achat.produit} × ${achat.quantite}',
                  style:
                      const TextStyle(
                    fontFamily:
                        'Inter',
                    fontSize: 14,
                    color:
                        Couleurs.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // LIGNE INFORMATION
  // ============================================================

  Widget _ligneInformation(
    String label,
    String valeur,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontFamily:
                    'Inter',
                fontSize: 14,
                fontWeight:
                    FontWeight.w600,
                color:
                    Couleurs.texte,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valeur,
              style:
                  const TextStyle(
                fontFamily:
                    'Inter',
                fontSize: 14,
                color:
                    Couleurs.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PIED
  // ============================================================

  Widget _construirePied(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 15,
      ),
      decoration:
          const BoxDecoration(
        border: Border(
          top: BorderSide(
            color:
                Color(0xFFEEEEEE),
          ),
        ),
      ),
      alignment:
          Alignment.centerRight,
      child: _boutonSecondaire(
        texte: 'Fermer',
        onTap: () =>
            Navigator.of(
          context,
        ).pop(),
      ),
    );
  }

  // ============================================================
  // BOUTON SECONDAIRE
  // ============================================================

  Widget _boutonSecondaire({
    required String texte,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        style:
            ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              const Color(
            0xFFF2F2F7,
          ),
          foregroundColor:
              const Color(
            0xFF333333,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              8,
            ),
            side:
                const BorderSide(
              color:
                  Color(0xFFE5E5EA),
            ),
          ),
        ),
        child: Text(
          texte,
          style:
              const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ),
    );
  }
}