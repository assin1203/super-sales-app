import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/app_version_api.dart';
import 'api_client.dart';
import 'models/app_version_info.dart';
import 'theme.dart';
import 'toast.dart';

/// 读取本地安装版本（生产走 package_info_plus，测试注入固定值）
typedef InstalledVersionLoader = Future<InstalledVersion> Function();

/// 打开外部链接，返回是否成功（测试可替换，避免真的拉起浏览器）
typedef ExternalOpener = Future<bool> Function(Uri url);

/// 生产环境的本地版本读取
Future<InstalledVersion> loadInstalledVersion() async {
  final info = await PackageInfo.fromPlatform();
  return InstalledVersion(
    versionName: info.version,
    // Android 的 buildNumber 就是 versionCode，iOS 是 CFBundleVersion
    versionCode: int.tryParse(info.buildNumber.trim()) ?? 0,
  );
}

/// 当前平台标识，后端按平台分别下发版本
String get updatePlatform {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    default:
      return 'other';
  }
}

/// 版本检查与更新提示。
///
/// 发布新版后，旧包冷启动即比对 `versionCode`：有新版本就弹窗引导去下载，
/// 强更（后端 `forceUpdate` 或低于 `minSupportedVersionCode`）时弹窗不可关闭。
///
/// 失败策略：自动检查（冷启动）任何异常都静默放行——接口挂了、断网、
/// 后端还没上这个接口，都不该让用户打不开 App；只有用户主动点「检查更新」
/// 才给出失败提示。
class AppUpdateChecker {
  AppUpdateChecker({
    AppVersionApi? api,
    InstalledVersionLoader? loadVersion,
    ExternalOpener? openUrl,
  })  : _api = api ?? appVersionApi,
        _loadVersion = loadVersion ?? loadInstalledVersion,
        _openUrl = openUrl ?? _launchExternal;

  final AppVersionApi _api;
  final InstalledVersionLoader _loadVersion;
  final ExternalOpener _openUrl;

  /// 弹窗展示中：避免冷启动自动检查与手动检查叠出两个弹窗
  bool _showing = false;

  /// 检查并提示。
  ///
  /// [manual] 为用户主动点击：已是最新/检查失败都要给反馈；否则静默。
  Future<void> check(BuildContext context, {bool manual = false}) async {
    if (_showing) return;

    final InstalledVersion installed;
    final AppVersionInfo? latest;
    try {
      installed = await _loadVersion();
      latest = await _api.latest(
        platform: updatePlatform,
        versionCode: installed.versionCode,
      );
    } catch (e) {
      if (!manual || !context.mounted) return;
      showToast(
        context,
        e is ApiException ? e.displayMessage : '检查更新失败，请稍后重试',
      );
      return;
    }

    if (!context.mounted) return;

    if (latest == null || latest.versionCode <= installed.versionCode) {
      if (manual) showToast(context, '当前已是最新版本 ${installed.display}');
      return;
    }

    _showing = true;
    try {
      await _showUpdateDialog(context, latest: latest, installed: installed);
    } finally {
      _showing = false;
    }
  }

  Future<void> _showUpdateDialog(
    BuildContext context, {
    required AppVersionInfo latest,
    required InstalledVersion installed,
  }) {
    final force = latest.requiresForceUpdate(installed);
    final notes = latest.releaseNotes;
    return showDialog<void>(
      context: context,
      // 强更时点遮罩、返回键都不能关掉；返回键由 PopScope 拦住
      barrierDismissible: !force,
      builder: (ctx) => PopScope(
        canPop: !force,
        child: AlertDialog(
          title: Text('发现新版本 v${latest.versionName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notes != null) ...[
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF1F2430),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  '当前版本 ${installed.display}',
                  style: const TextStyle(fontSize: 12, color: kqwTextSecondary),
                ),
                if (force) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '本次为必要更新，完成后才能继续使用',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE5484D)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('稍后再说'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openDownload(context, latest.downloadUrl);
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDownload(BuildContext context, String? url) async {
    final target = url?.trim();
    final uri = (target == null || target.isEmpty)
        ? null
        : Uri.tryParse(target);
    if (uri == null) {
      showToast(context, '下载地址暂不可用，请稍后重试');
      return;
    }
    final ok = await _openUrl(uri);
    if (!ok && context.mounted) showToast(context, '无法打开下载页面');
  }

  static Future<bool> _launchExternal(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}

final AppUpdateChecker appUpdateChecker = AppUpdateChecker();
