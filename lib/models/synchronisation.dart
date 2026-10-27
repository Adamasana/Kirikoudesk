class Synchronisation {
  final int? id;
  final int commandeLocaleId;
  final String idLocal;
  final int? commandeDjangoId;
  final String statut;
  final int tentatives;
  final DateTime? derniereTentative;
  final String? derniereErreur;
  final DateTime? dateSynchronisation;

  const Synchronisation({
    this.id,
    required this.commandeLocaleId,
    required this.idLocal,
    this.commandeDjangoId,
    required this.statut,
    required this.tentatives,
    this.derniereTentative,
    this.derniereErreur,
    this.dateSynchronisation,
  });

  factory Synchronisation.fromMap(Map<String, dynamic> map) {
    return Synchronisation(
      id: map['id'] as int?,
      commandeLocaleId: map['commande_locale_id'] as int,
      idLocal: map['id_local'] as String,
      commandeDjangoId: map['commande_django_id'] as int?,
      statut: map['statut'] as String? ?? 'pending',
      tentatives: map['tentatives'] as int? ?? 0,
      derniereTentative: map['derniere_tentative'] != null
          ? DateTime.tryParse(
              map['derniere_tentative'].toString(),
            )
          : null,
      derniereErreur: map['derniere_erreur'] as String?,
      dateSynchronisation: map['date_synchronisation'] != null
          ? DateTime.tryParse(
              map['date_synchronisation'].toString(),
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'commande_locale_id': commandeLocaleId,
      'id_local': idLocal,
      'commande_django_id': commandeDjangoId,
      'statut': statut,
      'tentatives': tentatives,
      'derniere_tentative': derniereTentative?.toIso8601String(),
      'derniere_erreur': derniereErreur,
      'date_synchronisation': dateSynchronisation?.toIso8601String(),
    };
  }

  Synchronisation copyWith({
    int? id,
    int? commandeLocaleId,
    String? idLocal,
    int? commandeDjangoId,
    String? statut,
    int? tentatives,
    DateTime? derniereTentative,
    String? derniereErreur,
    DateTime? dateSynchronisation,
  }) {
    return Synchronisation(
      id: id ?? this.id,
      commandeLocaleId: commandeLocaleId ?? this.commandeLocaleId,
      idLocal: idLocal ?? this.idLocal,
      commandeDjangoId: commandeDjangoId ?? this.commandeDjangoId,
      statut: statut ?? this.statut,
      tentatives: tentatives ?? this.tentatives,
      derniereTentative:
          derniereTentative ?? this.derniereTentative,
      derniereErreur: derniereErreur ?? this.derniereErreur,
      dateSynchronisation:
          dateSynchronisation ?? this.dateSynchronisation,
    );
  }
}