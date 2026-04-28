import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';

/// Service WebSocket pour synchronisation temps réel
/// Gère la connexion Socket.IO avec reconnexion automatique et heartbeat
class WebSocketService {
  IO.Socket? _socket;
  bool _isConnected = false;

  // Paramètres de reconnexion (backoff exponentiel)
  static const int _maxRetryDelay = 60;
  int _retryDelay = 1;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  String? _lastRestaurantId;
  String? _lastAuthToken;

  // Streams pour différents types d'événements
  final _newOrdersController = StreamController<Map<String, dynamic>>.broadcast();
  final _orderUpdatesController = StreamController<Map<String, dynamic>>.broadcast();
  final _menuUpdatesController = StreamController<Map<String, dynamic>>.broadcast();
  final _restaurantUpdatesController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters pour les streams
  Stream<Map<String, dynamic>> get newOrders => _newOrdersController.stream;
  Stream<Map<String, dynamic>> get orderUpdates => _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get menuUpdates => _menuUpdatesController.stream;
  Stream<Map<String, dynamic>> get restaurantUpdates => _restaurantUpdatesController.stream;

  bool get isConnected => _isConnected;

  /// Connexion au serveur WebSocket
  Future<void> connect({
    required String restaurantId,
    required String authToken,
  }) async {
    if (_isConnected) return;

    _lastRestaurantId = restaurantId;
    _lastAuthToken = authToken;

    try {
      _socket = IO.io(
        ApiConstants.wsBaseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({
              'token': authToken,
              'restaurantId': restaurantId,
            })
            .build(),
      );

      _socket!.connect();

      _socket!.onConnect((_) {
        _isConnected = true;
        _retryDelay = 1;
        _reconnectTimer?.cancel();
        _socket!.emit('join_restaurant', restaurantId);
        _startHeartbeat();
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        _heartbeatTimer?.cancel();
        _scheduleReconnect();
      });

      _socket!.onConnectError((_) {
        _isConnected = false;
        _heartbeatTimer?.cancel();
        _scheduleReconnect();
      });

      _setupEventListeners();
    } catch (e) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  /// Reconnexion avec backoff exponentiel
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_lastRestaurantId == null || _lastAuthToken == null) return;

    _reconnectTimer = Timer(Duration(seconds: _retryDelay), () async {
      _retryDelay = (_retryDelay * 2).clamp(1, _maxRetryDelay);
      _socket?.dispose();
      _socket = null;
      await connect(restaurantId: _lastRestaurantId!, authToken: _lastAuthToken!);
    });
  }

  /// Heartbeat toutes les 25s pour détecter les connexions mortes
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_socket != null && _isConnected) {
        _socket!.emit('ping');
      }
    });
  }

  /// Configuration des listeners d'événements (cast sécurisé)
  void _setupEventListeners() {
    _socket!.on('new_order', (data) {
      if (data is Map<String, dynamic>) {
        _newOrdersController.add(data);
      }
    });

    _socket!.on('order_updated', (data) {
      if (data is Map<String, dynamic>) {
        _orderUpdatesController.add(data);
      }
    });

    _socket!.on('order_cancelled', (data) {
      if (data is Map<String, dynamic>) {
        _orderUpdatesController.add(data);
      }
    });

    _socket!.on('menu_updated', (data) {
      if (data is Map<String, dynamic>) {
        _menuUpdatesController.add(data);
      }
    });

    _socket!.on('restaurant_updated', (data) {
      if (data is Map<String, dynamic>) {
        _restaurantUpdatesController.add(data);
      }
    });
  }

  /// Déconnexion manuelle (sans reconnexion)
  void disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _lastRestaurantId = null;
    _lastAuthToken = null;
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
  }

  /// Nettoyage des ressources
  void dispose() {
    disconnect();
    _newOrdersController.close();
    _orderUpdatesController.close();
    _menuUpdatesController.close();
    _restaurantUpdatesController.close();
  }

  /// Émettre un événement personnalisé
  void emit(String event, dynamic data) {
    if (_isConnected && _socket != null) {
      _socket!.emit(event, data);
    }
  }
}
