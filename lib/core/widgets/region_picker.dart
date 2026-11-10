import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 省市区数据（内置 `assets/regions.json`：31 省 / 341 市 / 3056 区县）。
///
/// 数据源自 modood/Administrative-divisions-of-China 的 `pca.json`，
/// 生成时做了两级归一化：直辖市的「市辖区 / 县」并入省级同名市，
/// 「省直辖县级行政区划」统一改名「省直辖县」；港澳台不在该数据集内。
///
/// 首次使用时读资源并缓存到进程内，之后同步取用；测试可注入替身避免读资源。
class RegionData {
  RegionData(this._tree);

  factory RegionData.fromMap(Map<String, Map<String, List<String>>> tree) =>
      RegionData(tree);

  final Map<String, Map<String, List<String>>> _tree;

  static RegionData? _cached;
  static RegionData? _override;

  /// 省份名（按资源文件顺序：华北 → 华南 → 西北）
  List<String> get provinces => _tree.keys.toList(growable: false);

  /// 某省下的市；省不存在时返回空列表，调用方不必判空
  List<String> citiesOf(String? province) {
    final cities = province == null ? null : _tree[province];
    return cities == null ? const [] : cities.keys.toList(growable: false);
  }

  /// 某市下的区县
  List<String> districtsOf(String? province, String? city) {
    final cities = province == null ? null : _tree[province];
    final districts = (cities == null || city == null) ? null : cities[city];
    return districts ?? const [];
  }

  /// 读 `assets/regions.json`，失败时返回空表（界面退化为不可选，不抛异常）
  static Future<RegionData> load() async {
    final injected = _override;
    if (injected != null) return injected;
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString('assets/regions.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final tree = <String, Map<String, List<String>>>{
        for (final p in json.entries)
          p.key: {
            for (final c in (p.value as Map<String, dynamic>).entries)
              c.key: (c.value as List<dynamic>).cast<String>(),
          },
      };
      return _cached = RegionData(tree);
    } catch (_) {
      return _cached = RegionData(const {});
    }
  }

  @visibleForTesting
  static void overrideForTest(RegionData? data) => _override = data;
}

/// 省市区三段拼串：直辖市去掉重复的市级（北京市 + 北京市 + 东城区 → 北京市东城区）
String joinRegion(String province, String city, String district) {
  final tail = city == province ? district : '$city$district';
  return '$province$tail';
}

/// 表单里的省市区选择项：外观与 TextFormField 一致，点击弹出三段联动选择。
class RegionPickerField extends StatelessWidget {
  const RegionPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = '请选择省 / 市 / 区（选填）',
  });

  /// 已选文本（省市区拼串）；空串表示未选
  final String value;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showRegionPicker(context);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: _border(),
          enabledBorder: _border(),
          suffixIcon: const Icon(Icons.keyboard_arrow_down,
              size: 20, color: Color(0xFF8A93A6)),
        ),
        child: Text(
          empty ? hint : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: empty ? const Color(0xFF9AA3B2) : const Color(0xFF1F2430),
          ),
        ),
      ),
    );
  }
}

/// 弹出省市区选择，确认返回拼串，取消返回 null
Future<String?> showRegionPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _RegionSheet(),
  );
}

OutlineInputBorder _border() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDDE2EA)),
    );

class _RegionSheet extends StatefulWidget {
  const _RegionSheet();

  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  late Future<RegionData> _future;

  String? _province;
  String? _city;
  String? _district;

  @override
  void initState() {
    super.initState();
    _future = RegionData.load();
  }

  void _pickProvince(RegionData data, String value) {
    if (_province == value) return;
    final cities = data.citiesOf(value);
    setState(() {
      _province = value;
      // 直辖市只有一个市级（北京市/北京市），自动选中省一次点击
      _city = cities.length == 1 ? cities.first : null;
      _district = null;
    });
  }

  void _pickCity(String value) {
    if (_city == value) return;
    setState(() {
      _city = value;
      _district = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: FutureBuilder<RegionData>(
        future: _future,
        builder: (context, snap) {
          final data = snap.data;
          if (data == null) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final cities = data.citiesOf(_province);
          final districts = data.districtsOf(_province, _city);
          final canConfirm =
              _province != null && _city != null && _district != null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    const Text('选择省 / 市 / 区',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 280,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _column(
                      data.provinces,
                      _province,
                      (v) => _pickProvince(data, v),
                    ),
                    const VerticalDivider(width: 1),
                    _column(cities, _city, _pickCity),
                    const VerticalDivider(width: 1),
                    _column(
                      districts,
                      _district,
                      (v) => setState(() => _district = v),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: canConfirm
                        ? () => Navigator.of(context)
                            .pop(joinRegion(_province!, _city!, _district!))
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A3D),
                      disabledBackgroundColor: const Color(0xFFE4E8EF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('确定',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 单列可选列表：选中项高亮，未选中的层级显示提示
  Widget _column(List<String> items, String? selected, ValueChanged<String> onTap) {
    if (items.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('请先选上一级',
              style: TextStyle(fontSize: 12, color: Color(0xFF9AA3B2))),
        ),
      );
    }
    return Expanded(
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final name = items[index];
          final active = name == selected;
          return InkWell(
            onTap: () => onTap(name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              color: active ? const Color(0xFFFFF3F0) : null,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? const Color(0xFFFF6A3D)
                      : const Color(0xFF1F2430),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
