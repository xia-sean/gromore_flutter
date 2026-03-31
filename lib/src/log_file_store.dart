import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// GroMore 文件日志存储
class GromoreLogFileStore {
  GromoreLogFileStore._();

  static bool _enabled = false;
  static File? _activeFile;
  static Future<void> _writeQueue = Future<void>.value();

  /// 是否启用文件日志
  static bool get enabled => _enabled;

  /// 配置文件日志
  static Future<void> configure({required bool enabled}) async {
    _enabled = enabled;
    if (!enabled) {
      await _writeQueue;
      return;
    }

    final File file = await _ensureActiveFile();
    _enqueueWrite(() async {
      if (await file.length() > 0) {
        await file.writeAsString('\n', mode: FileMode.append, flush: true);
      }
      await file.writeAsString(
        '===== session ${DateTime.now().toIso8601String()} =====\n',
        mode: FileMode.append,
        flush: true,
      );
    });
    await _writeQueue;
  }

  /// 追加一行日志
  static void appendLine(String line) {
    if (!_enabled) {
      return;
    }
    _enqueueWrite(() async {
      final File file = await _ensureActiveFile();
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    });
  }

  /// 导出日志为 txt 文件，返回导出路径
  static Future<String?> export({String? fileName}) async {
    if (!_enabled && _activeFile == null) {
      return null;
    }

    await _writeQueue;
    final File? source = _activeFile;
    if (source == null || !await source.exists()) {
      return null;
    }

    final Directory directory = await _ensureLogDirectory();
    final String resolvedFileName =
        fileName ?? 'gromore_log_${_timestampForFileName()}.txt';
    final File exportedFile = File('${directory.path}/$resolvedFileName');
    if (await exportedFile.exists()) {
      await exportedFile.delete();
    }
    await source.copy(exportedFile.path);
    return exportedFile.path;
  }

  /// 获取当前活跃日志文件路径
  static Future<String?> getActiveLogFilePath() async {
    await _writeQueue;
    final File? file = _activeFile;
    if (file == null || !await file.exists()) {
      return null;
    }
    return file.path;
  }

  /// 读取当前日志文件内容
  static Future<String> readContent() async {
    await _writeQueue;
    final File? file = _activeFile;
    if (file == null || !await file.exists()) {
      return '';
    }
    return file.readAsString();
  }

  /// 清空当前日志文件内容
  static Future<void> clear() async {
    await _writeQueue;
    final File? file = _activeFile;
    if (file == null || !await file.exists()) {
      return;
    }
    await file.writeAsString('', flush: true);
  }

  /// 删除当前日志文件
  static Future<void> delete() async {
    _enabled = false;
    await _writeQueue;
    final File? file = _activeFile;
    if (file != null && await file.exists()) {
      await file.delete();
    }
    _activeFile = null;
  }

  static void _enqueueWrite(Future<void> Function() action) {
    _writeQueue = _writeQueue.then((_) => action());
  }

  static Future<File> _ensureActiveFile() async {
    if (_activeFile != null) {
      return _activeFile!;
    }
    final Directory directory = await _ensureLogDirectory();
    final File file = File('${directory.path}/gromore_active_log.txt');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    _activeFile = file;
    return file;
  }

  static Future<Directory> _ensureLogDirectory() async {
    final Directory root = await getApplicationDocumentsDirectory();
    final Directory directory = Directory('${root.path}/gromore_flutter_logs');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static String _timestampForFileName() {
    final DateTime now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${now.year}'
        '${twoDigits(now.month)}'
        '${twoDigits(now.day)}_'
        '${twoDigits(now.hour)}'
        '${twoDigits(now.minute)}'
        '${twoDigits(now.second)}';
  }
}
