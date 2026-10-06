import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 任务中心（FR-7.x：新手 30 天包 + 普通周期/成就任务）
class TaskTab extends StatelessWidget {
  const TaskTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('任务中心'),
          bottom: const TabBar(tabs: [Tab(text: '新手任务（剩 21 天）'), Tab(text: '普通任务')]),
        ),
        body: TabBarView(children: [_newbieList(), _normalList()]),
      ),
    );
  }

  Widget _newbieList() => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final done = i < 3;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: done ? const Color(0xFF3F8600) : Colors.grey.shade300,
                child: Icon(done ? Icons.check : Icons.radio_button_unchecked, color: Colors.white, size: 18),
              ),
              title: Text(_newbie[i].$1, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
              subtitle: Text(_newbie[i].$2),
              trailing: Text('${_newbie[i].$3} 分', style: pointsTextStyle(size: 14)),
            ),
          );
        },
      );

  Widget _normalList() => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final t = _normal[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(t.$1),
              subtitle: Text('${t.$2} · ${t.$3}'),
              trailing: Text('${t.$4} 分', style: pointsTextStyle(size: 14)),
              isThreeLine: true,
            ),
          );
        },
      );

  static const _newbie = [
    ('T-N1 完善资料', '绑定手机号 + 登记商户信息', 20),
    ('T-N2 首台装机', '完成 1 台 POS 机安装', 50),
    ('T-N3 首台达标', '25 天内刷够 1000 元', 200),
    ('T-N4 首次推荐', '成功推荐 1 名新用户注册', 50),
    ('T-N5 首推达标', '推荐的新用户装机达标', 150),
    ('T-N6 团队入队', '进入团队并满 3 人', 100),
  ];

  static const _normal = [
    ('每日签到', '周期·日', '连续 7 天 +10 分', 2),
    ('每周活跃', '周期·周', '完成 ≥3 次有效推广', 15),
    ('月度流水运营', '周期·月', '名下机器月交易 ≥5000 元', 100),
    ('成就：初具规模', '单次', '累计直推达标 ≥3 人', 300),
  ];
}
