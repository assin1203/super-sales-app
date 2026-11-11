import 'package:flutter_test/flutter_test.dart';

import 'package:kqw_app/core/models/machine.dart';

/// 申请单联系电话：后端一律脱敏，仅当脱敏值与本机登录号码一致时补全。
void main() {
  test('脱敏值匹配本人号码时补全为完整号码', () {
    expect(revealOwnPhone('138****8001', '13812348001'), '13812348001');
  });

  test('别人的号码保持脱敏', () {
    expect(revealOwnPhone('139****7777', '13812348001'), '139****7777');
  });

  test('没有登录号码或号码已明文时原样返回', () {
    expect(revealOwnPhone('138****8001', null), '138****8001');
    expect(revealOwnPhone('13812348001', '13812348001'), '13812348001');
    expect(revealOwnPhone('', '13812348001'), '');
  });

  test('登录号码过短不做匹配（避免全匹配）', () {
    expect(revealOwnPhone('138****8001', '138'), '138****8001');
  });
}
