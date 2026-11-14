# 前端 C 端接口对接清单

以运行实例 OpenAPI 与后端 mapper/service 源码为契约依据（v2.0 文档已滞后，见文末差异）。

## 约定

- 成功响应是**裸数据**，只有错误才包一层 `{code, message}`；`ApiClient` 已按此解析。
- 所有 `BigInt`（id、积分、金额）序列化为**字符串**，模型层用 `String` 保精度，需要数值时再解析。
- 后端未设 `setGlobalPrefix`，路径为根级（`/user/me`，**不是** `/api/user/me`）。
- 生产基地址 `https://zhy-api.citykafei.com`（根路径就是后端，**无** `/appApi`、`/api` 前缀），
  定义在 `lib/core/api_client.dart` 的 `apiBaseUrl`；本地联调用 `--dart-define=API_BASE_URL=http://<ip>:3000` 覆盖。
- 三套独立 JWT（`admin` / `app` / `internal`），本端只用 `app`。
- 全局 `ValidationPipe({whitelist:true, transform:true})`：DTO 未声明字段会被静默剔除，前端不要多传。
- 分页信封统一 `{items, total, pageNum, pageSize}`，由 `PageResult<T>` 解析；**公告是例外**（字段名 `list`，
  `notice_api.dart#list` 传了 `listKey: 'list'`）；banner / 礼包 / 任务 / 地址 / 候补等不分页接口只有 `{items, total}`，
  `PageResult.fromListJson` 兼容。

## 接口 → 封装 → 页面

