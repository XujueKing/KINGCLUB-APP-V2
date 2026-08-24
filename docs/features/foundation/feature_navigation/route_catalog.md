# V1 路由目录与导航动作

- 文档状态：`In Review`
- 规则：可以先冻结跨模块所需的路由语义；只有已有独立页面文档且通过准入的页面才能实现 builder/page

## 1. 路由分区

| 分区 | 会话要求 | 是否允许外部打开 | V1 恢复策略 |
|---|---|---|---|
| `bootstrap` | `unknown` | 否 | 每次冷启动固定进入 |
| `authFlow` | `anonymous` 或登录恢复中 | 否 | 仅内存，进程结束即销毁 |
| `protected` | `authenticated` | 当前不允许 | 冷启动重新鉴权后只进入已批准目标 |

## 2. 首批冻结路由语义

| RouteData 语义名 | location | 分区 | 输入 | 页面准入 | 进入/退出规则 |
|---|---|---|---|---|---|
| `AuthBootstrapRoute` | `/auth/bootstrap` | bootstrap | 无 | 已批准 | 唯一初始路由；只能由 App Root 建立，不入返回栈 |
| `MobileLoginRoute` | `/auth/mobile` | authFlow | 可选内存 `AuthEntryContext` | 已批准 | 匿名入口；不得回到 bootstrap |
| `SmsCodeRoute` | `/auth/code` | authFlow | 必需 `$extra: LoginFlowRef` | 已批准 | K101 明确成功后 replace；无合法 FlowStore 条目则回 mobile |
| `TermsConsentRoute` | `/auth/consent` | authFlow | 必需 `$extra: ConsentRouteContext` | 已批准 | readOnly 使用 push/pop；loginRecovery 使用 replace |
| `HomeRoute` | `/home` | protected | 无 | 未批准，仅冻结语义 | K104 复核后的默认目标；对应页面批准前不得实现 builder/page |

`HomeRoute` 当前只授权为导航决策中的目标语义；首页实现仍须先建立并批准独立页面目录。导航单元测试使用 fake target，不得因为出现在路由目录就创建占位页面代码。

订单、聊天、申诉、账号受限、帮助和个人中心当前既不分配 location，也不建立 RouteIntent。对应功能/页面文档与 UI 流程批准后，再通过变更评审加入本表。

## 3. 仅内存参数

```text
AuthEntryContext
  exitPolicy              V1 固定 exitApp
  noticeCategory?         稳定通用提示，不含服务端原文

LoginFlowRef
  flowId                  安全随机、不透明、仅进程内索引
  generation              防止迟到导航引用旧流程

ConsentRouteContext
  mode                    readOnly | loginRecovery
  initialDocument?        terms | privacy，仅 readOnly
  loginFlowRef?           仅 loginRecovery 必需
```

- 这些对象通过类型化 `$extra` 传递，不生成 query/path，不注册 extra codec，不参与系统恢复。
- `flowId` 即使不含手机号也按敏感流程引用处理：禁止日志、埋点、截图附件和崩溃 breadcrumbs。
- RouteData 构造成功不代表上下文可信；页面构建前必须向 FlowStore 校验 generation、状态和所有权。

## 4. RouteIntent

业务层只能表达以下类型化意图，不能调用字符串 location：

```text
bootstrap
openMobileLogin(AuthEntryContext)
openSmsCode(LoginFlowRef)
openTermsReadOnly(document)
openTermsRecovery(LoginFlowRef)
openHome
back
resetForSessionLoss(noticeCategory)
```

当前不得提前定义通用 future route。新增 RouteIntent 必须与对应功能/页面文档一起评审。

## 5. 导航动作语义

| 动作 | 用途 | 不变量 |
|---|---|---|
| `push` | 同一安全流程内临时查看并返回，例如协议 readOnly | 来源状态仍在内存且允许返回 |
| `pop(result)` | 返回已知来源 | 禁止依赖 pop 传递凭据或用户对象 |
| `replace` | mobile→code、code↔consentRecovery 等一次性步骤 | 被替换页面不得由系统返回恢复 |
| `reset` | 登录成功、注销、撤销、过期、账号不可用 | 原栈完全丢弃，只建立 home 或 mobile 安全根目标 |

页面发出 RouteIntent，由唯一 `NavigationCoordinator` 串行决策和执行。页面不得直接调用 `context.go('/...')`、拼接 URI 或持有全局 NavigatorKey。
