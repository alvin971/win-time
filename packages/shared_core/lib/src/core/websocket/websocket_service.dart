import 'dart:async';

/// Interface de base pour les services WebSocket
/// À implémenter dans chaque application selon leurs besoins spécifiques
abstract class WebSocketService {
  /// Stream pour les événements WebSocket
  Stream<dynamic> get events;

  /// Vérifie si le WebSocket est connecté
  bool get isConnected;

  /// Connecte au WebSocket
  Future<void> connect({
    required String url,
    required String token,
    Map<String, dynamic>? additionalParams,
  });

  /// Déconnecte du WebSocket
  Future<void> disconnect();

  /// Envoie un message via WebSocket
  void emit(String event, dynamic data);

  /// Écoute un événement spécifique
  Stream<T> on<T>(String event);

  /// Rejoindre une room spécifique
  void joinRoom(String roomId);

  /// Quitter une room spécifique
  void leaveRoom(String roomId);

  /// Dispose des ressources
  void dispose();
}

/// Configuration WebSocket de base
class WebSocketConfig {
  /// URL du serveur WebSocket
  final String url;

  /// Token d'authentification
  final String token;

  /// Paramètres additionnels de connexion
  final Map<String, dynamic>? additionalParams;

  /// Timeout de connexion
  final Duration connectionTimeout;

  /// Activer la reconnexion automatique
  final bool autoReconnect;

  /// Délai avant reconnexion
  final Duration reconnectDelay;

  /// Nombre maximum de tentatives de reconnexion
  final int maxReconnectAttempts;

  const WebSocketConfig({
    required this.url,
    required this.token,
    this.additionalParams,
    this.connectionTimeout = const Duration(seconds: 10),
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 5,
  });
}

/// États de connexion WebSocket
enum WebSocketState {
  /// Déconnecté
  disconnected,

  /// En cours de connexion
  connecting,

  /// Connecté
  connected,

  /// En cours de reconnexion
  reconnecting,

  /// Erreur
  error,
}

/// Événements WebSocket communs
class WebSocketEvents {
  WebSocketEvents._();

  // Événements de connexion
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String error = 'error';
  static const String reconnect = 'reconnect';

  // Événements de commande (communs aux deux apps)
  static const String newOrder = 'new_order';
  static const String orderUpdated = 'order_updated';
  static const String orderStatusChanged = 'order_status_updated';
  static const String orderCancelled = 'order_cancelled';
  static const String orderReady = 'order_ready';

  // Événements de notification
  static const String notification = 'notification';
}