| 模块 | 端点 | 封装 | 使用位置 |
| --- | --- | --- | --- |
| 认证 | `POST /user/login` | `user_api.dart#login` | `login_page.dart` |
| 认证 | `POST /user/login/code`（手机号 + 短信验证码，验证码先调 `POST /common/sms/send`；未注册 → 20001「请先注册」，验证码错/过期 → 400，失败过多 → 429） | `user_api.dart#loginByCode` | `login_page.dart` 验证码登录形态 |
| 认证 | `POST /user/register` | `user_api.dart#register` | 仅 service 层保留（注册页未做） |
| 认证 | `POST /user/refresh` | `user_api.dart#refresh` | `auth_provider.dart` 静默续期 / 401 重放 |
| 认证 | `POST /user/logout` | `user_api.dart#logout` | `me_tab.dart` 退出登录 |
| 资料 | `GET /user/me` | `user_api.dart#me` | `auth_provider.dart#loadProfile` → 首页/我的/资料页；`lv1ReferrerNickname` / `lv2ReferrerNickname` 是 **L1/L2 等级推荐人**昵称——沿推荐链由近及远第一个等级达标的上级（未达标则不绑），与贡献值命中的「有房上线」解耦（团队页选项卡「L1 张三」） |
| 资料 | `PUT /user/profile` | `user_api.dart#updateProfile` | `profile_page.dart` 保存昵称/头像 |
| 资料 | `PUT /user/password` | `user_api.dart#changePassword` | `password_page.dart`（成功后强制重登） |
| 推广 | `GET /user/invite` | `user_api.dart#invite` | `referral_page.dart` |
| 推广 | `GET /user/invite/records` | `user_api.dart#inviteRecords` | `referral_page.dart` 下级明细 |
| 推广 | `GET /user/ancestors` | `user_api.dart#ancestors` | 已封装，暂无页面消费 |
| 积分 | `GET /user/points` | `points_api.dart#summary`（另有 `user_api.dart#points` 同端点封装，无调用方） | `me_tab.dart`、`mall_tab.dart`、`home_tab.dart` 余额 |
| 积分 | `GET /points/flows` | `points_api.dart#flows` | `points_flow_page.dart`（类型筛选 + 分页）；`flowType` 1~11（11 = 会员互赠）。入房费分成 `ENTRY_REFERRAL` 后端尚未映射，暂归入 10「其他」，映射定稿后要同步筛选项 |
| 积分 | `GET /points/packages` | `points_api.dart#packages` | `home_tab.dart`、`packages_page.dart` |
| 积分 | `POST /points/packages/{id}/order` | `points_api.dart#createPackageOrder` | 同上，下单后提示待接支付 SDK |
| 商城 | `GET /mall/products` | `mall_api.dart#products` | `mall_tab.dart`（等级池/虚拟权益分栏） |
| 商城 | `POST /mall/exchange` | `mall_api.dart#exchange` | `mall_tab.dart` 兑换 |
| 订单 | `GET /mall/orders` | `mall_api.dart#orders` | `orders_page.dart` |
| 订单 | `GET /mall/orders/{id}` | `mall_api.dart#orderDetail` | `orders_page.dart` 详情 |
| 订单 | `POST /mall/orders/{id}/cancel` | `mall_api.dart#cancel` | `orders_page.dart` |
| 订单 | `POST /mall/orders/{id}/confirm` | `mall_api.dart#confirm` | `orders_page.dart` 确认收货 |
| 地址 | `GET/POST /user/addresses`、`PUT/DELETE /user/addresses/{id}`、`POST /user/addresses/{id}/default` | `address_api.dart` | `addresses_page.dart` |
| 机器 | `GET /pos/machines`、`GET /pos/machines/{sn}` | `pos_api.dart` | `machines_page.dart`、首页达标卡 |
| 机器 | `POST /pos/apply`（`proofImages` 装机凭证截图 URL 数组 ≤4 张，选填，先调 `POST /common/upload/image`；说明见 `install_guide_page.dart`）、`POST /pos/newbie/submit` | `pos_api.dart` | `apply_machine_page.dart` 装机申请（首页入口，凭证截图区在申请信息下方）、`machines_page.dart` 新手机器提交 |
| 机器 | `POST /pos/apply/verify-phone`（他人使用先验证使用人手机号：校验验证码 → 号码未注册则自动建号并把当前用户绑为推广人 → 写 10 分钟有效标记，`POST /pos/apply` 提交时消费；错码/过期 400） | `pos_api.dart#verifyApplyPhone` | `apply_machine_page.dart` 他人使用（发码前先过拼图滑块） |
| 机器 | `GET /pos/applies`（`status`/`source` 筛选） | `pos_api.dart#applies` | `machines_page.dart`「已提交」列表 |
| 机器 | `POST /pos/applies/{id}/install`（`installMode` 1 平台安装 / 2 用户自装；补录 `bootTime`/`contactName`/`merchantName`/`region`/`address`/`remark`/`trafficFeeRemark`；后端 `proofImages` 字段保留，App 不再上传） | `pos_api.dart#installApply` | `machines_page.dart` 已通过申请「立即装机」、`add_machine_page.dart` 装机页（先查到 `applyId` 再调它） |
| 机器 | `GET /pos/applies/pending-by-phone`（按手机号查待装机申请，返回 `PendingInstallPreview`：0 条给提示、1 条直接装、多条弹选择） | `pos_api.dart#pendingAppliesByPhone` | `add_machine_page.dart`「安装 POS 机」第一步 |
| 机器 | `POST /pos/applies/install`（服务端按手机号直接装机） | `pos_api.dart#installApplyByPhone`（**死代码：全仓无调用方**） | 未使用，装机统一走 `pendingAppliesByPhone` + `installApply`，保留待清理 |
| 机器 | `GET /pos/brands`、`GET /pos/types`（品牌/类型下拉，仅下发 `status=1` 且按 `sort` 升序） | `pos_api.dart#brands` / `#types` | `add_machine_page.dart` 表单、`machines_page.dart` 装机弹窗 |
| 机器 | `POST /common/upload/image`（multipart 字段 `file`，jpg/png/gif/webp ≤5MB，返回 `{url,key,size}`） | `api_client.dart#uploadImage` | 申请凭证截图、头像上传 |
| 机器 | `POST /pos/machines`（`MachineCreateDto`，直接建机） | `pos_api.dart#addMachine` | 已无页面调用，装机统一走 `pendingAppliesByPhone` + `POST /pos/applies/{id}/install` |
| 任务 | `GET /tasks`、`GET /tasks/{code}`、`POST /tasks/{code}/claim` | `task_api.dart` | `task_tab.dart`、首页任务卡 |
| 积分 | `POST /points/transfers`（会员互赠：扣转出方 → 加接收方，双方各留流水） | `points_api.dart#transfer` | `points_transfer_page.dart` 积分转让 |
| 团队 | `GET /team/rooms`、`GET /team/rooms/{id}`、`GET /team/rooms/{id}/members`（房间 VO 另含 `startedAt` 开始时间、`endedAt` 完成时间——优先归档时间 `room.last_dividend_at`、缺失回落末次分红时间、都没有为 null、`firstContributionUserId` 最先拿到贡献值的成员 userId，已结束房间座位据此加皇冠） | `team_api.dart` | `team_tab.dart`、`room_detail_page.dart` |
| 团队 | `GET /team/room-packages`（档位列表，按 `sort` 升序） | `team_api.dart#roomPackages` | `home_tab.dart` 房间档位卡 |
| 团队 | `POST /team/rooms/enter`（`packageId` 选填，缺省默认档；回执含 `entryPoints`/`purchased`/`uplineId`/`rebound`）。**入房顺序**：600 档（`ADVANCED`/lv2）要求先进入过 200 档（`BASIC`/lv1）房间，判据是 `room_op_log` 的 OCCUPY 记录（看是否真进过，不看 `user.level`），不满足 → 400 + `43005`「请先进入 200 档房间，再进入 600 档房间」；**入房费分成**：本次真扣了入房费时按 50% 分给等级推荐人，已购档位复用资格（`entryPoints=0`）不分成；`uplineId` 仍是贡献值命中者，与等级推荐人解耦 | `team_api.dart#enterRoom` | `enter_room_flow.dart`（首页/团队页共用；`room_package.dart#needsBasicRoomFirst` 提前提示顺序要求） |
| 团队 | `GET /team/wait-queue` | `team_api.dart#waitQueue` | `team_tab.dart` 候补队列 |
| 首页 | `GET /home/banners` | `home_api.dart#banners` | `home_tab.dart` 轮播（空则回落本地图） |
| 支付 | `POST /payment/order`、`GET /payment/order/{id}` | `payment_api.dart` | 已封装，收银台待接 SDK |
| 公共 | `POST /common/upload/image` | `api_client.dart#uploadImage` | `profile_page.dart` 头像 |
| 公共 | `POST /common/sms/send`、`POST /common/sms/verify` | `common_api.dart` | 已封装，登录走本地滑块验证码 |
| 公共 | `GET /common/app/version`（公开端点） | `app_version_api.dart#latest` | `app_update.dart` 冷启动 + 「我的 → 检查更新」 |

