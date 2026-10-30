/// 积分转让结果（`POST /points/transfers`，FR-8.3 会员互赠）。
///
/// 幂等重放时后端返回首次结果并置 `idempotent = true`，
/// 前端据此提示「该笔已处理过」而不是再报成功。
class PointsTransferResult {
  const PointsTransferResult({
    required this.transferNo,
    required this.toPhone,
    this.toNickname = '',
    this.points = '0',
    this.balanceAfter = '0',
    this.idempotent = false,
    this.createdAt,
  });

  /// 转让单号（双方流水同一 transferNo）
  final String transferNo;
  final String toPhone;
  final String toNickname;

  /// 本次转让积分（字符串，避免大数精度问题）
  final String points;

  /// 转让后转出方余额
  final String balanceAfter;

  /// true 表示同一 requestNo 的重放结果，首次请求为 false
  final bool idempotent;
  final DateTime? createdAt;

  factory PointsTransferResult.fromJson(Map<String, dynamic> json) =>
      PointsTransferResult(
        transferNo: json['transferNo'] as String? ?? '',
        toPhone: json['toPhone'] as String? ?? '',
        toNickname: json['toNickname'] as String? ?? '',
        points: '${json['points'] ?? '0'}',
        balanceAfter: '${json['balanceAfter'] ?? '0'}',
        idempotent: json['idempotent'] == true,
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      );
}
