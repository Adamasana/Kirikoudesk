import 'package:sqflite/sqflite.dart';

import 'database_tables.dart';

class DatabaseMigrations {
  const DatabaseMigrations._();

  /// Vérifie si une colonne existe déjà dans une table SQLite.
  static Future<bool> _colonneExiste(
    Database db,
    String table,
    String colonne,
  ) async {
    final resultats = await db.rawQuery(
      'PRAGMA table_info($table)',
    );

    return resultats.any(
      (ligne) => ligne['name'] == colonne,
    );
  }

  static Future<void> onCreate(Database db) async {
    // ============================================================
    // POINT DE VENTE
    // ============================================================

    await db.execute('''
      CREATE TABLE ${DatabaseTables.pointVente} (
        id INTEGER PRIMARY KEY,
        ville TEXT NOT NULL,
        quartier TEXT NOT NULL
      )
    ''');

    // ============================================================
    // EQUIPE
    // ============================================================

    await db.execute('''
      CREATE TABLE ${DatabaseTables.equipe} (
        id INTEGER PRIMARY KEY,
        nom TEXT NOT NULL,
        point_de_vente_id INTEGER NOT NULL,
        identifiant TEXT NOT NULL,

        FOREIGN KEY (point_de_vente_id)
          REFERENCES ${DatabaseTables.pointVente}(id)
      )
    ''');

    // ============================================================
    // PRODUIT
    // ============================================================

    await db.execute('''
      CREATE TABLE ${DatabaseTables.produit} (
        id INTEGER PRIMARY KEY,

        affichage TEXT NOT NULL,
        nom TEXT NOT NULL,

        prix INTEGER NOT NULL,
        prix_evenement INTEGER NOT NULL,

        promo TEXT NOT NULL,
        nouveau TEXT NOT NULL,
        liquidation TEXT NOT NULL,

        actif TEXT NOT NULL,
        desactivation TEXT NOT NULL,

        date TEXT
      )
    ''');

    // ============================================================
    // SOUS-PRODUIT
    // ============================================================

    await db.execute('''
      CREATE TABLE ${DatabaseTables.sousProduit} (
        id INTEGER PRIMARY KEY,

        produit_id INTEGER NOT NULL,

        couleur TEXT NOT NULL,
        pointure TEXT NOT NULL,

        identifiant TEXT NOT NULL UNIQUE,

        actif TEXT NOT NULL,
        desactivation TEXT NOT NULL,

        numero TEXT UNIQUE,

        FOREIGN KEY (produit_id)
          REFERENCES ${DatabaseTables.produit}(id)
      )
    ''');

    // ============================================================
    // STOCK
    // ============================================================

    await db.execute('''
      CREATE TABLE ${DatabaseTables.stock} (
        id INTEGER PRIMARY KEY,

        point_de_vente_id INTEGER NOT NULL,

        sous_produit_id INTEGER,

        quantite INTEGER NOT NULL DEFAULT 0,

        FOREIGN KEY (point_de_vente_id)
          REFERENCES ${DatabaseTables.pointVente}(id),

        FOREIGN KEY (sous_produit_id)
          REFERENCES ${DatabaseTables.sousProduit}(id),

        UNIQUE (
          point_de_vente_id,
          sous_produit_id
        )
      )
    ''');

    // ============================================================
    // UTILISATEUR
    // ============================================================

    await db.execute('''
      CREATE TABLE ${DatabaseTables.utilisateur} (
        id INTEGER PRIMARY KEY,

        user_id INTEGER,

        boutique_id INTEGER,

        telephone TEXT NOT NULL,
        adresse TEXT NOT NULL,

        statut TEXT NOT NULL,
        post TEXT NOT NULL,

        numero TEXT,

        FOREIGN KEY (boutique_id)
          REFERENCES ${DatabaseTables.equipe}(id)
      )
    ''');

    // ============================================================
    // COMMANDE
    // ============================================================

    await db.execute('''
      CREATE TABLE ${DatabaseTables.commande} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        id_local TEXT NOT NULL UNIQUE,

        id_django INTEGER,

        user_id INTEGER,

        encaisse_par INTEGER,

        gestionnaire_id INTEGER,

        nom TEXT NOT NULL,
        telephone TEXT NOT NULL,

        ville TEXT,
        deplacement TEXT,

        montant INTEGER NOT NULL DEFAULT 0,

        remise INTEGER NOT NULL DEFAULT 0,

        livraison INTEGER NOT NULL DEFAULT 0,

        total INTEGER NOT NULL DEFAULT 0,

        payer TEXT NOT NULL DEFAULT 'Non',

        statut_local TEXT NOT NULL,

        origine TEXT NOT NULL DEFAULT 'Caisse',

        date_creation TEXT NOT NULL,

        date_validation TEXT,

        date_update TEXT,

        sync_status TEXT NOT NULL DEFAULT 'pending',

        sync_date TEXT,

        sync_erreur TEXT,

        FOREIGN KEY (user_id)
          REFERENCES ${DatabaseTables.utilisateur}(id),

        FOREIGN KEY (encaisse_par)
          REFERENCES ${DatabaseTables.utilisateur}(id),

        FOREIGN KEY (gestionnaire_id)
          REFERENCES ${DatabaseTables.equipe}(id)
      )
    ''');

    // ============================================================
    // SHOP
    // ============================================================

    await db.execute('''
      CREATE TABLE ${DatabaseTables.shop} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        commande_id INTEGER NOT NULL,

        article_id INTEGER,

        quantite INTEGER NOT NULL DEFAULT 1,

        couleur TEXT NOT NULL,

        pointure TEXT NOT NULL,

        prix INTEGER NOT NULL,

        montant INTEGER NOT NULL,

        statut TEXT NOT NULL DEFAULT 'valide',

        FOREIGN KEY (commande_id)
          REFERENCES ${DatabaseTables.commande}(id)
          ON DELETE CASCADE,

        FOREIGN KEY (article_id)
          REFERENCES ${DatabaseTables.sousProduit}(id)
      )
    ''');

    // ============================================================
    // SYNCHRONISATION
    // ============================================================

    await db.execute('''
      CREATE TABLE ${DatabaseTables.synchronisation} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        commande_locale_id INTEGER NOT NULL UNIQUE,

        id_local TEXT NOT NULL UNIQUE,

        commande_django_id INTEGER,

        statut TEXT NOT NULL DEFAULT 'pending',

        tentatives INTEGER NOT NULL DEFAULT 0,

        derniere_tentative TEXT,

        derniere_erreur TEXT,

        date_synchronisation TEXT,

        FOREIGN KEY (commande_locale_id)
          REFERENCES ${DatabaseTables.commande}(id)
          ON DELETE CASCADE
      )
    ''');

    // ============================================================
    // INDEX
    // ============================================================

    await db.execute('''
      CREATE INDEX idx_produit_nom
      ON ${DatabaseTables.produit}(nom)
    ''');

    await db.execute('''
      CREATE INDEX idx_sous_produit_produit
      ON ${DatabaseTables.sousProduit}(produit_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_stock_point_vente
      ON ${DatabaseTables.stock}(point_de_vente_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_commande_statut
      ON ${DatabaseTables.commande}(statut_local)
    ''');

    await db.execute('''
      CREATE INDEX idx_commande_sync_status
      ON ${DatabaseTables.commande}(sync_status)
    ''');

    await db.execute('''
      CREATE INDEX idx_commande_encaisse_par
      ON ${DatabaseTables.commande}(encaisse_par)
    ''');
  }

  // ============================================================
  // MIGRATIONS
  // ============================================================

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // ============================================================
    // VERSION 2
    // Ajout de encaisse_par
    // ============================================================

    if (oldVersion < 2) {
      final encaisseParExiste = await _colonneExiste(
        db,
        DatabaseTables.commande,
        'encaisse_par',
      );

      if (!encaisseParExiste) {
        await db.execute('''
          ALTER TABLE ${DatabaseTables.commande}
          ADD COLUMN encaisse_par INTEGER
        ''');
      }

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_commande_encaisse_par
        ON ${DatabaseTables.commande}(encaisse_par)
      ''');
    }

    // ============================================================
    // VERSION 3
    // Ajout de date_validation
    // ============================================================

    if (oldVersion < 3) {
      final dateValidationExiste = await _colonneExiste(
        db,
        DatabaseTables.commande,
        'date_validation',
      );

      if (!dateValidationExiste) {
        await db.execute('''
          ALTER TABLE ${DatabaseTables.commande}
          ADD COLUMN date_validation TEXT
        ''');
      }
    }
  }
}