## App 更新检查（`GET /common/app/version`）

已上线（后端 `super-sales-server/docs/api/app-version.md` 是契约与发版流程的事实源）。
公开端点，冷启动时用户可能未登录，**不要**要求 Authorization；接口 404 / 超时 / 断网时
App 静默放行——更新提示永远不能把用户卡在门外。

请求：`GET /common/app/version?platform=android&versionCode=1`

响应（裸数据，按平台各存一条最新版本记录即可）：

```json
{
  "versionName": "0.2.0",
  "versionCode": 2,
  "downloadUrl": "https://pos.citykafei.com/download/kqw-0.2.0.apk",
  "releaseNotes": "修复装机提交偶发失败\n优化扫码识别",
  "forceUpdate": false,
  "minSupportedVersionCode": 1
}
```

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `versionName` | 是 | 展示用版本名 |
| `versionCode` | 是 | 整数版本号，**前端只按它比较**；与 `pubspec.yaml` 的 `+N` 一致 |
| `downloadUrl` | 否 | APK 直链；为空时 App 提示「下载地址暂不可用」 |
| `releaseNotes` | 否 | 更新说明，纯文本 |
| `forceUpdate` | 否 | true = 旧包必须更新（弹窗不可关闭） |
| `minSupportedVersionCode` | 否 | 低于它的安装包一律强更，用于紧急封禁极老版本 |

前端行为（`lib/core/app_update.dart`）：

- 冷启动首帧后异步检查，与登录态无关；`versionCode` 不高于本地 → 不打扰。
- 强更：无「稍后再说」、点遮罩和返回键都关不掉；弱更：可稍后。
- 任何请求失败（404/断网/超时）→ 静默放行，绝不把用户挡在启动页外。
- 「我的 → 检查更新」为手动入口，失败/已是最新都会给一句提示。

发版约定：**每次发布必须递增 `pubspec.yaml` 的 `version: x.y.z+N`**，并同步后端记录
（`+N` → Android versionCode）。release 包已固定使用正式 keystore 签名
（`android/key.properties` + `android/app/kqw-release.jks`，两者均被 gitignore）：
这套密钥必须离线备份，丢失后已安装用户无法覆盖升级、只能卸载重装，泄露则可被签出冒名安装包。

## 检查结论

- `flutter analyze`：**0 error / 0 warning**，剩 5 条 `dangling_library_doc_comments`（仅注释风格）。
- `flutter test`：**77 项全部通过**（含窄屏 360dp 全页面无溢出、首页/商城/推广/机器渲染、版本更新提示 10 项）。
- 登录态：access（JWT，aud=app）+ refresh（opaque，Redis 轮换）双 token；401 自动刷新重放，刷新失败才登出。
- 未接能力均在代码中显式提示而非伪造成功：支付收银台（`packages_page.dart` / `home_tab.dart`）、短信验证码（登录用本地滑块）。
- 平台公告：后端无接口，`home_tab.dart` 只留占位说明，不展示假数据。

## 与 v2.0 文档的已知差异

1. 文档 59 条路径，当前运行实例 C 端（`src/modules/app` + `src/modules/common`）按控制器装饰器计数为 64 个端点，
   另有 `admin/*` 与 `internal/*` 若干；`app/home`、`app/points`、`app/pos`、`app/task`、`app/team`、`app/payment` 等模块文档未覆盖。
2. 文档未给响应模型；字段类型以 mapper/service 为准（如 `BigInt → string`）。
3. 前端密码校验下限按后端 8 位对齐；`/mall/exchange`、`/user/me` 的响应语义按源码而非文档。
4. 文档中的 `/api` 前缀在本实例不存在。
