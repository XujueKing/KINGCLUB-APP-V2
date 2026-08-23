# 功能与页面文档目录

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

对应代码目录在文档批准后创建：

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
3. 页面与 API/Mock 契约通过评审后，才创建对应 `lib/features/` 目录。
4. 功能 README 必须链接所有页面目录；页面必须反向链接所属功能。

