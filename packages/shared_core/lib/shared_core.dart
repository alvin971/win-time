/// Package partagé pour les applications Win Time
/// Contient les entités, constantes, mappers Firestore et utilitaires communs.
library shared_core;

// ─── Domain — Entities ─────────────────────────────────────────────────────
export 'src/domain/entities/address_entity.dart';
export 'src/domain/entities/business_hours.dart';
export 'src/domain/entities/category_entity.dart';
export 'src/domain/entities/contact_info.dart';
export 'src/domain/entities/order_entity.dart';
export 'src/domain/entities/product_entity.dart';
export 'src/domain/entities/restaurant_entity.dart';
export 'src/domain/entities/social_links.dart';
export 'src/domain/entities/user_entity.dart';

// ─── Domain — Enums ────────────────────────────────────────────────────────
export 'src/domain/enums/allergen.dart';
export 'src/domain/enums/cuisine_type.dart';
export 'src/domain/enums/day_of_week.dart';
export 'src/domain/enums/order_status.dart';
export 'src/domain/enums/payment_method.dart';
export 'src/domain/enums/payment_status.dart';
export 'src/domain/enums/price_range.dart';
export 'src/domain/enums/product_label.dart';
export 'src/domain/enums/user_role.dart';

// ─── Domain — Repositories (interfaces) ────────────────────────────────────
export 'src/domain/repositories/menu_repository.dart';
export 'src/domain/repositories/order_repository.dart';
export 'src/domain/repositories/restaurant_repository.dart';

// ─── Data — Firestore Models ───────────────────────────────────────────────
export 'src/data/models/category_model.dart';
export 'src/data/models/order_model.dart';
export 'src/data/models/product_model.dart';
export 'src/data/models/restaurant_model.dart';
export 'src/data/models/user_model.dart';

// ─── Core — Geo ────────────────────────────────────────────────────────────
export 'src/core/geo/geohash.dart';

// ─── Core — Constants ──────────────────────────────────────────────────────
export 'src/core/constants/api_constants.dart';
export 'src/core/constants/storage_keys.dart';

// ─── Core — Errors ─────────────────────────────────────────────────────────
export 'src/core/errors/failures.dart';
export 'src/core/errors/exceptions.dart';

// ─── Core — Network ────────────────────────────────────────────────────────
export 'src/core/network/api_result.dart';

// ─── Core — WebSocket ──────────────────────────────────────────────────────
export 'src/core/websocket/websocket_service.dart';

// ─── Core — Utils ──────────────────────────────────────────────────────────
export 'src/core/utils/date_formatter.dart';
export 'src/core/utils/validators.dart';
