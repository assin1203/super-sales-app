# 前端 C 端接口对接清单

以运行实例 OpenAPI 与后端 mapper/service 源码为契约依据（v2.0 文档已滞后，见文末差异）。

## 约定

- 成功响应是**裸数据**，只有错误才包一层 `{code, message}`；`ApiClient` 已按此解析。
- 所有 `BigInt`（id、积分、金额）序列化为**字符串**，模型层用 `String` 保精度，需要数值时再解析。
- 后端未设 `setGlobalPrefix`，路径为根级（`/user/me`，**不是** `/api/user/me`）。
- 三套独立 JWT（`admin` / `app` / `internal`），本端只用 `app`。
- 全局 `ValidationPipe({whitelist:true, transform:true})`：DTO 未声明字段会被静默剔除，前端不要多传。
- 分页统一 `{items, total, pageNum, pageSize}`，由 `PageResult<T>` 解析。

## 接口 → 封装 → 页面

| 模块 | 端点 | 封装 | 使用位置 |
| --- | --- | --- | --- |
| 认证 | `POST /user/login` | `user_api.dart#login` | `login_page.dart` |
| 认证 | `POST /user/register` | `user_api.dart#register` | 仅 service 层保留（注册页未做） |
| 认证 | `POST /user/refresh` | `user_api.dart#refresh` | `auth_provider.dart` 静默续期 / 401 重放 |
| 认证 | `POST /user/logout` | `user_api.dart#logout` | `me_tab.dart` 退出登录 |
| 资料 | `GET /user/me` | `user_api.dart#me` | `auth_provider.dart#loadProfile` → 首页/我的/资料页 |
| 资料 | `PUT /user/profile` | `user_api.dart#updateProfile` | `profile_page.dart` 保存昵称/头像 |
| 资料 | `PUT /user/password` | `user_api.dart#changePassword` | `password_page.dart`（成功后强制重登） |
| 推广 | `GET /user/invite` | `user_api.dart#invite` | `referral_page.dart` |
| 推广 | `GET /user/invite/records` | `user_api.dart#inviteRecords` | `referral_page.dart` 下级明细 |
| 推广 | `GET /user/ancestors` | `user_api.dart#ancestors` | 已封装，暂无页面消费 |
| 积分 | `GET /user/points` | `points_api.dart#summary` | `me_tab.dart`、`mall_tab.dart` 余额 |
| 积分 | `GET /points/flows` | `points_api.dart#flows` | `points_flow_page.dart`（类型筛选 + 分页） |
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
| 机器 | `POST /pos/apply`、`POST /pos/newbie/submit` | `pos_api.dart` | `machines_page.dart` 申请与新手机器提交 |
| 任务 | `GET /tasks`、`GET /tasks/{code}`、`POST /tasks/{code}/claim` | `task_api.dart` | `task_tab.dart`、首页任务卡 |
| 团队 | `GET /team/rooms`、`GET /team/rooms/{id}`、`GET /team/rooms/{id}/members` | `team_api.dart` | `team_tab.dart`、`room_detail_page.dart` |
| 团队 | `GET /team/wait-queue` | `team_api.dart#waitQueue` | `team_tab.dart` 候补队列 |
| 首页 | `GET /home/banners` | `home_api.dart#banners` | `home_tab.dart` 轮播（空则回落本地图） |
| 支付 | `POST /payment/order`、`GET /payment/order/{id}` | `payment_api.dart` | 已封装，收银台待接 SDK |
| 公共 | `POST /common/upload/image` | `api_client.dart#uploadImage` | `profile_page.dart` 头像 |
| 公共 | `POST /common/sms/send`、`POST /common/sms/verify` | `common_api.dart` | 已封装，登录走本地滑块验证码 |

## 检查结论

- `flutter analyze`：**0 error / 0 warning**，剩 5 条 `dangling_library_doc_comments`（仅注释风格）。
- `flutter test`：**18 项全部通过**（含窄屏 360dp 全页面无溢出、首页/商城/推广/机器渲染）。
- 登录态：access（JWT，aud=app）+ refresh（opaque，Redis 轮换）双 token；401 自动刷新重放，刷新失败才登出。
- 未接能力均在代码中显式提示而非伪造成功：支付收银台（`packages_page.dart` / `home_tab.dart`）、短信验证码（登录用本地滑块）。
- 平台公告：后端无接口，`home_tab.dart` 只留占位说明，不展示假数据。

## 与 v2.0 文档的已知差异

1. 文档 59 条路径，运行实例 84 条；C 端实际 34 条，`app/home`、`app/points`、`app/pos`、`app/task`、`app/team`、`app/payment` 等模块文档未覆盖。
2. 文档未给响应模型；字段类型以 mapper/service 为准（如 `BigInt → string`）。
3. 前端密码校验下限按后端 8 位对齐；`/mall/exchange`、`/user/me` 的响应语义按源码而非文档。
4. 文档中的 `/api` 前缀在本实例不存在。
