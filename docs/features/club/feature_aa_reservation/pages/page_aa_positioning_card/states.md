# AA 已选座定位凭证页状态

| 状态 | UI |
|---|---|
| `ready` | 完整定位卡、席位矩阵和动态二维码 |
| `checkedIn` | 二维码遮盖并显示旧版“已入场”印章 |
| `notYetAvailable` | 二维码区域显示开放时间，不暴露码值 |
| `ended` | 凭证只读、二维码失效 |
| `revoked` | 凭证撤销，提示联系工作人员 |
| `offline` | 不生成备用二维码，保留订单文字投影 |
| `privacyCovered` | App 进入后台时遮盖二维码，恢复前签发新 Fake token |

本次截图复刻默认展示 `ready`。
