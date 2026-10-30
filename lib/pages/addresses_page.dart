import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/address_api.dart';
import '../core/api_client.dart';
import '../core/models/address.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../core/widgets/async_view.dart';

/// 收货地址管理（列表 / 新增 / 编辑 / 设默认 / 删除）
///
/// 数据源 `/user/addresses`：上限 20 条（超限 11001），同一用户仅一条默认。
class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  List<AddressItem> _items = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await addressApi.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _error = e.displayMessage;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setDefault(AddressItem item) async {
    setState(() => _busyId = item.id);
    try {
      await addressApi.setDefault(item.id);
      if (!mounted) return;
      showToast(context, '已设为默认地址');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmDelete(AddressItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该地址？'),
        content: Text('「${item.receiver} ${item.fullAddress}」删除后不可恢复'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busyId = item.id);
    try {
      await addressApi.remove(item.id);
      if (!mounted) return;
      showToast(context, '地址已删除');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收货地址')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add_location_alt_outlined),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: AsyncStateView(
          loading: _loading,
          error: _error,
          isEmpty: _items.isEmpty,
          onRetry: _load,
          emptyText: '暂无收货地址，点右下角添加',
          emptyIcon: Icons.location_off_outlined,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _addressCard(_items[i]),
          ),
        ),
      ),
    );
  }

  Widget _addressCard(AddressItem a) {
    final busy = _busyId == a.id;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(a.receiver,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Text(a.phone,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 14)),
                const Spacer(),
                if (a.isDefault)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kqwPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('默认',
                        style: TextStyle(
                            color: kqwPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.black45),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(a.fullAddress,
                      style: const TextStyle(
                          color: Colors.black87, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: busy ? null : () => _showForm(a),
                  child: const Text('编辑'),
                ),
                if (!a.isDefault)
                  TextButton(
                    onPressed: busy ? null : () => _setDefault(a),
                    child: Text(busy ? '处理中…' : '设为默认'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: busy ? null : () => _confirmDelete(a),
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

  Future<void> _showForm(AddressItem? orig) async {
    final receiverCtrl = TextEditingController(text: orig?.receiver ?? '');
    final phoneCtrl = TextEditingController(text: orig?.phone ?? '');
    final provinceCtrl = TextEditingController(text: orig?.province ?? '');
    final cityCtrl = TextEditingController(text: orig?.city ?? '');
    final districtCtrl = TextEditingController(text: orig?.district ?? '');
    final detailCtrl = TextEditingController(text: orig?.detail ?? '');
    var isDefault = orig?.isDefault ?? false;
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            final receiver = receiverCtrl.text.trim();
            final phone = phoneCtrl.text.trim();
            final province = provinceCtrl.text.trim();
            final city = cityCtrl.text.trim();
            final district = districtCtrl.text.trim();
            final detail = detailCtrl.text.trim();
            if (receiver.isEmpty ||
                phone.length < 11 ||
                province.isEmpty ||
                city.isEmpty ||
                district.isEmpty ||
                detail.isEmpty) {
              showToast(ctx, '请完整填写收货人、手机号、省市区、详细地址');
              return;
            }
            setDialogState(() => submitting = true);
            try {
              if (orig == null) {
                await addressApi.create(
                  receiver: receiver,
                  phone: phone,
                  province: province,
                  city: city,
                  district: district,
                  detail: detail,
                  isDefault: isDefault,
                );
              } else {
                await addressApi.update(
                  orig.id,
                  receiver: receiver,
                  phone: phone,
                  province: province,
                  city: city,
                  district: district,
                  detail: detail,
                  isDefault: isDefault,
                );
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              showToast(context, orig == null ? '地址已添加' : '地址已更新');
              await _load();
            } on ApiException catch (e) {
              if (!ctx.mounted) return;
              setDialogState(() => submitting = false);
              showToast(ctx, e.displayMessage);
            }
          }

          return AlertDialog(
            title: Text(orig == null ? '新增地址' : '编辑地址'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(receiverCtrl, '收货人', Icons.person_outline, 20),
                    const SizedBox(height: 12),
                    _field(phoneCtrl, '手机号', Icons.phone_outlined, 11,
                        keyboardType: TextInputType.phone,
                        formatters: [FilteringTextInputFormatter.digitsOnly]),
                    const SizedBox(height: 12),
                    _field(provinceCtrl, '省 / 直辖市', Icons.place_outlined, 20),
                    const SizedBox(height: 12),
                    _field(cityCtrl, '市', Icons.location_city_outlined, 20),
                    const SizedBox(height: 12),
                    _field(districtCtrl, '区 / 县', Icons.place_outlined, 20),
                    const SizedBox(height: 12),
                    _field(detailCtrl, '详细地址（街道/门牌/楼层）',
                        Icons.home_outlined, 60),
                    const SizedBox(height: 4),
                    CheckboxListTile(
                      value: isDefault,
                      title:
                          const Text('设为默认地址', style: TextStyle(fontSize: 14)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) =>
                          setDialogState(() => isDefault = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                onPressed: submitting ? null : submit,
                child: Text(submitting ? '保存中…' : '保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon,
    int maxLength, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        counter: const SizedBox.shrink(),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
