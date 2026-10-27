import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/dashboard_statistiques.dart';

class DashboardStatistiquesRepository {
  const DashboardStatistiquesRepository();

  // ============================================================
  // STATISTIQUES DASHBOARD DU JOUR
  // ============================================================
  //
  // RÈGLES LOCALES :
  //
  // statut_local = Caisse
  // origine      = Caisse
  // date_creation = aujourd'hui
  //
  // VENTES :
  // somme de commande.total
  //
  // ACHATS :
  // somme de shop.quantite
  //
  // COMMANDES :
  // nombre de commandes correspondantes
  //
  // CLIENTS :
  // numéros de téléphone distincts
  //
  // Les 5 dernières factures ne sont pas récupérées ici.
  // Elles sont envoyées directement par l'API Dashboard.
  //
  // ============================================================

  Future<DashboardStatistiques>
      obtenirStatistiquesDuJour() async {
    final db = await DatabaseHelper.obtenirBase();

    final maintenant = DateTime.now();

    final debutJour = DateTime(
      maintenant.year,
      maintenant.month,
      maintenant.day,
    );

    final debutDemain = debutJour.add(
      const Duration(days: 1),
    );

    final debutJourIso =
        debutJour.toIso8601String();

    final debutDemainIso =
        debutDemain.toIso8601String();

    // ==========================================================
    // VENTES
    // ==========================================================

    final ventesResultat = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total), 0) AS total
      FROM ${DatabaseTables.commande}
      WHERE statut_local = ?
        AND origine = ?
        AND date_creation >= ?
        AND date_creation < ?
      ''',
      [
        'Caisse',
        'Caisse',
        debutJourIso,
        debutDemainIso,
      ],
    );

    final ventes = _convertirEnInt(
      ventesResultat.first['total'],
    );

    // ==========================================================
    // ACHATS
    // ==========================================================
    //
    // On prend uniquement les Shops appartenant aux commandes
    // correspondant aux critères du Dashboard.
    //
    // ==========================================================

    final achatsResultat = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(shop.quantite), 0) AS total
      FROM ${DatabaseTables.shop} AS shop
      INNER JOIN ${DatabaseTables.commande} AS commande
        ON commande.id = shop.commande_id
      WHERE commande.statut_local = ?
        AND commande.origine = ?
        AND commande.date_creation >= ?
        AND commande.date_creation < ?
      ''',
      [
        'Caisse',
        'Caisse',
        debutJourIso,
        debutDemainIso,
      ],
    );

    final achats = _convertirEnInt(
      achatsResultat.first['total'],
    );

    // ==========================================================
    // NOMBRE DE COMMANDES
    // ==========================================================

    final commandesResultat = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseTables.commande}
      WHERE statut_local = ?
        AND origine = ?
        AND date_creation >= ?
        AND date_creation < ?
      ''',
      [
        'Caisse',
        'Caisse',
        debutJourIso,
        debutDemainIso,
      ],
    );

    final commandes = _convertirEnInt(
      commandesResultat.first['total'],
    );

    // ==========================================================
    // CLIENTS
    // ==========================================================
    //
    // DISTINCT permet de ne récupérer qu'une seule fois chaque
    // numéro de téléphone.
    //
    // Les téléphones vides sont ignorés.
    //
    // ==========================================================

    final telephonesResultat = await db.rawQuery(
      '''
      SELECT DISTINCT telephone
      FROM ${DatabaseTables.commande}
      WHERE statut_local = ?
        AND origine = ?
        AND date_creation >= ?
        AND date_creation < ?
        AND telephone IS NOT NULL
        AND TRIM(telephone) != ''
      ORDER BY telephone ASC
      ''',
      [
        'Caisse',
        'Caisse',
        debutJourIso,
        debutDemainIso,
      ],
    );

    final telephones = telephonesResultat
        .map(
          (ligne) =>
              ligne['telephone']?.toString().trim() ?? '',
        )
        .where(
          (telephone) => telephone.isNotEmpty,
        )
        .toList();

    // ==========================================================
    // RESULTAT
    // ==========================================================
    //
    // Les factures récentes sont récupérées depuis le serveur.
    // Le modèle exige cependant une liste.
    //
    // Le Service ajoutera ensuite les factures reçues de l'API.
    //
    // ==========================================================

    return DashboardStatistiques(
      ventes: ventes,
      achats: achats,
      commandes: commandes,
      telephones: telephones,
      facturesRecentes: const [],
    );
  }

  // ============================================================
  // CONVERSION EN ENTIER
  // ============================================================

  int _convertirEnInt(
    dynamic valeur,
  ) {
    if (valeur == null) {
      return 0;
    }

    if (valeur is int) {
      return valeur;
    }

    if (valeur is num) {
      return valeur.toInt();
    }

    return int.tryParse(
          valeur.toString(),
        ) ??
        0;
  }
}