# 组件：会员头部

- 文档状态：`Approved for Development`
- 组件 ID：`HOME-C01`
- 旧版来源：`index.wxml` 顶部 `index_style`

## 内容顺序

```text
[KingClub Logo] [昵称] [性别图标] [等级 EXP:数值] [认证 V]
                [金币图标 数值] [钻石图标 数值]
                [经验进度条]
```

源码确定字段如下：

| 内容 | 旧字段/条件 | 首屏 Fake | 规则 |
|---|---|---|---|
| 品牌 Logo | `/images/logo_2.png` | 真实旧 PNG | 保持比例，不用文字重画 |
| 昵称 | `userNick` | `青铜` | 不是权限或账号 ID |
| 性别图标 | `gender==1 ? man4.png : woman4.png` | 男性图标 | 只作旧版展示复刻 |
| 等级 | `levelName` | `L-0` | 与昵称分开渲染 |
| 经验 | `vipLevel` | `50`，显示为 `EXP:50` | 不与进度百分比强绑定 |
| 认证 | `preUserInfo.isVerify` | 默认隐藏；另设已认证场景 | 条件显示 `bigV.png` |
| 金币 | `goldCoinNumber` | `50` | 使用 `gold.png` 和半透明胶囊 |
| 钻石 | `diamondNumber` | `0` | 使用 `diamond.png` 和半透明胶囊 |
| 进度 | `percent` | `50` | 0～100，超界钳制 |

## 视觉规则

- Logo 旧宽 `140rpx`；头部内容宽 `680rpx`。
- 主色 `#C9B69E`；资产胶囊背景 `#C9B69E33`。
- 性别图标约 `14rpx`，认证图标约 `16rpx`，不可用 Emoji 或字体符号替代。
- 经验条旧宽 `360rpx`、线宽 `4rpx`、圆角 `2rpx`，前景 `#C9B69E`，底色 `#C9B69E33`。
- 头部固定在首页上方；滚动后由渐变遮罩保持可读。

## 状态

- `readyUnverified`：无认证 V。
- `readyVerified`：显示认证 V。
- `longNickname`：单行截断，不挤掉等级和资产。
- `largeBalance`：数值紧凑格式或安全截断，不破坏两枚资产胶囊。
- `missingGenderPresentation`：保留图标位置并使用无性别语义占位，不能猜测用户性别。

## 验收

- [ ] 昵称与等级是两个独立内容，不能再写成一段硬编码文本。
- [ ] 性别、认证、金币、钻石全部使用旧素材。
- [ ] Fake 首屏准确显示 `青铜`、`L-0`、`EXP:50`、`50`、`0`。
- [ ] 200% 字体时信息仍可访问，允许换行/缩放但不可互相覆盖。
