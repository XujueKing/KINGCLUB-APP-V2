# KC-P-045 Android 视觉检查

检查日期：2026-08-27
视口：Android Medium Phone 1080×2400
实现截图：`android_account_deletion.png`
复刻依据：旧版 `del_user_account.wxml/.wxss` 与已批准 `Settings Wireframe v1 / Deletion`

## 对照结果

- 旧版黑底、暖金标题、风险图标、影响清单和底部危险操作结构已保留。
- 增加已批准的资格检查、共享身份边界、短信复核与最终短语确认。
- 页面明确只注销 KingClub，物业账号、物业数据和共享身份不受影响。
- 完整流程仅产生 Fake 完成态，不清除真实会话或调用注销接口。

final result: passed
