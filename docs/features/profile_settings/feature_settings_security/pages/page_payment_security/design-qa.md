# KC-P-044 Android 视觉检查

检查日期：2026-08-28
视口：Android Medium Phone 1080×2400
实现截图：`screenshots/android_payment_security_v2.png`
复刻依据：旧版 `modiffypwd.wxml/.wxss` 与已批准 `Settings Wireframe v1 / Payment PIN`

## 对照结果

- 旧版黑底、暖金标题、返回入口、纵向安全表单和主操作按钮结构已保留。
- 按已批准 V2 契约将旧版 8 位密码改为 6 位数字 PIN，未复用 MD5 或路由手机号。
- 修改、忘记、短信验证、新 PIN、二次确认和成功态均可离线操作。
- 输入遮挡，退出或进入后台清除内存输入；无真实短信和支付接口。
- 首屏卡片、双操作按钮与安全提示在 Android 实机尺寸下无裁切或溢出。
- 系统返回键回设置页；长按标题可切换所有批准的异常场景。

final result: passed
