/// C 端用户资料（`POST /user/login` 的 `user` 与 `GET /user/me` 同构）。
///
/// 登录只返回 id/phone/nickname/level 四个字段，`/user/me` 返回完整资料，
/// 因此模型里除 id/phone 外全部可空，避免两条链路互相覆盖。
/// 后端 `BigInt` 一律字符串（id），这里按字符串保存避免精度丢失。
class UserInfo {
  const UserInfo({
    required this.id,
    required this.phone,
    this.nickname,
    this.avatar,
    this.level = 0,
    this.levelName,
    this.gender = 0,
    this.birthday,
    this.inviteCode,
    this.referredByPhone,
    this.lv1ReferrerPhone,
    this.lv2ReferrerPhone,
    this.lv1ReferrerNickname,
    this.lv2ReferrerNickname,
    this.status = 1,
    this.canInstall = false,
    this.createdAt,
  });

  final String id;

  /// 本人手机号明文（仅本人可见）
  final String phone;
  final String? nickname;
  final String? avatar;

  /// 会员等级：0=L0 体验池，1=L1 ...，商城商品池按它过滤
  final int level;

  /// 等级名（tier.name，未配置回落 L{level}）
  final String? levelName;

  /// 0 未知 / 1 男 / 2 女
  final int gender;

  /// YYYY-MM-DD
  final String? birthday;

  final String? inviteCode;

  /// 推荐人手机号（后端已脱敏）
  final String? referredByPhone;

  /// L1（200 档）/ L2（600 档）房间上线手机号：进对应档位房时绑定，后端已脱敏
  final String? lv1ReferrerPhone;
  final String? lv2ReferrerPhone;

  /// L1 / L2 房间上线昵称：团队页选项卡「L1 张三」用；未绑定或对方无昵称为 null
  final String? lv1ReferrerNickname;
  final String? lv2ReferrerNickname;

  /// 账号状态：1 正常 / 0 停用
  final int status;

  /// 能否安装 POS 机：后台 `user.can_install` 开关（`POST /admin/users/{id}/can-install`），
  /// 「我的」据此决定是否展示「安装POS」入口；登录快照不含该字段，缺省 false。
  final bool canInstall;

  final DateTime? createdAt;

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: '${json['id'] ?? ''}',
      phone: json['phone'] as String? ?? '',
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 0,
      levelName: json['levelName'] as String?,
      gender: (json['gender'] as num?)?.toInt() ?? 0,
      birthday: json['birthday'] as String?,
      inviteCode: json['inviteCode'] as String?,
      referredByPhone: json['referredByPhone'] as String?,
      lv1ReferrerPhone: json['lv1ReferrerPhone'] as String?,
      lv2ReferrerPhone: json['lv2ReferrerPhone'] as String?,
      lv1ReferrerNickname: json['lv1ReferrerNickname'] as String?,
      lv2ReferrerNickname: json['lv2ReferrerNickname'] as String?,
      status: (json['status'] as num?)?.toInt() ?? 1,
      canInstall: json['canInstall'] as bool? ?? false,
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'nickname': nickname,
        'avatar': avatar,
        'level': level,
        'levelName': levelName,
        'gender': gender,
        'birthday': birthday,
        'inviteCode': inviteCode,
        'referredByPhone': referredByPhone,
        'lv1ReferrerPhone': lv1ReferrerPhone,
        'lv2ReferrerPhone': lv2ReferrerPhone,
        'lv1ReferrerNickname': lv1ReferrerNickname,
        'lv2ReferrerNickname': lv2ReferrerNickname,
        'status': status,
        'canInstall': canInstall,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  /// 手机号脱敏展示：138****0001
  String get maskedPhone => phone.length >= 7
      ? '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}'
      : phone;

  /// 优先昵称，其次脱敏手机号
  String get displayName {
    final n = nickname?.trim();
    return n != null && n.isNotEmpty ? n : maskedPhone;
  }

  /// 等级标签：优先后端等级名，否则 L{level}
  String get levelLabel {
    final name = levelName?.trim();
    return name != null && name.isNotEmpty ? name : 'L$level';
  }

  String get genderLabel => switch (gender) {
        1 => '男',
        2 => '女',
        _ => '未设置',
      };

  UserInfo copyWith({
    String? nickname,
    String? avatar,
    int? gender,
    String? birthday,
    String? inviteCode,
  }) =>
      UserInfo(
        id: id,
        phone: phone,
        nickname: nickname ?? this.nickname,
        avatar: avatar ?? this.avatar,
        level: level,
        levelName: levelName,
        gender: gender ?? this.gender,
        birthday: birthday ?? this.birthday,
        inviteCode: inviteCode ?? this.inviteCode,
        referredByPhone: referredByPhone,
        lv1ReferrerPhone: lv1ReferrerPhone,
        lv2ReferrerPhone: lv2ReferrerPhone,
        lv1ReferrerNickname: lv1ReferrerNickname,
        lv2ReferrerNickname: lv2ReferrerNickname,
        status: status,
        // 后台装机开关不在资料编辑范围内，必须原样透传，否则保存资料后入口会消失
        canInstall: canInstall,
        createdAt: createdAt,
      );
}
