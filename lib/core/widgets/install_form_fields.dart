import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/machine.dart';

/// 装机表单的共享字段与样式。
///
/// 「安装 POS 机」页（`AddMachinePage`）和机器列表里的装机弹窗（`_InstallDialog`）收的是同一张表单：
/// 安装方式、机器号、品牌、类型、流量费备注、开机时间、备注。两边各写一份的后果是漂移——
/// 历史上弹窗就漏了流量费备注，业务员在弹窗里装机时这一项永远传不上去。
/// 字段集合、校验入口和样式统一收在这里，改一处两边同时生效。

/// 身份证号后 6 位归一化：去空格 + 末位 X 统一大写。
///
/// 后端 `@Matches(^\d{5}[0-9X]$)` 只认大写，前端输入允许小写 x，
/// 所以提交前、核对前都必须先归一化，避免「界面能过、后端 400」。
String normalizeInstallIdTail(String value) => value.trim().toUpperCase();

/// 身份证号后 6 位校验（与后端 `@Matches` 同口径）：前 5 位数字，末位数字或 X。
String? validateInstallIdTail(String? value) {
  final idTail = normalizeInstallIdTail(value ?? '');
  if (idTail.isEmpty) return '请输入客户身份证号后 6 位';
  if (!RegExp(r'^\d{5}[0-9X]$').hasMatch(idTail)) {
    return '请输入身份证号最后 6 位（末位可为 X）';
  }
  return null;
}

/// 客户姓名必填（实名核对用，必须与身份证一致）
String? validateInstallContactName(String? value) {
  if ((value ?? '').trim().isEmpty) return '请输入客户姓名';
  return null;
}

const _borderColor = Color(0xFFDDE2EA);
const _focusColor = Color(0xFF2E7BFF);
const _hintColor = Color(0xFF9AA3B2);
const _labelColor = Color(0xFF4A5160);
const _iconColor = Color(0xFF8A93A6);

/// 标签在上的字段容器（与装机页视觉一致），[required] 时标签前加红星
Widget installField(String label, {required Widget child, bool required = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (required)
              const Text('*', style: TextStyle(fontSize: 13, color: Color(0xFFE53935))),
            if (required) const SizedBox(width: 2),
            Text(label, style: const TextStyle(fontSize: 13, color: _labelColor)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

OutlineInputBorder installBorder() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _borderColor),
    );

OutlineInputBorder installFocusedBorder() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _focusColor, width: 1.4),
    );

InputDecoration installInputDecoration(String hint, {Widget? suffixIcon}) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: installBorder(),
      enabledBorder: installBorder(),
      focusedBorder: installFocusedBorder(),
      suffixIcon: suffixIcon,
    );

InputDecoration installDropdownDecoration(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: installBorder(),
      enabledBorder: installBorder(),
      focusedBorder: installFocusedBorder(),
      suffixIcon: const Icon(Icons.keyboard_arrow_down, size: 20, color: _iconColor),
    );

String _two(int v) => v.toString().padLeft(2, '0');

/// 开机日期选择框（点开系统日期选择器，不允许选未来）
Widget installDateField({required DateTime? value, required VoidCallback onTap}) {
  final text = value == null
      ? '选择开机日期'
      : '${value.year}-${_two(value.month)}-${_two(value.day)}';
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: value == null ? _hintColor : const Color(0xFF1F2430),
              ),
            ),
          ),
          const Icon(Icons.calendar_today_outlined, size: 18, color: _iconColor),
        ],
      ),
    ),
  );
}

/// 打开开机日期选择器；返回 null 表示用户取消
Future<DateTime?> pickInstallBootDate(BuildContext context, DateTime? current) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: current ?? now,
    firstDate: DateTime(now.year - 5),
    lastDate: now,
    helpText: '选择开机日期',
    cancelText: '取消',
    confirmText: '确定',
  );
}

/// 装机表单字段集合。
///
/// 状态由调用方持有（[installMode] / [brandId] / [typeId] / [bootDate] 都是受控值），
/// 本组件只负责渲染和把变更回传；[phoneField] 供装机页插入「客户手机号」（弹窗按 applyId 装机不需要），
/// [extraFields] 供弹窗补齐联系人/门店/地区/地址。
class InstallFormFields extends StatelessWidget {
  const InstallFormFields({
    super.key,
    required this.snController,
    required this.trafficFeeController,
    required this.remarkController,
    required this.installMode,
    required this.onInstallModeChanged,
    required this.brands,
    required this.types,
    required this.brandId,
    required this.typeId,
    required this.onBrandChanged,
    required this.onTypeChanged,
    required this.bootDate,
    required this.onPickBootDate,
    this.optionsLoading = false,
    this.optionsError,
    this.onRetryOptions,
    this.snValidator,
    this.onScanSn,
    this.snFocusNode,
    this.machineInfo,
    this.contactNameController,
    this.contactNameValidator,
    this.phoneField,
    this.idTailController,
    this.idTailValidator,
    this.identityCheck,
    this.extraFields = const <Widget>[],
  });

  final TextEditingController snController;
  final TextEditingController trafficFeeController;
  final TextEditingController remarkController;

  final int installMode;
  final ValueChanged<int> onInstallModeChanged;

  final List<PosBrandOption> brands;
  final List<PosTypeOption> types;
  final String? brandId;
  final String? typeId;
  final ValueChanged<String?> onBrandChanged;
  final ValueChanged<String?> onTypeChanged;

