# 编辑个人资料页验收

## 文档准入

- [x] 可编辑字段仅为封面、昵称、简介、城市/区域、职业、身高和四类偏好；头像本期固定为空白
- [x] 实名、手机号、性别、生日、余额、等级和支付密码已排除；封面按用户最新决定纳入
- [x] 稳定字段、optionId、校验范围与城市区域从属关系明确
- [x] 加载、编辑、媒体处理、保存、冲突、结果未知和会话失效状态明确
- [x] 幂等键、`profileVersion`、媒体 intent/commit 和未保存退出规则明确
- [x] 用户于 2026-08-25 批准 Profile Center Wireframe v1 / Edit 与字段范围

## UI Mock 验收

- [x] PROFILE-M05～M12、M16～M18 可通过字段操作和长按标题场景面板重复演示
- [x] 空白头像无交互，不误导用户进入未交付的头像流程
- [x] 冲突不会静默覆盖，结果未知先查询收敛，快速重复保存只产生一个逻辑提交
- [x] 字段标签、字段级错误、保存进度、可滚动键盘场景和 200% 字体无溢出
- [x] 不访问真实媒体、目录或资料接口，不读取系统相册
- [x] 正常编辑、放弃、冲突和结果确认路径使用正式用户文案，不展示 Fake、Mock 或服务器未接入提示

自动化证据：`test/edit_profile_flow_test.dart` 8 项、`test/profile_row_alignment_test.dart` 3 项通过；项目全量 132 项通过，`flutter analyze` 无问题。

设备证据：[顶部与字段列表](android_edit_profile_v2.png)、[偏好与保存按钮](android_edit_profile_bottom_v2.png)、[右侧固定箭头列](android_edit_profile_aligned_v2.png)。

离线 UI Mock 已完成；真实接入仍受项目级 `UI Flow Approved` 门禁约束。

## 2026-08-29 黑金与封面变更验收

- [x] 文档先更新后开发；此前“封面不可编辑”的限制已撤销
- [x] 编辑主页及全部弹窗、选择器、输入框、按钮和选中态无粉色像素主题
- [x] 顶部显示当前封面预览与“更换封面”入口
- [x] 封面选择器提供三张本地 Mock 封面，香槟金标识当前选择
- [x] 未保存返回会提示放弃，保存后“我的”主页立即显示新封面
- [x] 不访问真实相册、上传接口或系统媒体权限
- [x] Android 真机、Widget 测试和 `flutter analyze` 通过

验收证据：[`audit/2026-08-29-black-gold-cover/README.md`](audit/2026-08-29-black-gold-cover/README.md)

## 2026-08-29 紧凑入口与系统相册

- [x] “更换封面”胶囊明显小于上一版且不遮挡封面主体
- [x] 点击入口可打开 Android 系统相册并选择一张图片
- [x] 选择成功后立即预览，保存后“我的”主页显示同一张图片
- [x] 取消或选择失败时保留原封面与其他资料草稿
- [x] 本轮无相机、裁剪、上传和真实资料接口调用
- [x] Widget 测试、`flutter analyze`、Android 构建与真机流程通过

## 2026-08-29 封面调整与持久化

- [x] 相册选图后进入与主页头图同宽高比的黑金调整页
- [x] 图片可拖动、缩放，确认后预览调整结果
- [x] 取消相册或取消调整均不产生封面草稿
- [x] 保存后封面写入应用私有目录，重新创建主页时自动加载
- [x] 头像保持空白且不可点击
- [x] 不上传服务器、不调用资料接口

自动化证据：`test/edit_profile_flow_test.dart`、`test/profile_cover_persistence_test.dart`、首页 golden 与项目全量 293 项测试通过；`flutter analyze` 无问题。Android arm64 真机完成系统相册、位置调整、生成预览和私有目录落盘验证。

真机证据：[`audit/2026-08-29-cover-adjust/README.md`](audit/2026-08-29-cover-adjust/README.md)

验收证据：[`audit/2026-08-29-gallery-picker/README.md`](audit/2026-08-29-gallery-picker/README.md)
