# 编辑个人资料页验收

## 文档准入

- [x] 可编辑字段仅为头像、昵称、简介、城市/区域、职业、身高和四类偏好
- [x] 实名、手机号、性别、生日、余额、等级、支付密码和封面已排除
- [x] 稳定字段、optionId、校验范围与城市区域从属关系明确
- [x] 加载、编辑、媒体处理、保存、冲突、结果未知和会话失效状态明确
- [x] 幂等键、`profileVersion`、媒体 intent/commit 和未保存退出规则明确
- [x] 用户于 2026-08-25 批准 Profile Center Wireframe v1 / Edit 与字段范围

## UI Mock 验收

- [x] PROFILE-M05～M12、M16～M18 可通过字段操作和长按标题场景面板重复演示
- [x] 头像选择取消、权限拒绝、格式/上传/commit 失败分开表达且不会误报成功
- [x] 冲突不会静默覆盖，结果未知先查询收敛，快速重复保存只产生一个逻辑提交
- [x] 字段标签、字段级错误、保存进度、可滚动键盘场景和 200% 字体无溢出
- [x] 不访问真实媒体、目录或资料接口，不读取系统相册

自动化证据：`test/edit_profile_flow_test.dart` 8 项、`test/profile_row_alignment_test.dart` 3 项通过；项目全量 132 项通过，`flutter analyze` 无问题。

设备证据：[顶部与字段列表](android_edit_profile_v2.png)、[偏好与保存按钮](android_edit_profile_bottom_v2.png)、[右侧固定箭头列](android_edit_profile_aligned_v2.png)。

离线 UI Mock 已完成；真实接入仍受项目级 `UI Flow Approved` 门禁约束。
