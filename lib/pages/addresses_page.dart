import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/toast.dart';

/// 收货地址管理（列表 / 新增 / 编辑 / 设默认 / 删除，mock 数据）
class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  final List<_Address> _addresses = [
    _Address(
      name: '张三',
      phone: '138****0001',
      region: '上海市 徐汇区',
      detail: '漕溪北路 88 号 4 号楼 1201 室',
      isDefault: true,
    ),
    _Address(
      name: '张三',
      phone: '138****0001',
      region: '上海市 浦东新区',
      detail: '张杨路 500 号 9 楼 902',
      isDefault: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收货地址')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add_location_alt_outlined),
      ),
      body: _addresses.isEmpty
          ? const Center(child: Text('暂无收货地址，点右下角添加', style: TextStyle(color: Colors.black45)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _addresses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _addressCard(i),
            ),
    );
  }

  Widget _addressCard(int i) {
    final a = _addresses[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(a.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Text(a.phone, style: const TextStyle(color: Colors.black54, fontSize: 14)),
                const Spacer(),
                if (a.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kqwPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('默认', style: TextStyle(color: kqwPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Icon(Icons.location_on_outlined, size: 14, color: Colors.black45),
            const SizedBox(height: 4),
            Text('${a.region} ${a.detail}', style: const TextStyle(color: Colors.black87, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: () => _showForm(i),
                  child: const Text('编辑'),
                ),
                if (!a.isDefault)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final b in _addresses) {
                          b.isDefault = false;
                        }
                        a.isDefault = true;
                      });
                      showToast(context, '已设为默认地址（mock）');
                    },
                    child: const Text('设为默认'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => _confirmDelete(i),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showForm(int? index) {
    final orig = index == null ? null : _addresses[index];
    final nameCtrl = TextEditingController(text: orig?.name ?? '');
    final phoneCtrl = TextEditingController(text: orig?.phone ?? '');
    final regionCtrl = TextEditingController(text: orig?.region ?? '');
    final detailCtrl = TextEditingController(text: orig?.detail ?? '');
    bool isDefault = orig?.isDefault ?? false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(index == null ? '新增地址' : '编辑地址'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: '收货人',
                      prefixIcon: Icon(Icons.person_outline),
                      counter: SizedBox.shrink(),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    maxLength: 11,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      prefixIcon: Icon(Icons.phone_outlined),
                      counter: SizedBox.shrink(),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: regionCtrl,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: '所在地区（省 市 区）',
                      prefixIcon: Icon(Icons.place_outlined),
                      counter: SizedBox.shrink(),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailCtrl,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: '详细地址（街道/门牌/楼层）',
                      prefixIcon: Icon(Icons.home_outlined),
                      counter: SizedBox.shrink(),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: isDefault,
                    title: const Text('设为默认地址', style: TextStyle(fontSize: 14)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setDialogState(() => isDefault = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final region = regionCtrl.text.trim();
                final detail = detailCtrl.text.trim();
                if (name.isEmpty || phone.length < 11 || region.isEmpty || detail.isEmpty) {
                  showToast(ctx, '请完整填写收货人、手机号、地区、详细地址');
                  return;
                }
                final addr = _Address(name: name, phone: phone, region: region, detail: detail, isDefault: isDefault);
                if (isDefault) {
                  for (final b in _addresses) {
                    b.isDefault = false;
                  }
                }
                setState(() {
                  if (index == null) {
                    if (_addresses.isEmpty) addr.isDefault = true;
                    _addresses.add(addr);
                  } else {
                    _addresses[index] = addr;
                  }
                });
                Navigator.pop(ctx);
                showToast(context, index == null ? '地址已添加（mock）' : '地址已更新（mock）');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int i) {
    final a = _addresses[i];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该地址？'),
        content: Text('「${a.name} ${a.region}」删除后不可恢复'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                final wasDefault = a.isDefault;
                _addresses.removeAt(i);
                if (wasDefault && _addresses.isNotEmpty) {
                  _addresses.first.isDefault = true;
                }
              });
              Navigator.pop(ctx);
              showToast(context, '地址已删除（mock）');
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _Address {
  _Address({required this.name, required this.phone, required this.region, required this.detail, required this.isDefault});

  final String name;
  final String phone;
  final String region;
  final String detail;
  bool isDefault;
}
