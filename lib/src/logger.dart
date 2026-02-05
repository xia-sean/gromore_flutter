import 'package:flutter/foundation.dart';

/// 日志级别枚举
enum LogLevel {
  /// Debug 级别
  debug,

  /// Info 级别
  info,

  /// Warn 级别
  warn,

  /// Error 级别
  error,
}

/// 日志来源枚举
enum LogSource {
  /// Dart 层日志
  dart,

  /// 原生层日志
  native,
}

/// 日志级别值转换
extension LogLevelValue on LogLevel {
  /// 获取字符串值
  String get value {
    switch (this) {
      case LogLevel.debug:
        return 'debug';
      case LogLevel.info:
        return 'info';
      case LogLevel.warn:
        return 'warn';
      case LogLevel.error:
        return 'error';
    }
  }
}

/// 日志来源值转换
extension LogSourceValue on LogSource {
  /// 获取字符串值
  String get value {
    switch (this) {
      case LogSource.dart:
        return 'dart';
      case LogSource.native:
        return 'native';
    }
  }
}

/// 日志事件实体
class LogEvent {
  /// 构建日志事件
  ///
  /// [level] 日志级别
  /// [message] 日志内容
  /// [tag] 日志标签
  /// [timestamp] 时间戳
  /// [source] 日志来源
  LogEvent({
    required this.level,
    required this.message,
    required this.tag,
    required this.timestamp,
    required this.source,
  });

  /// 日志级别
  final LogLevel level;

  /// 日志内容
  final String message;

  /// 日志标签
  final String tag;

  /// 时间戳
  final DateTime timestamp;

  /// 日志来源
  final LogSource source;

  /// 转为通道传输 Map
  Map<String, dynamic> toMap() {
    return {
      'level': level.value,
      'message': message,
      'tag': tag,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'source': source.value,
    };
  }

  /// 从通道 Map 解析日志事件
  ///
  /// [map] 通道回传的日志数据
  static LogEvent fromMap(Map<dynamic, dynamic> map) {
    final String levelValue = map['level']?.toString() ?? 'info';
    final String sourceValue = map['source']?.toString() ?? 'native';
    return LogEvent(
      level: _parseLevel(levelValue),
      message: map['message']?.toString() ?? '',
      tag: map['tag']?.toString() ?? 'gromore',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      source: sourceValue == 'dart' ? LogSource.dart : LogSource.native,
    );
  }

  /// 解析日志级别
  ///
  /// [value] 日志级别字符串
  static LogLevel _parseLevel(String value) {
    switch (value) {
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warn':
        return LogLevel.warn;
      case 'error':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}

/// 日志处理回调
///
/// [event] 日志事件
typedef LogHandler = void Function(LogEvent event);

/// 日志工具类
class GromoreLogger {
  GromoreLogger._();

  /// 是否启用日志
  static bool _enabled = kDebugMode;

  /// 当前日志级别
  static LogLevel _level = LogLevel.info;

  /// 日志处理回调
  static LogHandler? _handler;

  /// 是否输出原生日志到控制台
  static bool _printNativeLog = false;

  /// 获取是否启用日志
  static bool get enabled => _enabled;

  /// 获取当前日志级别
  static LogLevel get level => _level;

  /// 设置日志开关
  ///
  /// [enabled] 是否启用
  static void setLogEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// 设置日志级别
  ///
  /// [level] 日志级别
  static void setLogLevel(LogLevel level) {
    _level = level;
  }

  /// 设置日志处理回调
  ///
  /// [handler] 日志回调
  static void setHandler(LogHandler? handler) {
    _handler = handler;
  }

  /// 设置是否打印原生日志
  ///
  /// [enabled] 是否打印
  static void setPrintNativeLog(bool enabled) {
    _printNativeLog = enabled;
  }

  /// 输出 debug 日志
  ///
  /// [message] 日志内容
  /// [tag] 日志标签
  static void debug(String message, {String tag = 'gromore'}) {
    _log(LogLevel.debug, message, tag, LogSource.dart);
  }

  /// 输出 info 日志
  ///
  /// [message] 日志内容
  /// [tag] 日志标签
  static void info(String message, {String tag = 'gromore'}) {
    _log(LogLevel.info, message, tag, LogSource.dart);
  }

  /// 输出 warn 日志
  ///
  /// [message] 日志内容
  /// [tag] 日志标签
  static void warn(String message, {String tag = 'gromore'}) {
    _log(LogLevel.warn, message, tag, LogSource.dart);
  }

  /// 输出 error 日志
  ///
  /// [message] 日志内容
  /// [tag] 日志标签
  static void error(String message, {String tag = 'gromore'}) {
    _log(LogLevel.error, message, tag, LogSource.dart);
  }

  /// 处理原生日志事件
  ///
  /// [event] 日志事件
  static void handleNative(LogEvent event) {
    if (_handler != null) {
      _handler!(event);
    }
    if (_printNativeLog && _shouldLog(event.level)) {
      debugPrint(_format(event));
    }
  }

  /// 统一日志输出入口
  ///
  /// [level] 日志级别
  /// [message] 日志内容
  /// [tag] 日志标签
  /// [source] 日志来源
  static void _log(LogLevel level, String message, String tag, LogSource source) {
    if (!_shouldLog(level)) {
      return;
    }
    final event = LogEvent(
      level: level,
      message: message,
      tag: tag,
      timestamp: DateTime.now(),
      source: source,
    );
    if (_handler != null) {
      _handler!(event);
    }
    debugPrint(_format(event));
  }

  /// 判断是否需要输出日志
  ///
  /// [level] 日志级别
  static bool _shouldLog(LogLevel level) {
    if (!_enabled) {
      return false;
    }
    return level.index >= _level.index;
  }

  /// 格式化日志文本
  ///
  /// [event] 日志事件
  static String _format(LogEvent event) {
    final time = event.timestamp.toIso8601String();
    return '[${event.source.value}][${event.level.value}][${event.tag}] $time ${event.message}';
  }
}
