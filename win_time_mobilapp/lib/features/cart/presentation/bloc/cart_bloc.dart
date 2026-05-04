import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_core/shared_core.dart';

/// Cart bloc — état local uniquement (pas persisté en Postgres).
/// Un cart est lié à UN restaurant : changer de resto vide le cart
/// (avec confirmation côté UI).

// ─── Events ────────────────────────────────────────────────────────────────

abstract class CartEvent extends Equatable {
  const CartEvent();
  @override
  List<Object?> get props => [];
}

class CartItemAdded extends CartEvent {
  final ProductEntity product;
  final String restaurantId;
  final int quantity;
  const CartItemAdded({
    required this.product,
    required this.restaurantId,
    this.quantity = 1,
  });
  @override
  List<Object?> get props => [product.id, restaurantId, quantity];
}

class CartItemRemoved extends CartEvent {
  final String productId;
  const CartItemRemoved(this.productId);
  @override
  List<Object?> get props => [productId];
}

class CartItemQuantityChanged extends CartEvent {
  final String productId;
  final int newQuantity;
  const CartItemQuantityChanged(this.productId, this.newQuantity);
  @override
  List<Object?> get props => [productId, newQuantity];
}

class CartCleared extends CartEvent {
  const CartCleared();
}

// ─── State ─────────────────────────────────────────────────────────────────

class CartLine extends Equatable {
  final ProductEntity product;
  final int quantity;
  const CartLine({required this.product, required this.quantity});
  double get lineTotal => product.price * quantity;
  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);
  @override
  List<Object?> get props => [product.id, quantity];
}

class CartState extends Equatable {
  /// Restaurant ID du resto auquel ce cart est lié, ou null si vide.
  final String? restaurantId;
  final List<CartLine> lines;

  const CartState({this.restaurantId, this.lines = const []});

  factory CartState.empty() => const CartState();

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);
  double get subtotal => lines.fold(0.0, (sum, l) => sum + l.lineTotal);

  CartState copyWith({String? restaurantId, List<CartLine>? lines}) =>
      CartState(
        restaurantId: restaurantId ?? this.restaurantId,
        lines: lines ?? this.lines,
      );

  @override
  List<Object?> get props => [restaurantId, lines];
}

// ─── Bloc ──────────────────────────────────────────────────────────────────

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(CartState.empty()) {
    on<CartItemAdded>(_onAdd);
    on<CartItemRemoved>(_onRemove);
    on<CartItemQuantityChanged>(_onQty);
    on<CartCleared>((_, emit) => emit(CartState.empty()));
  }

  void _onAdd(CartItemAdded event, Emitter<CartState> emit) {
    // Resto différent → reset (le caller doit avoir confirmé)
    if (state.restaurantId != null &&
        state.restaurantId != event.restaurantId) {
      emit(CartState(
        restaurantId: event.restaurantId,
        lines: [CartLine(product: event.product, quantity: event.quantity)],
      ));
      return;
    }

    final lines = [...state.lines];
    final idx = lines.indexWhere((l) => l.product.id == event.product.id);
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(
        quantity: lines[idx].quantity + event.quantity,
      );
    } else {
      lines.add(CartLine(product: event.product, quantity: event.quantity));
    }
    emit(state.copyWith(restaurantId: event.restaurantId, lines: lines));
  }

  void _onRemove(CartItemRemoved event, Emitter<CartState> emit) {
    final lines =
        state.lines.where((l) => l.product.id != event.productId).toList();
    if (lines.isEmpty) {
      emit(CartState.empty());
    } else {
      emit(state.copyWith(lines: lines));
    }
  }

  void _onQty(CartItemQuantityChanged event, Emitter<CartState> emit) {
    if (event.newQuantity <= 0) {
      add(CartItemRemoved(event.productId));
      return;
    }
    final lines = state.lines
        .map((l) => l.product.id == event.productId
            ? l.copyWith(quantity: event.newQuantity)
            : l)
        .toList();
    emit(state.copyWith(lines: lines));
  }
}
