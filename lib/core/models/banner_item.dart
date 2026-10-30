/// 首页广告位（`GET /home/banners`，公开端点，未登录也能看）。
///
/// `linkType`：0 不跳转 / 1 内部路由 / 2 外链 / 3 商品详情（服务端已把库内
/// 字符串枚举映射成数字）。items 为空时前端用本地兜底图，不算错误。
class BannerItem {
  const BannerItem({
    required this.id,
    required this.title,
    required this.image,
    this.subtitle = '',
    this.linkType = 0,
    this.linkValue = '',
    this.sort = 0,
    this.startAt,
    this.endAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String image;
  final int linkType;
  final String linkValue;
  final int sort;
  final DateTime? startAt;
  final DateTime? endAt;

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
        id: '${json['id'] ?? ''}',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        image: json['image'] as String? ?? '',
        linkType: (json['linkType'] as num?)?.toInt() ?? 0,
        linkValue: json['linkValue'] as String? ?? '',
        sort: (json['sort'] as num?)?.toInt() ?? 0,
        startAt: DateTime.tryParse('${json['startAt'] ?? ''}'),
        endAt: DateTime.tryParse('${json['endAt'] ?? ''}'),
      );

  bool get hasImage => image.isNotEmpty;

  /// 是否可点击（0 = 纯展示图）
  bool get clickable => linkType != 0 && linkValue.isNotEmpty;
}
