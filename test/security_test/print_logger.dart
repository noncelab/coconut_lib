import 'dart:io';

class PrintLogger {
  static final PrintLogger _instance = PrintLogger._internal();
  static PrintLogger get instance => _instance;

  late File _logFile;
  bool _isInitialized = false;

  PrintLogger._internal();

  void initialize(String filePath) {
    final currentDir = Directory.current.path;
    final logFilePath = '$currentDir/$filePath';
    _logFile = File(logFilePath);

    // 로그 파일 초기화 (기존 내용 모두 삭제)
    try {
      _logFile.writeAsStringSync('');
    } catch (e) {
      print('로그 파일 초기화 중 오류 발생: $e');
    }

    _isInitialized = true;
  }

  void log(String message) {
    if (!_isInitialized) {
      throw StateError('PrintLogger가 초기화되지 않았습니다. initialize()를 먼저 호출하세요.');
    }

    // 콘솔에도 출력
    print(message);

    // 파일에도 기록
    try {
      _logFile.writeAsStringSync(
          '${DateTime.now().toIso8601String()}: $message\n',
          mode: FileMode.append);
    } catch (e) {
      print('로그 파일 기록 중 오류 발생: $e');
    }
  }

  void logWithoutConsole(String message) {
    if (!_isInitialized) {
      throw StateError('PrintLogger가 초기화되지 않았습니다. initialize()를 먼저 호출하세요.');
    }

    // 파일에만 기록 (콘솔 출력 없음)
    try {
      _logFile.writeAsStringSync(
          '${DateTime.now().toIso8601String()}: $message\n',
          mode: FileMode.append);
    } catch (e) {
      print('로그 파일 기록 중 오류 발생: $e');
    }
  }

  void clearLog() {
    if (!_isInitialized) {
      throw StateError('PrintLogger가 초기화되지 않았습니다. initialize()를 먼저 호출하세요.');
    }

    try {
      _logFile.writeAsStringSync('');
    } catch (e) {
      print('로그 파일 초기화 중 오류 발생: $e');
    }
  }
}
