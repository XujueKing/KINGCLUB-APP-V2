# 设置与安全 Mock 场景

| ID | 场景 | 预期 |
|---|---|---|
| SETTINGS-M01 | 设置正常 | 固定菜单 |
| SETTINGS-M02 | 能力加载失败 | 固定入口仍安全可用 |
| SETTINGS-M03 | 通知关闭 | 打开 Fake 系统设置 |
| SETTINGS-M04 | 清缓存 | 不清会话/草稿 |
| SETTINGS-M05 | 退出成功 | 清理并 reset |
| SETTINGS-M06 | 退出远端未知 | 本地安全退出并提示 |
| SETTINGS-M07 | PIN 未设置 | 短信复核后设置 |
| SETTINGS-M08 | 修改 PIN 成功 | 不显示/保存 PIN |
| SETTINGS-M09 | 旧 PIN 错误 | 剩余尝试由服务端返回 |
| SETTINGS-M10 | PIN 锁定 | 禁止继续输入 |
| SETTINGS-M11 | PIN 规则不符 | 本地即时提示，服务端复核 |
| SETTINGS-M12 | PIN 设置结果未知 | 原键对账 |
| SETTINGS-M13 | 注销 preflight 可通过 | 展示影响与留存 |
| SETTINGS-M14 | 未结订单阻断 | 进入订单详情 |
| SETTINGS-M15 | 资产/退款/储物阻断 | 对应处理入口 |
| SETTINGS-M16 | 注销短信过期 | 重新获取 challenge |
| SETTINGS-M17 | 注销提交成功 | 撤销会话并 reset |
| SETTINGS-M18 | 注销结果未知 | 禁重复提交并对账 |
| SETTINGS-M19 | 法律目录正常/文档切换 | 显示版本/生效日 |
| SETTINGS-M20 | 文档离线缓存/过期 | 明确缓存状态 |
| SETTINGS-M21 | 无效 DocumentRef | 安全返回目录 |
| SETTINGS-M22 | 会话失效 | 敏感流程清理并 reset |

所有场景只用 Fake port，不接真实短信、会话、注销、K107 或系统 SDK。
