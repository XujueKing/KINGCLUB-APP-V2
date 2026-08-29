# 旧版欢迎封面页

- Scope ID：`KC-P-001A`
- 文档状态：`Approved for Development`
- UI 阶段：只允许 Flutter UI/Mock，不接真实协议目录或登录接口
- 旧版来源：`C:\Users\Poplar\Desktop\KingClub-app\pages\login`
- 视觉基准：用户于 2026-08-28 提供的旧版封面截图

## 页面目标

完整复刻旧版进入页：用户在粉黑色 KingClub 封面上阅读并同意协议，点击 `NEXT` 进入旧版手机号登录页。

## 视觉契约

- 背景必须使用旧版原图 `bj.jpg`，按屏幕全幅覆盖；不使用渐变、色块或合成占位图代替。
- 左上角使用旧版粉色透明 `logo_1.png`，宽度为视口的 `21.33%`，左边距约 `6.7%`，上边距按旧版 `130rpx` 比例复刻。
- 页面底部依次为协议勾选行、粉色 `NEXT` 胶囊按钮、`BUSINESS HOURS`、`20:30-04:00`。
- 背景、粉色 Logo 和大型 `King club` 装饰文字都来自原图/原素材，不用 Flutter 字体重绘。
- 微信小程序右上角宿主胶囊不属于 App UI，Flutter App 不复刻。

## 交互

- 默认未勾选，`NEXT` 使用旧版降低透明度的禁用态。
- 勾选后 `NEXT` 可点，进入 `/auth/mobile`。
- `《隐私政策》` 和 `《用户协议》` 分别打开现有本地只读协议页，返回后勾选状态保留。
- 不在本页请求短信、创建会话或展示账户状态。

## 线框

```text
[粉黑人物原图全屏背景]
[粉色 King club Logo]



[x] 我已阅读并同意《隐私政策》和《用户协议》
[                         NEXT                         ]
                    BUSINESS HOURS
                       20:30-04:00
```

## 配套文档

- [交互](interactions.md)
- [状态](states.md)
- [验收](acceptance.md)
