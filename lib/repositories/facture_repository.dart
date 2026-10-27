import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/facture.dart';

class FactureRepository {
  const FactureRepository();

  // ============================================================
  // FACTURES
  // ============================================================

  Future<List<Facture>> obtenirToutes() async {
    final db = await DatabaseHelper.obtenirBase();

    final commandes = await db.query(
      DatabaseTables.commande,
      where:
          'statut_local = ? '
          'AND origine = ?',
      whereArgs: [
        'Facture',
        'Caisse',
      ],
      orderBy: 'date_creation DESC',
    );

    final factures = <Facture>[];

    for (final commande in commandes) {
      factures.add(
        await _construireFacture(
          db,
          commande,
        ),
      );
    }

    return factures;
  }

  // ============================================================
  // 30 DERNIERS JOURS
  // ============================================================

  Future<List<Facture>> obtenirDerniers30Jours() async {
    final db = await DatabaseHelper.obtenirBase();

    final dateLimite = DateTime.now().subtract(
      const Duration(days: 30),
    );

    final commandes = await db.query(
      DatabaseTables.commande,
      where:
          'statut_local = ? '
          'AND origine = ? '
          'AND date_creation >= ?',
      whereArgs: [
        'Facture',
        'Caisse',
        dateLimite.toIso8601String(),
      ],
      orderBy: 'date_creation DESC',
    );

    final factures = <Facture>[];

    for (final commande in commandes) {
      factures.add(
        await _construireFacture(
          db,
          commande,
        ),
      );
    }

    return factures;
  }

  // ============================================================
  // FACTURE PAR ID LOCAL
  // ============================================================

  Future<Facture?> obtenirParId(
    int id,
  ) async {
    final db = await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.commande,
      where:
          'id = ? '
          'AND statut_local = ? '
          'AND origine = ?',
      whereArgs: [
        id,
        'Facture',
        'Caisse',
      ],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return _construireFacture(
      db,
      resultats.first,
    );
  }

  // ============================================================
  // FACTURE PAR ID DJANGO
  // ============================================================

  Future<Facture?> obtenirParIdDjango(
    int idDjango,
  ) async {
    final db = await DatabaseHelper.obtenirBase();

    final resultats = await db.query(
      DatabaseTables.commande,
      where:
          'id_django = ? '
          'AND statut_local = ? '
          'AND origine = ?',
      whereArgs: [
        idDjango,
        'Facture',
        'Caisse',
      ],
      limit: 1,
    );

    if (resultats.isEmpty) {
      return null;
    }

    return _construireFacture(
      db,
      resultats.first,
    );
  }

  // ============================================================
  // RECHERCHE
  // ============================================================

  Future<List<Facture>> rechercher(
    String recherche,
  ) async {
    final texte = recherche.trim();

    if (texte.isEmpty) {
      return obtenirDerniers30Jours();
    }

    final db = await DatabaseHelper.obtenirBase();

    final dateLimite = DateTime.now().subtract(
      const Duration(days: 30),
    );

    final idDjango = int.tryParse(texte);

    String where =
        'statut_local = ? '
        'AND origine = ? '
        'AND date_creation >= ? '
        'AND (nom LIKE ? OR telephone LIKE ?';

    final whereArgs = <dynamic>[
      'Facture',
      'Caisse',
      dateLimite.toIso8601String(),
      '%$texte%',
      '%$texte%',
    ];

    if (idDjango != null) {
      where += ' OR id_django = ?';
      whereArgs.add(idDjango);
    }

    where += ')';

    final commandes = await db.query(
      DatabaseTables.commande,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date_creation DESC',
    );

    final factures = <Facture>[];

    for (final commande in commandes) {
      factures.add(
        await _construireFacture(
          db,
          commande,
        ),
      );
    }

    return factures;
  }

  // ============================================================
  // SUPPRIMER UNE FACTURE LOCALE
  // ============================================================

  Future<void> supprimer(
    int id,
  ) async {
    final db = await DatabaseHelper.obtenirBase();

    await db.transaction(
      (transaction) async {
        await transaction.delete(
          DatabaseTables.shop,
          where: 'commande_id = ?',
          whereArgs: [id],
        );

        await transaction.delete(
          DatabaseTables.synchronisation,
          where: 'commande_locale_id = ?',
          whereArgs: [id],
        );

        await transaction.delete(
          DatabaseTables.commande,
          where: 'id = ?',
          whereArgs: [id],
        );
      },
    );
  }

  // ============================================================
  // CONSTRUIRE UNE FACTURE
  // ============================================================

