# App Shell Mock/Fake 场景

- 文档状态：`Approved for Development`

| 场景 ID | 输入 | 预期 |
|---|---|---|
| SHELL-M01 | approved 会员首次登录 | 首页根启动，四主目的地和中央扫码可见 |
| SHELL-M02 | 切换四个 Tab 后返回 | 各分支栈和滚动状态在进程内保留 |
| SHELL-M03 | 当前消息分支在单聊详情，重按消息 | 回会话列表根；再次点击发出滚动到顶意图 |
| SHELL-M04 | 任意分支打开扫码后取消 | 返回原分支和原位置，无第五分支 |
| SHELL-M05 | 消息未读 0/1/99/120 | 无徽标、1、99、99+；语义朗读正确 |
| SHELL-M06 | 离线/恢复在线 | 全局提示出现/消失，当前分支不被重建 |
| SHELL-M07 | 前台收到 session revoked | 等待清理，销毁四分支后 reset 手机号登录 |
| SHELL-M08 | membership 变 pending/suspended | 销毁业务 Shell，进入会员审核状态页 |
| SHELL-M09 | 快速重复点 Tab/扫码 | 单一导航结果，无重复页和重复权限请求 |
| SHELL-M10 | 进程终止再启动 | 不恢复 Shell 栈；从 bootstrap 复核后进入首页根 |
| SHELL-M11 | Fake 服务端返回未知 Tab/URL | 丢弃并记录稳定分类，不改变 Shell |
| SHELL-M12 | 文字缩放 200%/窄屏 | 导航仍可识别、触控区域不缩小、无关键内容截断 |

所有场景必须使用 FakeSessionView、FakeBadgeSource、FakeConnectivity 和 FakeRouteExecutor，不访问真实服务或 SDK。
