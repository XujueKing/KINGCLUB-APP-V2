# 超级接口可信调用链

- 文档状态：In Review
- 所属业务域：foundation / API gateway
- 最后更新：2026-08-24

## 目标

在保留新服务端统一密文入口的前提下，为 KingClub V2 建立可验证的参数契约、可信用户上下文、业务权限、审计和旧接口兼容边界。

## 已确认事实

- 新入口为 `POST /supper-interface`，旧入口为 `/supper_interface`，路径不兼容。
- 新请求支持 handshake 或 API Key 两种密文模式。
- `interface` 元数据控制 executor、Routine、authPolicy、超时和启停。
- 新数据库执行器只允许白名单 Routine 名，并以单个 JSON 参数调用。
- 当前服务加载了 `interfaceKey/interfaceReturn`，但没有在执行链中使用现有校验器。
- 当前 `authPolicy` 只提供 public、handshake、session、api_key、system 粗粒度策略。
- Routine 当前只收到客户端 `params`，没有可信会话上下文。

## 当前建议

1. 先修复参数契约校验和可信上下文，再登记 KingClub 业务接口。
2. 为 KingClub 注册独立 business line 和接口命名空间。
3. 新 V2 接口使用语义文档 + 不透明编号；Flutter 只调用命名方法，不直接散落编号。
4. 旧编号通过显式 compatibility map 转换，禁止隐式复用不同语义。
5. 对象级权限必须由服务端注入用户身份并在 Routine/策略层校验。

## 不包含

- 本阶段不迁移全部 79 个静态旧接口。
- 不直接执行旧多参数 Routine。
- 不允许客户端继续提交可信 `userAccount`。

## 相关文档

- [调用流程](flow.md)
- [契约与元数据](data_and_api.md)
- [KingClub V2 第一批超级接口契约](interface_contracts_v1.md)
- [验收标准](acceptance.md)

## 开发准入

- [x] KingClub business line 与数据库边界已确认
- [x] interfaceId 策略已确认：创建全新 KingClub 接口，旧接口只参考不复用
- [ ] 可信上下文 envelope 已评审
- [ ] 权限模型已评审
- [ ] 参数契约校验方案已评审
- [ ] 状态更新为 Approved for Development