  Future<Facture> _construireFacture(
    DatabaseExecutor db,
    Map<String, dynamic> commande,
  ) async {
    final commandeId =
        commande['id'] as int;

    final shops = await db.query(
      DatabaseTables.shop,
      where: 'commande_id = ?',
      whereArgs: [commandeId],
      orderBy: 'id ASC',
    );

    final produits = <Achat>[];

    for (final shop in shops) {
      final articleId = _convertirEnInt(
        shop['article_id'],
      );

      String identifiant = '';
      String produit = '';

      if (articleId != null) {
        final sousProduits = await db.query(
          DatabaseTables.sousProduit,
          columns: [
            'identifiant',
            'produit_id',
          ],
          where: 'id = ?',
          whereArgs: [articleId],
          limit: 1,
        );

        if (sousProduits.isNotEmpty) {
          final sousProduit =
              sousProduits.first;

          identifiant =
              sousProduit['identifiant']
                      ?.toString() ??
                  '';

          final produitId =
              _convertirEnInt(
            sousProduit['produit_id'],
          );

          if (produitId != null) {
            final produitsResultats =
                await db.query(
              DatabaseTables.produit,
              columns: ['nom'],
              where: 'id = ?',
              whereArgs: [produitId],
              limit: 1,
            );

            if (produitsResultats.isNotEmpty) {
              produit =
                  produitsResultats.first['nom']
                          ?.toString() ??
                      '';
            }
          }
        }
      }

      produits.add(
        Achat(
          id:
              _convertirEnInt(
                    shop['id'],
                  ) ??
                  0,

          articleId:
              articleId,

          identifiant:
              identifiant,

          produit:
              produit,

          couleur:
              shop['couleur']?.toString() ??
                  '',

          pointure:
              shop['pointure']?.toString() ??
                  '',

          quantite:
              _convertirEnInt(
                    shop['quantite'],
                  ) ??
                  0,

          prix:
              _convertirEnInt(
                    shop['prix'],
                  ) ??
                  0,

          montant:
              _convertirEnInt(
                    shop['montant'],
                  ) ??
                  0,

          statut:
              shop['statut']?.toString() ??
                  '',

          date:
              _convertirDate(
                shop['date'],
              ),
        ),
      );
    }

    return Facture(
      id:
          commandeId,

      // ========================================================
      // ID DJANGO
      // ========================================================

      idDjango:
          _convertirEnInt(
            commande['id_django'],
          ),

      // ========================================================
      // CLIENT
      // ========================================================

      nom:
          commande['nom']?.toString() ??
              '',

      telephone:
          commande['telephone']?.toString() ??
              '',

      ville:
          commande['ville']?.toString(),

      deplacement:
          commande['deplacement']?.toString(),

      // ========================================================
      // MONTANTS
      // ========================================================

      montant:
          _convertirEnInt(
                commande['montant'],
              ) ??
              0,

      remise:
          _convertirEnInt(
                commande['remise'],
              ) ??
              0,

      livraison:
          _convertirEnInt(
                commande['livraison'],
              ) ??
              0,

      total:
          _convertirEnInt(
                commande['total'],
              ) ??
              0,

      // ========================================================
      // ÉTAT
      // ========================================================

      payer:
          commande['payer']?.toString() ??
              'Non',

      statut:
          commande['statut_local']?.toString() ??
              'Facture',

      origine:
          commande['origine']?.toString() ??
              'Caisse',

      // ========================================================
      // DATE DE LA FACTURE
      // ========================================================
      //
      // date_validation = date réelle de validation de la vente.
      //
      // C'est cette valeur qui correspond à la date de la
      // facture.
      //
      // Côté Django :
      //
      // Commande.date = date_validation
      //
      // ========================================================

      date:
          _convertirDate(
            commande['date_validation'],
          ),

      // ========================================================
      // DATES LOCALES
      // ========================================================

      dateCreation:
          DateTime.parse(
        commande['date_creation'].toString(),
      ),

      datePaiement:
          _convertirDate(
        commande['date_paiement'],
      ),

      dateConfirmation:
          _convertirDate(
        commande['date_confirmation'],
      ),

      dateUpdate:
          _convertirDate(
        commande['date_update'],
      ),

      // ========================================================
      // ARTICLES
      // ========================================================

      produits:
          produits,
    );
  }

  // ============================================================
  // CONVERSION EN ENTIER
  // ============================================================

  int? _convertirEnInt(
    dynamic valeur,
  ) {
    if (valeur == null) {
      return null;
    }

    if (valeur is int) {
      return valeur;
    }

    if (valeur is num) {
      return valeur.toInt();
    }

    return int.tryParse(
      valeur.toString(),
    );
  }

  // ============================================================
  // CONVERSION EN DATE
  // ============================================================

  DateTime? _convertirDate(
    dynamic valeur,
  ) {
    if (valeur == null) {
      return null;
    }

    final texte =
        valeur.toString().trim();

    if (texte.isEmpty) {
      return null;
    }

    return DateTime.tryParse(
      texte,
    );
  }
}