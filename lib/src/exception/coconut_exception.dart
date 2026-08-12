part of '../../coconut_lib.dart';

/// Base class for recoverable, domain-specific failures from Coconut APIs.
///
/// Malformed serialized input uses [FormatException], invalid API arguments use
/// [ArgumentError]/[RangeError], and invalid object state uses [StateError].
class CoconutException<C extends Enum> implements Exception {
  final C code;
  final String message;
  final Object? cause;
  final Map<String, Object?> context;

  CoconutException(this.code, this.message,
      {this.cause, Map<String, Object?> context = const {}})
      : context = Map.unmodifiable(context);

  @override
  String toString() {
    final details = context.isEmpty ? '' : ' $context';
    return '$runtimeType(${code.name}): $message$details';
  }
}
