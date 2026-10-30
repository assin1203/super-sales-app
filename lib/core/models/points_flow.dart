/// 积分流水（`GET /points/flows`）。
///
/// `flowType` 是前端数字 1~10（库内字符串枚举已在服务端映射），
/// `delta` / `balanceAfter` 为 BigInt 字符串（负数表示扣减）。
class PointsFlowItem {
  const PointsFlowItem({
    required this.id,
    required this.flowType,
    required this.typeName,
    required this.delta,
    required this.balanceAfter,
    required this.bizNo,
    required this.remark,
    this.createdAt,
  });

  final String id;

  /// 1 达标入队 / 2 推荐达标奖励 / 3 团队分红 / 4 任务奖励 / 5 商城兑换扣减
  /// 6 晋级礼奖励 / 7 后台人工调账 / 8 订单取消退回 / 9 积分礼包充值 / 10 其他
  final int flowType;
  final String typeName;

  /// 变动值（带符号）
  final String delta;

  /// 变动后余额
  final String balanceAfter;

  final String bizNo;
  final String remark;
  final DateTime? createdAt;

  factory PointsFlowItem.fromJson(Map<String, dynamic> json) => PointsFlowItem(
        id: '${json['id'] ?? ''}',
        flowType: (json['flowType'] as num?)?.toInt() ?? 10,
        typeName: json['typeName'] as String? ?? '',
        delta: '${json['delta'] ?? '0'}',
        balanceAfter: '${json['balanceAfter'] ?? '0'}',
        bizNo: json['bizNo'] as String? ?? '',
        remark: json['remark'] as String? ?? '',
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      );

  bool get isIncome => !delta.startsWith('-') && delta != '0';

  /// 带符号展示：+100 / -50
  String get deltaLabel => isIncome ? '+$delta' : delta;

  /// 流水类型筛选项（与后端 flowType 1~10 对齐）
  static const Map<int, String> typeLabels = {
    1: '达标入队积分',
    2: '推荐达标奖励',
    3: '团队分红',
    4: '任务奖励',
    5: '商城兑换扣减',
    6: '晋级礼奖励',
    7: '后台人工调账',
    8: '订单取消退回',
    9: '积分礼包充值',
    10: '其他',
  };
}
