import 'enum.dart';

class CoconutError {
  final ErrorCodeEnum errorCode;
  final String message;
  final Exception? originalException;

  CoconutError(this.errorCode, this.message, [this.originalException]);

  factory CoconutError.unknown({Object? error}) {
    if (error is Exception) {
      return CoconutError(
          ErrorCodeEnum.unknownError, 'Unknown error occurred.', error);
    }
    return CoconutError(ErrorCodeEnum.unknownError, 'Unknown error occurred.');
  }

  @override
  String toString() {
    return originalException != null
        ? 'coconut error:[$errorCode] $message. Original exception: $originalException'
        : 'coconut error:[$errorCode] $message';
  }
}
