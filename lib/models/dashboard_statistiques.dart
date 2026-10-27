import 'facture.dart';

class DashboardStatistiques {
  final int ventes;
  final int achats;
  final int commandes;
  final List<String> telephones;
  final List<Facture> facturesRecentes;

  const DashboardStatistiques({
    required this.ventes,
    required this.achats,
    required this.commandes,
    required this.telephones,
    required this.facturesRecentes,
  });

  // ============================================================
  // CLIENTS
  // ============================================================

  int get clients => telephones.length;

  // ============================================================
  // JSON
  // ============================================================

  factory DashboardStatistiques.fromJson(
    Map<String, dynamic> json,
  ) {
    return DashboardStatistiques(
      ventes: _convertirEnInt(
        json['ventes'],
      ),
      achats: _convertirEnInt(
        json['achats'],
      ),
      commandes: _convertirEnInt(
        json['commandes'],
      ),
      telephones: _convertirTelephones(
        json['telephones'],
      ),
      facturesRecentes:
          _convertirFacturesRecentes(
        json['factures_recentes'],
      ),
    );
  }

  // ============================================================
  // CONVERSION DES FACTURES
  // ============================================================

  static List<Facture> _convertirFacturesRecentes(
    dynamic valeur,
  ) {
    if (valeur is! List) {
      return [];
    }

    return valeur
        .whereType<Map>()
        .map(
          (element) => Facture.fromMap(
            Map<String, dynamic>.from(
              element,
            ),
          ),
        )
        .toList();
  }

  // ============================================================
  // CONVERSION ENTIERS
  // ============================================================

  static int _convertirEnInt(
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

  // ============================================================
  // CONVERSION TELEPHONES
  // ============================================================

  static List<String> _convertirTelephones(
    dynamic valeur,
  ) {
    if (valeur is! List) {
      return [];
    }

    return valeur
        .map(
          (element) => element.toString().trim(),
        )
        .where(
          (telephone) => telephone.isNotEmpty,
        )
        .toList();
  }
}