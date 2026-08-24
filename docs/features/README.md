# 功能与页面文档目录

## 当前 M0 范围

- **已确认事实**：本期消费者 Flutter App 已冻结 48 个逻辑页面，完整账本见 [App 范围、页面覆盖与 UI 交付门禁](../v2/APP_SCOPE_AND_UI_DELIVERY_GATE.md)。
- 32 个本期功能均已拥有独立目录：2 个为 `Approved for Development`、5 个为 `In Review`、25 个为 `Draft`。
- 48 个页面均已拥有独立目录；现有四个登录页为 `Approved for Development`，其余 44 个页面骨架为 `Draft`。
- D1 完整群聊、D2 作品发布、D3 红包/金币转赠以及角色后台未建立本期页面目录。
- 目录存在只代表进入设计队列，不代表允许开发。

## 目录约定

每个功能和页面必须使用独立目录，禁止把多个无关功能写进同一个 Markdown 文件。

```text
docs/features/
  <domain>/
    feature_<feature_name>/
      README.md
      flow.md
      data_and_api.md
      acceptance.md
      pages/
        page_<page_name>/
          README.md
          states.md
          interactions.md
          acceptance.md
```

示例：

```text
docs/features/identity/feature_phone_login/
docs/features/identity/feature_phone_login/pages/page_login/
docs/features/identity/feature_phone_login/pages/page_verification_code/
docs/features/messaging/feature_direct_chat/
docs/features/messaging/feature_direct_chat/pages/page_chat_room/
```

只有本期 App 功能/页面总清单全部批准后，才创建对应 UI/Mock 代码目录：

```text
lib/features/identity/phone_login/
lib/features/identity/phone_login/presentation/pages/login/
lib/features/identity/phone_login/presentation/pages/verification_code/
```

## 命名规则

- 目录和文件使用小写 `snake_case`。
- 功能目录以 `feature_` 开头，页面目录以 `page_` 开头。
- 一个页面只能属于一个主功能；共享 UI 放入该领域的 `shared`，全局共享需要单独评审。
- 页面名称描述用户任务，不使用 `page1`、`new_page`、`common` 等模糊名称。

## 创建规则

1. 从 `_templates/feature/` 复制功能模板并填写。
2. 功能范围评审通过后，为清单中的每个页面复制 `_templates/page/`。
3. 页面与 API/Mock 契约通过评审后，先标记文档准入；不得单独提前创建对应 UI。
4. 本期清单内全部功能和页面文档批准后，才统一创建 `lib/features/` 并只接 Fake Repository。
5. 全部 UI Mock 流程达到项目级 `UI Flow Approved` 后，才允许连接真实超级接口、WebSocket 或 SDK。
6. 功能 README 必须链接所有页面目录；页面必须反向链接所属功能。

## 全局阶段门禁

```text
全部功能/页面文档批准
  -> 全部 UI + Mock/Fake 流程
  -> 整 App UI 验收（UI Flow Approved）
  -> 真实接口/SDK 接入
```

单个页面的 `Approved for Development` 只表示文档合格，不授权绕过全局门禁提前开发或接真实服务。

## 当前 Foundation 入口

Flutter 工程创建前的技术底座评审见 [foundation/README.md](foundation/README.md)。这些目录是跨功能能力文档，不代表 Flutter 代码已经创建。
