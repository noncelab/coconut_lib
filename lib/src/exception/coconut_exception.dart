part of '../../coconut_lib.dart';

/// Base class for recoverable, domain-specific failures from Coconut APIs.
///
/// Malformed serialized input uses [FormatException], invalid API arguments use
/// [ArgumentError]/[RangeError], and invalid object state uses [StateError].
///
/// {@category Errors}
class CoconutException<C extends Enum> implements Exception {
  /// Stable machine-readable code for programmatic error handling.
  final C code;

  /// Human-readable description of the failure.
  final String message;

  /// Lower-level error that caused this failure, when available.
  final Object? cause;

  /// Immutable diagnostic values associated with the failure.
  final Map<String, Object?> context;

  /// Creates a domain failure with an optional [cause] and diagnostic [context].
  CoconutException(this.code, this.message,
      {this.cause, Map<String, Object?> context = const {}})
      : context = Map.unmodifiable(context);

  @override
  String toString() {
    final details = context.isEmpty ? '' : ' $context';
    return '$runtimeType(${code.name}): $message$details';
  }
}
