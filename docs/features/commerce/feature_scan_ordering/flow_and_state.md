# 扫码点单流程与状态

```text
安全扫码 -> 验证 OrderingContextRef -> 商品/购物车
        -> 请求 QuoteRef -> 点单确认
        -> 创建订单（幂等） -> PaymentIntentRef -> 支付处理
```

## 购物车状态

`loadingCatalog -> browsing <-> editingCart -> quoting -> quoteReady`

异常分支：`invalidContext`、`venueClosed`、`tableUnavailable`、`catalogError`、`offline`、`sessionInvalid`。

## 报价与创建状态

`loadingQuote -> ready -> submitting -> orderCreated`

- `quoteChanged`：展示旧/新金额或失效商品，用户确认后生成新 QuoteRef。
- `quoteExpired`：禁止提交，重取报价。
- `resultUnknown`：用原 IdempotencyKey 查询创建结果，不重复创建。
- `soldOut/limitExceeded`：回购物车定位问题项。

返回确认页不得恢复已过期报价；订单创建成功后返回键只能去订单详情或订单中心，不能再次提交。
