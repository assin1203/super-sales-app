import '../api_client.dart';
import '../models/machine.dart';
import '../models/page_result.dart';

/// POS 机器接口（`/pos/*`）。
///
/// 新手任务状态 0 未开始 / 1 进行中 / 2 审核中 / 3 已完成；
/// 装机申请为公开提交流程（需 app token，userId 由后端从 JWT 取）。
class PosApi {
  PosApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 我的机器列表（需 app token）：已装机机器分页 + 申请中的新增机器（同一用户可多台）
  Future<MachineList> machines({
    int? newbieStatus,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/pos/machines',
      query: {
        if (newbieStatus != null) 'newbieStatus': '$newbieStatus',
        'pageNum': '$pageNum',
        'pageSize': '$pageSize',
      },
    );
    return MachineList.fromJson(json);
  }

  /// 我的装机申请列表（需 app token）：`GET /pos/applies`
  ///
  /// 与 [machines] 里附带的 `applies` 相比，这个接口支持按状态/来源筛选，
  /// 且不受机器分页影响，是「已提交」列表的权威数据源。
  /// [status] 0 待处理 / 1 已通过 / 2 已拒绝，缺省全部；
  /// [source] 1 装机申请 / 2 新增机器，缺省全部。
  Future<PageResult<MachineApply>> applies({
    int? status,
    int? source,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/pos/applies',
      query: {
        if (status != null) 'status': '$status',
        if (source != null) 'source': '$source',
        'pageNum': '$pageNum',
        'pageSize': '$pageSize',
      },
    );
    return PageResult.fromJson(json, MachineApply.fromJson);
  }

  /// 按客户手机号查待装申请（装机页「先查后装」）：`GET /pos/applies/pending-by-phone`
  ///
  /// 只出 status=0 待处理记录，先申请的在前；查不到不抛异常，用 `found=false` 判断。
  /// 拿到 items 后按 applyId 走 [installApply] 精确绑定，一次装一台。
  Future<PendingInstallPreview> pendingAppliesByPhone(
    String phone, {
    int? source,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/pos/applies/pending-by-phone',
      query: {
        'phone': phone,
        if (source != null) 'source': '$source',
      },
    );
    return PendingInstallPreview.fromJson(json);
  }

  /// 装机：把审核通过的申请转成正式机器（`POST /pos/applies/{id}/install`）
  ///
  /// [machineNo] 申请记录已有机号时可省略，传了必须与记录一致；
  /// [installMode] 1 平台安装（业务员上门，默认）/ 2 用户自装；
  /// 其余字段用于申请记录为空时补录。
  Future<MachineApply> installApply({
    required String applyId,
    String? machineNo,
    int? installMode,
    String? brandId,
    String? typeId,
    DateTime? bootTime,
    String? contactName,
    String? merchantName,
    String? region,
    String? address,
    String? remark,
    String? trafficFeeRemark,
    String? idTail,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/pos/applies/$applyId/install',
      body: _installBody(
        machineNo: machineNo,
        installMode: installMode,
        brandId: brandId,
        typeId: typeId,
        bootTime: bootTime,
        contactName: contactName,
        merchantName: merchantName,
        region: region,
        address: address,
        remark: remark,
        trafficFeeRemark: trafficFeeRemark,
        idTail: idTail,
      ),
    );
    return MachineApply.fromJson(json);
  }

  /// 按手机号装机（`POST /pos/applies/install`）
  ///
  /// [phone] 申请时填写的使用人手机号，据此定位待处理申请，一次只装一台；
  /// 申请记录还没填的联系人/门店/地区/地址等可在这次一并补录。
  Future<MachineApply> installApplyByPhone({
    required String phone,
    String? machineNo,
    int? installMode,
    String? brandId,
    String? typeId,
    DateTime? bootTime,
    String? contactName,
    String? merchantName,
    String? region,
    String? address,
    String? remark,
    String? trafficFeeRemark,
    String? idTail,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/pos/applies/install',
      body: {
        'phone': phone,
        ..._installBody(
          machineNo: machineNo,
          installMode: installMode,
          brandId: brandId,
          typeId: typeId,
          bootTime: bootTime,
          contactName: contactName,
          merchantName: merchantName,
          region: region,
          address: address,
          remark: remark,
          trafficFeeRemark: trafficFeeRemark,
          idTail: idTail,
        ),
      },
    );
    return MachineApply.fromJson(json);
  }

  /// 装机请求体：空值不传，避免覆盖申请记录里已有的值
  Map<String, dynamic> _installBody({
    String? machineNo,
    int? installMode,
    String? brandId,
    String? typeId,
    DateTime? bootTime,
    String? contactName,
    String? merchantName,
    String? region,
    String? address,
    String? remark,
    String? trafficFeeRemark,
    String? idTail,
  }) {
    String? filled(String? value) =>
        (value != null && value.isNotEmpty) ? value : null;
    return {
      if (filled(machineNo) != null) 'machineNo': machineNo,
      if (installMode != null) 'installMode': '$installMode',
      if (filled(brandId) != null) 'brandId': brandId,
      if (filled(typeId) != null) 'typeId': typeId,
      if (bootTime != null) 'bootTime': _dateText(bootTime),
      if (filled(contactName) != null) 'contactName': contactName,
      if (filled(merchantName) != null) 'merchantName': merchantName,
      if (filled(region) != null) 'region': region,
      if (filled(address) != null) 'address': address,
      if (filled(remark) != null) 'remark': remark,
      if (filled(trafficFeeRemark) != null) 'trafficFeeRemark': trafficFeeRemark,
      if (filled(idTail) != null) 'idTail': idTail!.trim().toUpperCase(),
    };
  }

