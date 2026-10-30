import 'dart:math';

/// 幂等键（requestNo）生成：后端按 requestNo 去重，重放返回首次结果。
///
/// 形状为 `时间戳-随机串`，够唯一即可，不引入 uuid 依赖。
String newRequestNo() {
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = Random.secure();
  final suffix = List.generate(6, (_) => rand.nextInt(36).toRadixString(36)).join();
  return '$ts$suffix';
}
