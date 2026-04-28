# Win Time - Documentation Fonctionnelle

## Vue d'ensemble

Win Time est une application mobile de Click & Collect pour restaurants, permettant aux utilisateurs de commander et récupérer leurs repas sans attente.

## Fonctionnalités principales

### 1. Onboarding (Écrans d'accueil)

Au premier lancement, l'utilisateur découvre 4 écrans de présentation :
- Découverte des restaurants à proximité
- Système de Click & Collect avec créneaux horaires
- Commande simple et rapide
- Récupération avec QR code

**Navigation** : Boutons "Suivant" et "Passer" disponibles

### 2. Authentification

#### Connexion
- Connexion par email et mot de passe
- Options de connexion sociale (Google, Apple, Facebook)
- Lien "Mot de passe oublié"
- Lien vers l'inscription

#### Inscription
- Formulaire complet avec validation :
  - Nom complet
  - Email
  - Numéro de téléphone
  - Mot de passe avec confirmation
- Acceptation des conditions d'utilisation obligatoire
- Lien vers la connexion pour utilisateurs existants

#### Espace restaurateur
- Lien "Vous êtes restaurateur ?" pour accéder au panel propriétaire

### 3. Page d'accueil

**Affichage** :
- Barre de recherche pour trouver des restaurants
- Badge "Click & Collect" sur chaque restaurant
- Liste de restaurants avec :
  - Photo du restaurant
  - Nom et type de cuisine
  - Note et nombre d'avis
  - Temps de préparation
  - Distance
  - Statut (Ouvert/Fermé)

**Navigation** : Clic sur un restaurant pour voir les détails

### 4. Page restaurant (Détails)

**Informations affichées** :
- Image du restaurant
- Nom et description
- Note, avis, temps de préparation
- Badge "Click & Collect"
- Statut d'ouverture
- Spécialités du restaurant

**Menu** :
- Catégories de plats (Entrées, Plats, Desserts, Boissons)
- Pour chaque plat :
  - Photo
  - Nom et description
  - Prix
  - Bouton "Ajouter au panier"

**Action** : Ajout de plats au panier avec animation

### 5. Panier

**Affichage** :
- Liste des articles avec :
  - Photo et nom du plat
  - Prix unitaire
  - Quantité (modifiable avec +/-)
  - Prix total par article
  - Bouton de suppression

**Calculs automatiques** :
- Sous-total : Somme de tous les articles
- Frais Win Time (2%) : Calculés automatiquement sur le sous-total
- Total à payer : Sous-total + Frais Win Time

**Informations** :
- Icône d'information expliquant les frais Win Time de 2%
- Message indiquant que le paiement se fait au restaurant

**Actions** :
- Modifier les quantités
- Supprimer des articles
- Passer à la commande

### 6. Commande (Checkout)

**Informations client** :
- Nom complet
- Numéro de téléphone
- Email

**Choix de l'heure** :
- "Dès que possible" (temps de préparation affiché)
- "Programmer" avec sélection de créneau horaire :
  - Créneaux de 30 minutes
  - Affichage du jour et de l'heure

**Paiement** :
- Encadré bleu informatif : "Paiement sur place"
- Message : "Vous réglerez directement au restaurant lors du retrait"
- AUCUN paiement en ligne requis

**Résumé détaillé de la commande** :
- Liste complète de tous les articles commandés avec quantités et prix
- Sous-total
- Frais Win Time (2%)
- Total à payer

**Action** : Bouton "Confirmer la commande"

### 7. Confirmation de commande

**Page entièrement scrollable** contenant :

**En-tête** :
- Animation de succès (icône verte)
- Message de confirmation
- Numéro de commande unique

**Détails de la commande** :
- Nom du restaurant
- Statut de la commande
- Heure de commande
- Heure de retrait estimée

**Facture détaillée** :
- Badge "Paiement sur place"
- Section "Articles" avec :
  - Liste complète de tous les produits commandés
  - Quantité et nom de chaque article
  - Prix de chaque article
- Sous-total
- Frais Win Time (2%) avec icône d'information
- TOTAL À PAYER en gros caractères verts

**QR Code** :
- Code QR unique pour le retrait
- Message : "Présentez ce QR code au restaurant"
- Visible en scrollant vers le bas

**Actions** :
- Bouton "Suivre ma commande"
- Bouton "Retour à l'accueil"

### 8. Suivi de commande

**Statuts disponibles** :
- En préparation
- Prête
- Récupérée

**Affichage** :
- Timeline visuelle avec indicateur de progression
- Nom du restaurant
- Articles commandés
- Montant total
- QR code pour le retrait

**Action** : Bouton "Retour à l'accueil"

## Modèle économique

### Frais Win Time
- **Taux** : 2% du sous-total
- **Calcul** : Automatique sur chaque commande
- **Affichage** : Transparent sur toutes les pages (panier, checkout, facture)
- **Information** : Icône d'information disponible pour expliquer les frais

### Paiement
- **Méthode** : Paiement sur place au restaurant
- **Aucun** paiement en ligne requis
- **Moment** : Lors du retrait de la commande

## Click & Collect

### Principe
- Commande à l'avance via l'application
- Choix du créneau horaire de retrait
- Récupération sans attente au restaurant
- Présentation du QR code pour validation

### Créneaux horaires
- Intervalles de 30 minutes
- Option "Dès que possible" (temps de préparation du restaurant)
- Option "Programmer" pour choisir une heure précise

## Navigation de l'application

```
Onboarding (premier lancement)
    ↓
Connexion/Inscription
    ↓
Page d'accueil (liste restaurants)
    ↓
Détails restaurant + Menu
    ↓
Panier
    ↓
Checkout
    ↓
Confirmation + QR Code
    ↓
Suivi de commande
```

## Données de test

L'application contient des restaurants de démonstration :
- Chez Marie (Française)
- Sushi Master (Japonaise)
- Bella Italia (Italienne)
- Le Burger House (Américaine)
- Taj Mahal (Indienne)

Chaque restaurant propose plusieurs plats dans différentes catégories avec images et descriptions.

## Technologies

- **Framework** : Flutter 3.5.0+
- **Plateforme** : iOS (iPhone 16 Pro)
- **Architecture** : Clean Architecture avec séparation Domain/Data/Presentation
- **État** : Gestion locale avec setState
- **QR Code** : Génération automatique avec package qr_flutter

## Prochaines fonctionnalités (non implémentées)

- Géolocalisation des restaurants à proximité
- Notifications push en temps réel
- Panel restaurateur pour gestion des commandes
- Historique complet des commandes
- Système de favoris
- Évaluations et avis clients
