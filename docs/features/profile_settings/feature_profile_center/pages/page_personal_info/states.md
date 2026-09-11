# 我的个人信息页状态

- `ready`：当前本地头像和九行固定 Mock 资料完整显示。
- `pickingAvatar`：等待系统相册返回，不重复打开选择器。
- `croppingAvatar`：方形裁切预览，可缩放/移动并确认或取消。
- `avatarSaveError`：保留原头像并显示非阻断提示。
- `editingNickname`：会员称呼编辑弹窗。
- `editingSignature`：签名编辑弹窗。
- `sessionInvalid`：清理临时编辑值并请求全局重新认证。

所有只读字段在正常态始终存在；200% 字体和小屏使用纵向滚动，不允许截断返回键或支付密码入口。
