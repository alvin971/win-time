/// Utilitaires de validation pour les formulaires
class Validators {
  Validators._();

  /// Valide une adresse email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Email invalide';
    }

    return null;
  }

  /// Valide un mot de passe
  static String? validatePassword(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }

    if (value.length < minLength) {
      return 'Le mot de passe doit contenir au moins $minLength caractères';
    }

    return null;
  }

  /// Valide un numéro de téléphone français
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le numéro de téléphone est requis';
    }

    // Supprime les espaces, points, tirets
    final cleaned = value.replaceAll(RegExp(r'[\s\.\-]'), '');

    // Vérifie le format français (commence par 0 ou +33)
    final phoneRegex = RegExp(r'^(?:(?:\+|00)33|0)[1-9](?:\d{8})$');

    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Numéro de téléphone invalide';
    }

    return null;
  }

  /// Valide un champ requis
  static String? validateRequired(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }

  /// Valide une longueur minimale
  static String? validateMinLength(String? value, int minLength,
      {String fieldName = 'Ce champ'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }

    if (value.length < minLength) {
      return '$fieldName doit contenir au moins $minLength caractères';
    }

    return null;
  }

  /// Valide une longueur maximale
  static String? validateMaxLength(String? value, int maxLength,
      {String fieldName = 'Ce champ'}) {
    if (value != null && value.length > maxLength) {
      return '$fieldName ne peut pas dépasser $maxLength caractères';
    }

    return null;
  }

  /// Valide un nombre
  static String? validateNumber(String? value, {String fieldName = 'Ce champ'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }

    if (double.tryParse(value) == null) {
      return '$fieldName doit être un nombre valide';
    }

    return null;
  }

  /// Valide un nombre positif
  static String? validatePositiveNumber(String? value,
      {String fieldName = 'Ce champ'}) {
    final numberError = validateNumber(value, fieldName: fieldName);
    if (numberError != null) return numberError;

    final number = double.parse(value!);
    if (number <= 0) {
      return '$fieldName doit être un nombre positif';
    }

    return null;
  }

  /// Valide une URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'URL est requise';
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'URL invalide';
    }

    return null;
  }

  /// Combine plusieurs validateurs
  static String? combine(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  }
}
