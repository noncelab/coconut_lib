import 'dart:io';

class FileDatabase {
  // final String applicationPath;
  final String fileName;
  String get path => 'cache/$fileName';

  // FileDatabase(this.applicationPath, this.fileName);
  FileDatabase(this.fileName);

  // 파일에 문자열 데이터를 저장하는 메서드
  Future<void> save(String data) async {
    Directory folder = Directory('cache');
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    try {
      final file = File(path);
      await file.writeAsString(data, mode: FileMode.write);
    } catch (e) {
      print('Error saving file: $e');
    }
  }

  // 파일에서 문자열 데이터를 읽어오는 메서드
  Future<String> load() async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final contents = await file.readAsString();
        return contents;
      } else {
        print('Cache file does not exist');
        return '';
      }
    } catch (e) {
      print('Error loading file: $e');
      return '';
    }
  }

  // 파일을 삭제하는 메서드
  Future<void> delete() async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print('File deleted successfully');
      } else {
        print('File does not exist');
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }
}

// void main() async {
//   // 파일 경로 정의
//   String filePath = 'example.txt';

//   // FileDatabase 인스턴스 생성
//   var fileDb = FileDatabase(filePath);

//   // 파일에 데이터 저장
//   await fileDb.save('This is a sample text.');

//   // 파일에서 데이터 읽기
//   String data = await fileDb.load();
//   print('Data read from file: $data');

//   // 파일 삭제
//   await fileDb.delete();
// }