  /// 扫机号查机具档案（`GET /pos/machines/{sn}/info`）
  ///
  /// 装机页扫码后调用：命中台账即回填品牌/类型/型号，业务员不用手填；
  /// 查不到不抛异常，用 `found=false` 判断（此时页面保持手选品牌/类型）。
  Future<PosMachineProfile> machineProfile(String sn) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/pos/machines/${Uri.encodeComponent(sn)}/info',
    );
    return PosMachineProfile.fromJson(json);
  }

  /// 按客户实名查已装机器（`GET /pos/installed-machines`）
  ///
  /// 装机页提交前的核对步骤：[name] 客户姓名 + [idTail] 身份证号后 6 位一起查，
  /// 只回机器号与品牌；查不到不抛异常，用 `found=false` + `message` 走提示。
  Future<InstalledMachines> installedMachines({
    required String name,
    required String idTail,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/pos/installed-machines',
      query: {'name': name, 'idTail': idTail.trim().toUpperCase()},
    );
    return InstalledMachines.fromJson(json);
  }

  /// 机器详情（含时间线与奖励状态）
  Future<MachineDetail> machineDetail(String sn) async {
    final json = await _api.get<Map<String, dynamic>>('/pos/machines/$sn');
    return MachineDetail.fromJson(json);
  }

  /// 提交装机申请（同手机号 7 天内重复申请会被拦截）
  ///
  /// [useType] 使用人标记：1 自己用 / 2 他人用。
  /// 后端 `MachineApplyDto` 尚未加该字段，上线前提交会被后端忽略
  /// （不影响其余字段落库），后端补齐后无需再改调用方。
  /// 提交装机申请（`POST /pos/apply`）
  ///
  /// [proofImages] 申请时上传的凭证截图 URL（选填，最多 4 张），
  /// 先调 `POST /common/upload/image` 换地址，空列表不传。
  Future<MachineApplyResult> apply({
    required String contactName,
    required String phone,
    int? useType,
    String? merchantName,
    String? region,
    String? address,
    String? remark,
    List<String>? proofImages,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/pos/apply',
      body: {
        'contactName': contactName,
        'phone': phone,
        if (useType != null) 'useType': useType,
        if (merchantName != null && merchantName.isNotEmpty)
          'merchantName': merchantName,
        if (region != null && region.isNotEmpty) 'region': region,
        if (address != null && address.isNotEmpty) 'address': address,
        if (remark != null && remark.isNotEmpty) 'remark': remark,
        if (proofImages != null && proofImages.isNotEmpty)
          'proofImages': proofImages,
      },
    );
    return MachineApplyResult.fromJson(json);
  }

  /// 验证「他人使用」的使用人手机号（`POST /pos/apply/verify-phone`）
  ///
  /// 验证码先由 `/common/sms/send` 下发；校验通过后服务端写 10 分钟有效的标记，
  /// 号码未注册时自动建号并把推广人绑到当前登录用户，`useType=2` 的申请提交时才放行。
  Future<ApplyPhoneVerifyResult> verifyApplyPhone({
    required String phone,
    required String code,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/pos/apply/verify-phone',
      body: {'phone': phone, 'code': code},
    );
    return ApplyPhoneVerifyResult.fromJson(json);
  }

  /// 新手任务提交审核（成功后后端置「审核中」，返回新状态供页面就地更新）
  Future<NewbieSubmitResult> submitNewbie(String sn) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/pos/newbie/submit',
      body: {'sn': sn},
    );
    return NewbieSubmitResult.fromJson(json);
  }

  /// 品牌下拉（后台 /admin/pos/brands 维护，仅返回启用项，sort 升序）
  Future<List<PosBrandOption>> brands() async {
    final json = await _api.get<Map<String, dynamic>>('/pos/brands');
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => PosBrandOption.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 类型下拉（后台 /admin/pos/types 维护）
  Future<List<PosTypeOption>> types() async {
    final json = await _api.get<Map<String, dynamic>>('/pos/types');
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => PosTypeOption.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 新增机器：机号全局唯一（重复 → 41009），机号能查到归属用户则绑定客户
  Future<MachineAddResult> addMachine({
    required String machineNo,
    required String customerPhone,
    String? brandId,
    String? typeId,
    String? trafficFeeRemark,
    DateTime? bootTime,
    String? remark,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/pos/machines',
      body: {
        'machineNo': machineNo,
        'customerPhone': customerPhone,
        if (brandId != null && brandId.isNotEmpty) 'brandId': brandId,
        if (typeId != null && typeId.isNotEmpty) 'typeId': typeId,
        if (trafficFeeRemark != null && trafficFeeRemark.isNotEmpty)
          'trafficFeeRemark': trafficFeeRemark,
        if (bootTime != null) 'bootTime': _dateText(bootTime),
        if (remark != null && remark.isNotEmpty) 'remark': remark,
      },
    );
    return MachineAddResult.fromJson(json);
  }

  /// 日期参数统一 yyyy-MM-dd（后端 DATE 列按此格式校验）
  static String _dateText(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}

final PosApi posApi = PosApi();
