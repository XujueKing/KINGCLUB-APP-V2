# 权限状态与交互流程

## 统一流程

```text
用户触发能力
  -> 查询当前能力/权限状态
  -> granted: 执行能力
  -> notDetermined: 展示用途说明 -> 用户继续 -> 系统请求
  -> denied: 展示可重试说明与替代路径
  -> permanentlyDenied/systemOff: 展示设置引导
  -> restricted/unavailable: 展示不可在 App 内修复与替代路径
  -> 返回前台: 重新查询，绝不假设已授权
```

## 交互规则

- 用途说明必须对应当前动作，不使用恐吓、默认勾选或连续弹窗诱导授权。
- 用户取消说明弹窗时不触发系统权限框，并能继续使用不依赖该权限的页面。
- 同一动作进行中防重复请求；迟到结果绑定 lifecycle generation，页面销毁后不得导航。
- 系统设置跳转是用户显式动作；从设置返回只重新查询，不自动继续拍摄、扫码或上传。
- 会话失效优先于权限结果；敏感媒体选择结果在退出/切号后立即丢弃。

## Fake 状态

Mock Runtime 必须支持 `notDetermined/granted/denied/permanentlyDenied/restricted/serviceDisabled/unavailable/pluginError`，以及用户取消、前后台切换和设置后授权变化。
