# 登录与会员准入剩余流程实机检查

- 日期：2026-08-29
- 设备：Android `23116PN5BC`
- 包名：`com.lingmei.kingclub.v2preview`
- 构建：Flutter preview debug，本地 UI/Mock 流程

## 已接受截图

1. [启动封面](01-welcome.png)：隐私勾选、NEXT 禁用态和营业时间无遮挡。
2. [手机号登录](02-mobile-login.png)：旧版黑金登录结构、输入区和底部主按钮完整。
3. [验证码输入](03-code-entry.png)：键盘弹出后输入区保持可见。
4. [验证码就绪](04-code-ready.png)：键盘收起后 NEXT 与城市文字完整，正常界面无测试提示。
5. [实名与成年核验](05-real-name.png)：步骤、进度条、禁酒图标、输入框和人脸核验按钮完整。

## 检查结论

- 启动到实名页的主路径在目标 Android 设备上可达，未出现黑屏、裁切或返回栈中断。
- 正常用户界面未展示 Fake、Mock、真实服务或测试模式提示。
- 后续实名提交属于成年核验动作，本轮未通过自动设备控制执行；Step 2～审核结果改由 Widget 测试验证布局状态与交互。
- `00-current.png` 是进入本轮流程前捕获到的其他页面，已明确拒绝，不作为本次检查证据。

## 配套自动化

- `test/app_smoke_test.dart`：启动、旧版登录、实名、形象资料、偏好、审核通过与 App Shell 主路径。
- `test/identity_remaining_flow_test.dart`：验证码帮助/重取/错误/成功、着装音乐选择、全部审核状态。

真实短信、实名、相机/相册、上传、审核查询与准入授权仍保持 `Blocked`。
