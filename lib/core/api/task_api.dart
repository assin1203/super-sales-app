import '../api_client.dart';
import '../models/task_item.dart';
import '../request_no.dart';

/// 任务中心接口（`/tasks/*`），全部需 app token。
///
/// `category`：1 新手任务 / 2 日常任务，缺省全部；列表不分页。
class TaskApi {
  TaskApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 任务列表（模板 + 本人当前周期实例）
  Future<List<TaskItem>> list({int? category}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/tasks',
      query: {if (category != null) 'category': '$category'},
    );
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => TaskItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 任务详情（含规则文案与最近 10 条发奖记录）
  Future<TaskDetail> detail(String code) async {
    final json = await _api.get<Map<String, dynamic>>('/tasks/$code');
    return TaskDetail.fromJson(json);
  }

  /// 领取任务奖励：同 requestNo 重放返回首次结果，重复领取报 42002
  Future<TaskClaimResult> claim(String code, {String? requestNo}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/tasks/$code/claim',
      body: {'requestNo': requestNo ?? newRequestNo()},
    );
    return TaskClaimResult.fromJson(json);
  }
}

final TaskApi taskApi = TaskApi();
