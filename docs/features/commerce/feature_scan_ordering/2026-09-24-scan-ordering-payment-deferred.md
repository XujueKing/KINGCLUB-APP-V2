# 2026-09-24 扫码点单推进记录

## 本日范围

本日推进扫码点单主链路，并完成新版服务器的微信服务商支付运行配置。真实支付回调仍需在微信后台最终确认后再做小额联调；在此之前，客户端确认页保持只读，避免误创建真实订单。

## 已接通

1. 相机扫码和首页扫码共用 `ScanRoute.parse`。
2. 旧桌卡协议 `type=9` 已兼容：
   `tableld`（小写 l）、`shopld`、`tableName`；桌卡域名和路径可以变化。
3. 扫码后进入 `/commerce/ordering`，查询顺序为桌台上下文 → 商品目录。
4. 商品页继续使用旧小程序的酒水/饮料/小吃布局；真实目录的库存上限、售罄状态、四语言名称和分价格式由服务端响应决定。
5. 真实目录可以进入订单确认页。确认页保留服务端分价格式，并明确显示支付回调待最终联调；提交按钮在当前客户端包中保持禁用，避免回调地址尚未在微信后台生效时误创建真实订单。

## 公网入口核对

商业服务现在已挂到 `api.wuyexin.cn/commerce/`，公网 `/commerce/health` 返回 `kingclub-commerce / table-configuration`。登录、短信、聊天仍走现有 `test.wuyexin.cn/kingclub-v2` 超级接口路径；Nginx 的 `/commerce/` 与 `/kingclub/commerce/` 已切到支付候选商业容器，旧聊天容器未修改。

因此构建时保持登录地址不变，并显式设置商业地址：

```text
KINGCLUB_API_BASE_URL=https://test.wuyexin.cn/kingclub-v2
KINGCLUB_COMMERCE_API_BASE_URL=https://api.wuyexin.cn/commerce
```

这两个地址分工不同：登录、短信和聊天继续走现有 KingClub 超级接口；桌台、商品目录和新版商业接口走 `api.wuyexin.cn/commerce`。

## 支付服务器状态

- 克洛泽清吧门店 `V00000000001` 继续使用旧服务商模式，子商户号保持 `1705261229`，profile 为 `lingmei`。
- 新版商业容器的 `KINGCLUB_COMMERCE_PAYMENT_ENABLED=1` 已打开，旧 `lingmei` 凭证以只读方式挂载；旧 `default`、`kingclub` profile 仍未启用。
- 微信通知入口为 `https://api.wuyexin.cn/kingclub/commerce/wechat/lingmei/notify`，公网已路由到支付容器；无效签名验证返回 401，门店映射可正常加载。
- 启动参数使用商业入口 `commerce-main.js`；保留了容器规格和私有配置回滚备份。

服务器保留的 `api.shanghai-kingclub.cn/commerce/` 仍可作为商业服务备用入口，本日构建优先使用用户指定的 `api.wuyexin.cn`。

## 验证

- 桌卡解析、扫码分发、点单购物车、真实目录进入确认页、确认页支付延期和响应式布局测试通过。
- 新增回归覆盖：真实目录结算回调能够到达确认页；实时报价保留整数分，不被当作整元；支付未接入时不会创建本地假订单。
- commerce profile APK 已安装至 B 手机 `TOHYQSINONBMJN6H`，最终双地址构建 SHA-256：`C32C0DA2C7689696E94F6A03381853B4B5F79426D31D99DC11BA3DAAC7C6CF2C`。
- `api.wuyexin.cn/commerce/health`、`test.wuyexin.cn/kingclub-v2/health` 均已核对通过。
