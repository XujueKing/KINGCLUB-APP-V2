# 储物袋十款酒瓶素材测试

用户要求在 B 手机 APP 的储物袋里查看十款新酒瓶，而不是浏览器。沿用原储物袋九宫格、上下分页、翻面和液位动画；芝华士保留旧素材。

- 十款透明 PNG 派生的遮罩、描边、外框使用同一 viewBox；本次为本地素材测试，暂时随商务测试包提供。商家服务器图片上传、版本地址和缓存接入未完成，不宣称本地素材已上架。
- 仅非 release 的 commerce flavor 加 KINGCLUB_BOTTLE_MATERIAL_PREVIEW=true 启用。默认关闭；真实储物 Repository 不变。标题标明素材测试，右上测试余量调节 0–100%。
- 测试数据不混入真实成员储物；不订阅储物实时刷新；二维码不签发，不能取酒。不写数据库，不生成价格或库存。
- 酒瓶三层与液位百分比是显示示意，不能由高度反推实际毫升。
- 素材原文件留在用户提供的本地目录，本仓库仅包含此项已授权的商品展示衍生素材。

验证：12 项储物展示测试通过（360×640、393×852、翻面、九宫格两页、0/100% 余量及禁止签发测试取酒码）；4 个变更代码/测试文件静态检查通过。旧券测试从“物”修正为“券”，并明确券背面没有液位组件。

用户补充：券不做刻度；三层液位仅适用于酒，券/普通物品维持现有展示。

安装状态：commerce/profile/arm64 构建成功；已对 B 手机 TOHYQSINONBMJN6H 执行 install -r，返回 Success，并启动 com.lingmei.kingclub.commerce/com.lingmei.kingclub.MainActivity。未操作 A 手机或聊天包。

APK SHA256：EA8DED013C8A89631946D631F82ABCC2C93301316F9CADE108206847FB93F439。真机逐款视觉验收待用户查看；安装成功不代表视觉验收完成。

构建开关：KINGCLUB_BOTTLE_MATERIAL_PREVIEW=true，保留既有 API 地址及 TABLE_MANAGEMENT=true / GUEST_COUNT=false 配置。生产 release 即使误设该开关也不启用素材测试。
