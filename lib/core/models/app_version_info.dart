// 版本模型：本地安装版本 + 服务端下发的最新版本。

/// 本地安装版本（生产由 `package_info_plus` 读取，测试可注入）
class InstalledVersion {
  const InstalledVersion({
    required this.versionName,
    required this.versionCode,
  });

  /// 展示用版本名（Android versionName / iOS CFBundleShortVersionString）
  final String versionName;

  /// 单调递增的整数版本号（Android versionCode / iOS CFBundleVersion）
  final int versionCode;

  /// 形如 `v0.1.0`（版本比较只用 [versionCode]）
  String get display => 'v$versionName';

  @override
  String toString() => '$display($versionCode)';
}

/// `GET /common/app/version` 的响应体
///
/// 后端只下发「最新版本」，是否需要更新由前端按 [versionCode] 比较得出：
/// 比较 versionName 字符串会在 0.10.0 vs 0.9.0 上判错。
class AppVersionInfo {
  const AppVersionInfo({
    required this.versionName,
    required this.versionCode,
    this.downloadUrl,
    this.releaseNotes,
    this.forceUpdate = false,
    this.minSupportedVersionCode,
  });

  final String versionName;
  final int versionCode;

  /// Android APK 下载地址（iOS 为 App Store / TestFlight 链接）
  final String? downloadUrl;

  /// 更新说明，纯文本
  final String? releaseNotes;

  /// 后端开关：为 true 时所有低于 [versionCode] 的安装包都必须更新
  final bool forceUpdate;

  /// 最低可用 versionCode：低于它一律强更（不配则只看 [forceUpdate]）
  final int? minSupportedVersionCode;

  /// 该安装版本是否必须更新。
  ///
  /// [forceUpdate] 只对「确实有新版本可升」的旧包生效：已经等于最新版的
  /// 安装包即使开关为 true 也不算强更。
  bool requiresForceUpdate(InstalledVersion current) =>
      current.versionCode < versionCode &&
      (forceUpdate ||
          (minSupportedVersionCode != null &&
              current.versionCode < minSupportedVersionCode!));

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      versionName: _toText(json['versionName']) ?? '',
      // 后端 BigInt 会序列化成字符串，必须兼容
      versionCode: _toInt(json['versionCode']) ?? 0,
      downloadUrl: _toText(json['downloadUrl'] ?? json['url']),
      releaseNotes: _toText(json['releaseNotes'] ?? json['changelog']),
      forceUpdate: _toBool(json['forceUpdate']),
      minSupportedVersionCode: _toInt(json['minSupportedVersionCode']),
    );
  }
}

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool _toBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    return text == 'true' || text == '1';
  }
  return false;
}

String? _toText(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}
