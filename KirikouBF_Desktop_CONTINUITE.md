# KirikouBF Desktop — Document de continuité du projet

> **Document de passation destiné à une autre IA**
>
> Ce document décrit l'objectif, l'historique, l'architecture, les décisions techniques, les fichiers existants, l'état actuel et la feuille de route du projet **KirikouBF Desktop**.
>
> Une autre IA qui reçoit ce fichier doit pouvoir comprendre le projet et continuer le développement sans repartir de zéro.

---

# 1. IDENTITÉ DU PROJET

## Nom

**KirikouBF Desktop**

## Type

Application desktop **Windows**, développée avec **Flutter**.

## Backend

Application web **Django** existante nommée **KirikouBF**.

## Objectif général

Transformer progressivement l'application web Django existante en une application desktop Windows destinée au personnel de la boutique.

L'application doit être rapide, confortable, interactive et surtout fonctionner selon une architecture **local-first**.

Architecture générale :

```text
                 DJANGO / SERVEUR
                       ▲
                       │
                 Synchronisation
                       │
                       ▼
              SQLITE LOCAL FLUTTER
                       │
              ┌────────┼────────┐
              │        │        │
           Produits  Stocks  Commandes
              │                 │
              └────── CAISSE ──┘



