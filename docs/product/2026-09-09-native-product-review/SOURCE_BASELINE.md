# 资料基线、核验结果与缺口

## 1. 本机输入资产（已确认事实）

| 资产 | 实际位置 | 核验状态 |
|---|---|---|
| 当前 Flutter App | `D:\WEB3_AI\KINGCLUB-APP-V2` | `main / 84e55bc`，保留此前未提交修复与本轮文档 |
| 小程序原型 | `D:\WEB3_AI\KingClub-git` | `master / 9299208`，提交标题 1.1.38；本轮检查工作区干净，不等于核验微信线上版本 |
| 用户提供的旧 Java 服务 | `D:\2026-ZHUZHOU\SERVICES\wuyexin-service\wuyexin` | 外层不是 Git；内层存在大量未提交内容与 `._pack-*.idx` 索引错误，不更改或清理 |
| 新服务 | `D:\2026-ZHUZHOU\SERVICES\ccsop-service` | `business/kingclub-v2 / d9929ff`，已有 `.gitignore` 修改，本轮不覆盖 |
| 旧库结构与数据 | `D:\2026-ZHUZHOU\物业信数据库\nuggets-结构+数据.sql` | 9,086,676,447 字节，导出头时间 `07/06/2026 14:08:03`，源版本 MySQL 5.7.27 |
| 辅助结构文件 | 同目录 `nuggets-仅结构.sql` | 4,970,220 字节；导出头时间 `07/06/2026 14:05:19`，不能因文件后改时间较新就认定 schema 已更新 |
| 群聊增量 | 同目录 `migrations/20260830_group_chat_complete.sql` | 两张新增 k_ 表、群管理接口及 Routine；只确认脚本存在，未验证生产执行 |

原始 SQL 保留原位，绝不加入 App Git 仓库。文件指纹：

- 结构与数据 SHA-256：`9d8235e17c5608246e702d1302cb2f593fbe8e4645a9fb0142e519b2a9737ad0`。
- 仅结构 SHA-256：`d5a0a1bc3b2da8474c131ec38da2b4bfb9d4ea498bd2a7d043e6e347fb13fc0c`。

## 2. 范围核对（已确认事实）

混包共 515 张表。KING CLUB 前缀表为 94 张、1484 字段；未定义外键；默认字符集 87 张 utf8、7 张 utf8mb4。结构快照还识别到 131 个 K_/k_ Routine 与 186 个目标为 k_ 表的触发器。数量来自文件定义，不代表当前生产库的精确数量。

分类根 `S232202502210097 酒吧`：

| 分类 | typeId | 快照接口数 | 当前客户端静态引用数 |
|---|---|---:|---:|
| App | `S232202502210099` | 92 | 78 |
| 服务器端使用 | `S232202502210100` | 11 | 1 |
| 群管理增量（不在旧快照） | 脚本登记 App 分类 | 3 个新增编号 | 3 |

当前 82 个静态接口编号中 79 命中快照，分类树另外补出 24 个未被静态引用的接口；它们可能由服务端、动态配置或旧版调用，不按“无前端引用”删除。

特别注意：`S231202504160682 / K_ChangeHeaderImage` 归入“服务器端使用”，但仍出现在小程序源码。因此分类适合定位业务，**不等于调用权限**。

递归 Routine 词法分析发现公共候选依赖 `g_sms`、`id_config`、`software_update`。这些不是获准迁移的 KING CLUB 业务表；Java 支付、文件、短信、搜索等还须独立查证，不能宣称只有这三项公共依赖。

## 3. 最新小程序与早期 V2 的差异

- 注册路由由历史 69 个变为 72 个：新增群成员管理、选曲、音乐详情。
- 作品发布已有本地草稿、幂等提交/结果查询、媒体合成、配乐和生命周期防竞态；这些没有因为 V2 只画了视频流就被实现。
- 资料已有媒体容错、账单分页、关系失败回滚；聊天背景/作品草稿按账号分区的经验应复用。
- 音乐和播放的近期测试结果应优先于较早文档：本轮测试含“相机不受音乐加载阻塞”等新行为，不把旧的等待配乐策略直接当最终产品要求。
- 旧版颜值分数、年龄/性别/会员门槛在表与流程中存在，但展示范围、准入规则和敏感资料处理须重新确认，不能直接当新产品默认规则。

## 4. 旧服务端来源不一致：必须先补齐

当前提供目录的 `SupperInterface.java` 对一组聊天/群接口要求 `sessionToken`；小程序 `utils/group-session.js` 只补 `userAccount`，其群聊文档明确描述“过渡版无令牌”。这是可复核的本地源码不一致，尚未访问线上验证。

当前目录的 `KingClubApi.java` 可见注册照片、支付、消息等 14 个路由，但未找到当前小程序使用的 `videoFeed / videoComments / addVideoComment / setWorkReaction / publishWork / publishStatus` 实现。旧 `SupperService.java` 仍有短 SQL `substring` 执行分支，与资料模块的后续修复记录不同。

