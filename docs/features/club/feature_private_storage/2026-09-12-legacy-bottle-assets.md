# 旧酒瓶素材查阅结果

2026-09-12，只读核对旧小程序、旧服务器素材目录和旧k_goods商品目录，未修改旧库或App。

| 商品 | 商品键 | 旧小程序图片 | 轮廓定义 |
|---|---|---|---|
| 轩尼诗XO | K23500000001 | images/HennessyXO.png、HennessyXO_mini.png | app.wxss:434起，BJ/A/B齐全 |
| 绝对伏特加 | K23500000002 | images/vodka.png、vodka_mini.png | app.wxss:448起，BJ/A/B齐全 |
| 芝华士12年 | K23500000003 | images/CHIVAS12.png、CHIVAS12_mini.png | app.wxss:460起，BJ/A/B齐全 |
| 轩尼诗VSOP | K23500000007 | images/HennessyVSOP.png、HennessyVSOP_mini.png | app.wxss:473起，BJ/A/B齐全 |

- 四款本地原图均431×679 PNG；XO缩略图152×240。轮廓使用内嵌SVG mask：BJ为背景/阴影外形，A瓶身，B液体遮罩。pages/index/index.wxss:815起配置各商品独立尺寸，:858起为公共液面动画。
- 旧服务器/home/ops/prod/files/wyx_files/micApp/kingclub/images下存在vodka.png(38422字节)、CHIVAS12.png(62629)、HennessyVSOP.png(56198)。
- 旧服务器/home/ops/prod/files/wyx_files/kingClub/images/HennessyXO.svg存在；viewBox=0 0 400.68 637.61，单path，其d属性与旧小程序W_K23500000001_A完全一致。
- 对旧wyx_files树的SVG搜索仅找到上述XO.svg；按常见酒款英文名称在旧文件树搜索未找到更多命名瓶图。不排除未关联的随机文件名图片，不能据此认定所有磁盘均无其它酒图。
- 旧k_goods查阅45条非删除商品记录：仅上述4款有appImage/iconImage映射；XO映射本地/images/HennessyXO.png，其余3款映射远程地址；svgImage列均为空。其它商品不能从商品记录确认现成瓶图。
- 新版assets/legacy/storage已内置伏特加、芝华士12年、轩尼诗VSOP图片和A/B SVG。XO图片及轮廓尚未接入新版；可直接提取复用，无需重画。此次只查阅，不新增库存或商品。

## 本机轮廓错配修正

用户指出当前芝华士轮廓为XO、轩尼诗VSOP为芝华士。逐path核对确认错误。已从旧app.wxss重新提取：chivas-A/B取K23500000003，hennessy-A/B取K23500000007；vodka-A/B与K23500000002一致，保持字节不变。酒款PNG、库存、剩余百分比及波纹逻辑均未修改。
