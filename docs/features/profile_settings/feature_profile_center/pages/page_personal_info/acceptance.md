# 我的个人信息页验收

- [x] 用户于 2026-09-12 提供小程序视觉基准并批准进入 UI/Mock 开发。
- [x] “我的个人信息”和设置“个人信息”均进入本页，不再打开旧编辑封面页。
- [x] 标题、头像尺寸、九行顺序、分隔线、文案和值列与截图一致，右侧值和箭头使用固定列对齐。
- [x] 点击头像可选择、裁切、本地保存并在重新进入后恢复；取消或失败不覆盖原头像。
- [x] 仅会员称呼、签名、修改支付密码显示右箭头且箭头同列。
- [x] 昵称和签名可本地编辑；支付密码入口可进入并返回。
- [x] 页面返回可回实际来源页，Android 真机和 200% 字体无溢出。
- [x] 定向测试和 `flutter analyze` 通过。

设备证据：`C:\Users\Poplar\AppData\Local\Temp\kingclub_personal_fixed_v2.png`；头像系统选择器：`C:\Users\Poplar\AppData\Local\Temp\kingclub_avatar_picker.png`。自动化证据：个人信息、关于和 Shell 相关定向测试 26/26 通过；`flutter analyze` 无问题。