小程序现有文档分别引用 `wuyexin-service-online` 和 `wuyexin-service-clean`，两目录在本机存在。本轮未切换或替换用户指定基线；后续需要确认线上部署提交/构建制品和这些差异源，不能直接将用户提供目录认定为正在运行的完整最新版。

旧构建文件包含明文凭据配置。文档不复制其值，后续应做专门的凭据盘点、配置外置与必要轮换；本轮不调用这些凭据、不替用户擅自轮换。

## 5. 新服务端已经具备什么

已确认代码：Node.js 24、TypeScript、Express、MySQL 8.4 目标、Redis/BullMQ/ws；001～022 migration；独立 KingClub K 命名空间；K101～K107 登录/协议/会话；统一身份内部客户端、本地投影和补偿；加密、防重放、审计、受控 Routine、附件与通知底座。

已确认代码限制：

| 编号 | 证据 | 影响 / 下阶段动作 |
|---|---|---|
| B01 | `src/super-interface/auth/auth-policy.ts`、`executors/db-procedure-executor.ts` | 通用 session 策略只检查会话，通用 Routine 执行器仅传 params；业务对象归属、角色与可信上下文不能靠加密自动获得，必须补齐并测试 |
| B02 | `src/platform/file/attachment-routes.ts` 的 optionalActor | 当前附件入口仅凭 sessionId/apiKeyId 查询凭据，没有此路由的持有密钥签名验证；接敏感媒体前须改成有签名/短期授权票据的请求，不把 ID 当秘密 |
| B03 | `src/super-interface/timeout/with-timeout.ts` | 超时通过 Promise.race 返回，不能保证数据库或外部副作用停止；写操作必须幂等、查询未知结果并有执行期限 |
| B04 | `src/business-lines/kingclub/business-line.config.ts`、默认 adapters | 支付/SMS/身份默认仍是 Mock；local-storage 和站内通知不是完整云媒体/手机离线推送方案 |
| B05 | `src/platform/websocket/` | 会话和事件传输不等于会话成员、消息持久化、离线补偿、历史检索、退群撤权都已实现 |
| B06 | `database/mysql8/018`～`022` | 主要是身份/登录，尚未提供本产品完整订单、库存、账本、群聊和内容业务迁移 |

这些是本地源码边界与风险，不是已验证的线上攻击事件。本轮仅诊断登记，未修改服务端。

## 6. 本轮验证与未验证

- 新服务：`npm run typecheck` 通过；Vitest 37 文件 / 133 项通过（单 worker，禁用加载运行环境配置，连接地址隔离到本机不可用端口；不跑真实 E2E）。
- 小程序：`node --test tests/*.test.js`，70/70 通过；不等于线上兼容或真机视觉通过。
- V2：沿用上一批同日已记录的 analyze 通过、329 项中 327 通过/2 Golden 失败和 Android 预览构建证据；本轮只有文档/盘点工具，不重复声称新做了真机验收。
- 9.09 GB 文件逐字节计算 SHA-256，结构扫描 9,869,824 行；3 个超长非接口行只保留行首供识别，未导出行值；接口目录解析无截断跳过。结构工具不是通用 SQL 解释器。
- 未运行 MySQL 导入、金额对账、迁移回滚演练、真实后端 E2E、旧 Java 构建、iOS 构建、生产容量压测、线上数据核验或逐页截图对照。
- 盘点脚本 3 项合成回归通过：结构/分类/依赖与 SHA-256、超长行内存限制、损坏元数据拒绝与敏感值不输出；另两份生成脚本通过 Node 语法检查。原始数据未复制入仓库。

## 7. 重现盘点

只读输入、脱敏结构输出保存在忽略的 `.dart_tool/product-audit/`；随后生成三份结构附件：

```powershell
node scripts/audit_legacy_assets.mjs sql 'D:\2026-ZHUZHOU\物业信数据库\nuggets-结构+数据.sql' .dart_tool/product-audit/legacy-dump.json
node scripts/audit_legacy_assets.mjs sql 'D:\2026-ZHUZHOU\物业信数据库\nuggets-仅结构.sql' .dart_tool/product-audit/legacy-schema.json
node scripts/inventory_product_sources.mjs 'D:\WEB3_AI\KingClub-git' .dart_tool/product-audit/legacy-dump.json .dart_tool/product-audit/client.json
node scripts/build_product_review_inventory.mjs .dart_tool/product-audit/legacy-dump.json .dart_tool/product-audit/legacy-schema.json .dart_tool/product-audit/client.json docs/product/2026-09-09-native-product-review/inventory
```

切换快照或小程序版本后必须重新审阅生成差异，不机械覆盖已批准的业务解释。
