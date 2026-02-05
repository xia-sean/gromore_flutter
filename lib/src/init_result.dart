/// 单个平台初始化结果
class PlatformInitResult {
  /// 构建初始化结果
  ///
  /// [success] 是否成功
  /// [errorCode] 错误码（可选）
  /// [errorMessage] 错误信息（可选）
  const PlatformInitResult({
    required this.success,
    this.errorCode,
    this.errorMessage,
  });

  /// 成功结果构造
  const PlatformInitResult.success()
      : success = true,
        errorCode = null,
        errorMessage = null;

  /// 失败结果构造
  ///
  /// [errorCode] 错误码
  /// [errorMessage] 错误信息
  const PlatformInitResult.failure({
    required this.errorCode,
    required this.errorMessage,
  }) : success = false;

  /// 跳过结果构造
  ///
  /// [reason] 跳过原因
  const PlatformInitResult.skipped({String? reason})
      : success = false,
        errorCode = 'skipped',
        errorMessage = reason ?? 'skipped';

  /// 是否成功
  final bool success;

  /// 错误码
  final String? errorCode;

  /// 错误信息
  final String? errorMessage;

  /// 转为通道传输 Map
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
    };
  }

  /// 从通道 Map 解析结果
  ///
  /// [map] 通道回传的结果数据
  static PlatformInitResult fromMap(Map<dynamic, dynamic> map) {
    final bool success = map['success'] == true;
    return PlatformInitResult(
      success: success,
      errorCode: map['errorCode']?.toString(),
      errorMessage: map['errorMessage']?.toString(),
    );
  }
}

/// 双端初始化结果（Android/iOS）
class InitResult {
  /// 构建双端初始化结果
  ///
  /// [android] Android 结果
  /// [ios] iOS 结果
  const InitResult({
    required this.android,
    required this.ios,
  });

  /// Android 结果
  final PlatformInitResult android;

  /// iOS 结果
  final PlatformInitResult ios;

  /// 转为通道传输 Map
  Map<String, dynamic> toMap() {
    return {
      'android': android.toMap(),
      'ios': ios.toMap(),
    };
  }
}
