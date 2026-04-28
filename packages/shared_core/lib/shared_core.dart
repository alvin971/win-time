/// Package partagé pour les applications Win Time
/// Contient les entités, constantes et utilitaires communs
library shared_core;

// Domain - Entities
export 'src/domain/entities/user_entity.dart';
export 'src/domain/entities/order_entity.dart';

// Domain - Enums
export 'src/domain/enums/user_role.dart';
export 'src/domain/enums/order_status.dart';
export 'src/domain/enums/payment_status.dart';
export 'src/domain/enums/payment_method.dart';

// Core - Constants
export 'src/core/constants/api_constants.dart';
export 'src/core/constants/storage_keys.dart';

// Core - Errors
export 'src/core/errors/failures.dart';
export 'src/core/errors/exceptions.dart';

// Core - Network
export 'src/core/network/api_result.dart';

// Core - WebSocket
export 'src/core/websocket/websocket_service.dart';

// Core - Utils
export 'src/core/utils/date_formatter.dart';
export 'src/core/utils/validators.dart';