  final DateTime? bootDate;
  final VoidCallback onPickBootDate;

  final bool optionsLoading;
  final String? optionsError;
  final VoidCallback? onRetryOptions;

  final FormFieldValidator<String>? snValidator;
  final VoidCallback? onScanSn;

  /// 机器号输入框焦点：装机页用它监听「手输机号离开输入框」后自动查机具档案
  final FocusNode? snFocusNode;

  /// 机具信息展示位（扫码带出的品牌/类型/型号），紧跟在机器号之后
  final Widget? machineInfo;

  /// 客户姓名（实名核对的第一项，排在手机号之前）
  final TextEditingController? contactNameController;
  final FormFieldValidator<String>? contactNameValidator;

  /// 装机页把「客户手机号」插在机器号之后；弹窗按申请单装机，不需要
  final Widget? phoneField;

  /// 客户身份证号后 6 位（实名核对，装机必填）：手机号之后插入
  final TextEditingController? idTailController;
  final FormFieldValidator<String>? idTailValidator;

  /// 实名核对结果与「核对已装机器」按钮（装机页用），紧跟身份证字段
  final Widget? identityCheck;

  /// 额外字段（弹窗用：联系人 / 门店名称 / 所在地区 / 详细地址），与备注一起排在最后
  final List<Widget> extraFields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        installField(
          '安装方式',
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('平台安装')),
                ButtonSegment(value: 2, label: Text('用户自装')),
              ],
              selected: {installMode},
              onSelectionChanged: (v) => onInstallModeChanged(v.first),
            ),
          ),
        ),
        installField(
          '机器号',
          child: TextFormField(
            controller: snController,
            focusNode: snFocusNode,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z_-]')),
              LengthLimitingTextInputFormatter(64),
            ],
            validator: snValidator,
            decoration: installInputDecoration(
              '扫码或手输机号',
              suffixIcon: onScanSn == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 20, color: _iconColor),
                      tooltip: '扫码录入',
                      onPressed: onScanSn,
                    ),
            ),
          ),
        ),
        if (machineInfo != null) machineInfo!,
        if (contactNameController != null)
          installField(
            '客户姓名',
            required: true,
            child: TextFormField(
              controller: contactNameController,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              validator: contactNameValidator,
              decoration: installInputDecoration('与身份证一致的客户姓名'),
            ),
          ),
        if (phoneField != null) phoneField!,
        if (idTailController != null)
          installField(
            '身份证号后 6 位',
            required: true,
            child: TextFormField(
              controller: idTailController,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                LengthLimitingTextInputFormatter(6),
              ],
              validator: idTailValidator,
              decoration: installInputDecoration('客户身份证号最后 6 位（末位可为 X）'),
            ),
          ),
        if (identityCheck != null) identityCheck!,
        installField('品牌', child: _brandField()),
        installField('类型', child: _typeField()),
        installField(
          '流量费备注',
          child: TextFormField(
            controller: trafficFeeController,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
            decoration: installInputDecoration('如：流量费孔出、月租 5 元'),
          ),
        ),
        installField(
          '开机时间',
          child: installDateField(value: bootDate, onTap: onPickBootDate),
        ),
        ...extraFields,
        installField(
          '备注',
          child: TextFormField(
            controller: remarkController,
            maxLines: 3,
            inputFormatters: [LengthLimitingTextInputFormatter(100)],
            decoration: installInputDecoration('其他备注'),
          ),
        ),
      ],
    );
  }

  Widget _brandField() {
    if (optionsLoading) return _optionPlaceholder('品牌加载中…');
    if (optionsError != null) return _optionFailed();
    return DropdownButtonFormField<String>(
      // FormField 只在初始时读一次 initialValue（didUpdateWidget 不同步），
      // 扫码回填是程序改选中值：用 key 重建才能把带出的品牌显示出来
      key: ValueKey('brand-${brandId ?? ''}'),
      initialValue: brandId,
      isExpanded: true,
      decoration: installDropdownDecoration(brands.isEmpty ? '暂无可选品牌' : '请选择品牌'),
      items: [
        for (final brand in brands) DropdownMenuItem(value: brand.id, child: Text(brand.name)),
      ],
      onChanged: onBrandChanged,
    );
  }

  Widget _typeField() {
    if (optionsLoading) return _optionPlaceholder('类型加载中…');
    if (optionsError != null) return _optionFailed();
    return DropdownButtonFormField<String>(
      // 同上：扫码带出的类型要立刻回显，靠 key 重建同步选中值
      key: ValueKey('type-${typeId ?? ''}'),
      initialValue: typeId,
      isExpanded: true,
      decoration: installDropdownDecoration(types.isEmpty ? '暂无可选类型' : '请选择类型'),
      items: [
        for (final type in types) DropdownMenuItem(value: type.id, child: Text(type.name)),
      ],
      onChanged: onTypeChanged,
    );
  }

  Widget _optionPlaceholder(String text) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontSize: 14, color: _hintColor)),
          ],
        ),
      );

  /// 字典加载失败：点一下重试（不打断已填写的机器号 / 手机号）
  Widget _optionFailed() => InkWell(
        onTap: onRetryOptions,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  optionsError ?? '选项加载失败，点击重试',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: _hintColor),
                ),
              ),
              const Icon(Icons.refresh, size: 18, color: _iconColor),
            ],
          ),
        ),
      );
}
