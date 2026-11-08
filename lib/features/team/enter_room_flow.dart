import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/team_api.dart';
import '../../core/api_client.dart';
import '../../core/models/enter_room_result.dart';
import '../../core/models/room_package.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';

/// 入房流程（首页档位卡、团队页共用）：确认弹窗 → `POST /team/rooms/enter`
/// → 成功提示并跳房间详情。
///
/// 积分口径全部在后端：首次入房才买礼包扣 `entryPoints`，买过（终身一次）后
/// 进房不再扣费。所以可用积分不足且未购该档位时**直接拦截**，引导用户先
/// 去积分中心获取积分；已购档位（[RoomPackage.purchased]）放行，余额未知
/// （接口失败）也不拦，交给后端判定。
///
/// 返回入房回执；用户取消、积分不足或接口失败返回 null。
Future<EnterRoomResult?> enterRoomFlow(
  BuildContext context, {
  required RoomPackage pkg,
  int? balance,
  TeamApi? api,
}) async {
  final client = api ?? teamApi;
  final result = await showDialog<Object>(
    context: context,
    builder: (dialogContext) => _EnterRoomDialog(
      pkg: pkg,
      balance: balance,
      api: client,
    ),
  );
  if (!context.mounted) return null;
  if (result is _NeedPoints) {
    context.push('/points');
    return null;
  }
  if (result is! EnterRoomResult) return null;
  showToast(context, result.summary);
  context.push('/room/${result.roomId}');
  return result;
}

/// 弹窗回执哨兵：积分不足，交给外层引导去积分中心。
class _NeedPoints {
  const _NeedPoints();
}

class _EnterRoomDialog extends StatefulWidget {
  const _EnterRoomDialog({
    required this.pkg,
    required this.balance,
    required this.api,
  });

  final RoomPackage pkg;

  /// 可用积分；null 表示余额未知（接口失败）
  final int? balance;
  final TeamApi api;

  @override
  State<_EnterRoomDialog> createState() => _EnterRoomDialogState();
}

class _EnterRoomDialogState extends State<_EnterRoomDialog> {
  bool _submitting = false;

  /// 积分不足且没买过该档位礼包：直接拦下，不允许进入
  bool get _blocked {
    if (widget.pkg.purchased) return false;
    final balance = widget.balance;
    if (balance == null) return false; // 余额未知，交后端判定
    return balance < widget.pkg.entryPoints;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.api.enterRoom(packageId: widget.pkg.id);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 失败原因以后端为准：积分不足 / 已在房间中 / 档位不符 / 未登录
      showToast(context, e.displayMessage);
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pkg = widget.pkg;
    final balance = widget.balance;
    final lack = balance == null ? 0 : pkg.entryPoints - balance;
    return AlertDialog(
      title: Text(_blocked ? '积分不足' : '进入房间'),
      content: Text(_content(pkg, balance, lack)),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        if (_blocked)
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(const _NeedPoints()),
            child: const Text('去获取积分',
                style: TextStyle(color: Colors.white)),
          )
        else
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('确认进入',
                    style: TextStyle(color: Colors.white)),
          ),
      ],
    );
  }

  String _content(RoomPackage pkg, int? balance, int lack) {
    if (_blocked) {
      return '「${pkg.name}」档位入房需 ${pkg.entryPoints} 积分，'
          '当前可用积分 $balance，还差 $lack 积分。\n'
          '请先到积分中心获取积分后再进入房间。';
    }
    if (pkg.purchased) {
      return '您已购买「${pkg.name}」档位礼包，本次进房不再扣积分。'
          '${balance != null ? '\n当前可用积分：$balance。' : ''}';
    }
    return '「${pkg.name}」档位入房需消耗 ${pkg.entryPoints} 积分；'
        '首次进入会购买该档位礼包（终身一次），之后进房不再扣积分。'
        '${balance != null ? '\n当前可用积分：$balance。' : ''}';
  }
}

/// 团队页用：先拉档位列表让用户选，再走同一个入房流程。
/// 拉不到档位时用默认档（不传 packageId，后端取 sort 升序首条）。
Future<EnterRoomResult?> pickPackageAndEnter(
  BuildContext context, {
  int? balance,
  TeamApi? api,
}) async {
  final client = api ?? teamApi;
  List<RoomPackage> packages;
  try {
    packages = await client.roomPackages();
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.displayMessage);
    return null;
  }
  if (!context.mounted) return null;

  RoomPackage? picked;
  if (packages.length <= 1) {
    // 只有一档（或没配档位）就不用选，直接确认
    picked = packages.isEmpty ? null : packages.first;
  } else {
    picked = await showDialog<RoomPackage>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择入房档位',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        children: [
          for (final pkg in packages)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, pkg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(pkg.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text('${pkg.entryPoints} 积分', style: pointsTextStyle()),
                ],
              ),
            ),
        ],
      ),
    );
  }
  if (!context.mounted) return null;
  if (picked == null && packages.isNotEmpty) return null; // 用户取消选择

  // 没配档位时给个占位包，让后端走默认档（sort 升序首条）
  final pkg = picked ??
      const RoomPackage(
        id: '',
        code: '',
        name: '默认档',
        entryPoints: 0,
      );
  return enterRoomFlow(context, pkg: pkg, balance: balance, api: client);
}
