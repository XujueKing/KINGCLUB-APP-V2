# 可信中继测试包配置

`scripts/build-chat-preview.ps1` 新增可选参数 `RelayUrl`、`RelayPeer`、`RelayCertificatePath`。不传参时保持原来的服务端预览包；指定中继时必须同时提供 WSS `/novovm` 地址和 `novovm-ed25519:` 公钥标识，不能与 SkipNovoRudp 同用。

公网受信证书可省略 RelayCertificatePath；本地私有测试节点可指定公开 PEM 证书，脚本转换为编译参数 `KINGCLUB_NOVORUDP_RELAY_CA_BASE64`。不得传入私钥。证书只用于该中继连接的独立 SecurityContext，不安装到系统证书库，不关闭主机名或有效期校验；NovoRUDP 的固定节点公钥认证仍然执行。

运行时使用真实证书解析器验证证书内容；无效内容会使中继初始化失败，普通 CCSOP 聊天仍是保留路径。修改节点地址时须确保该地址包含在证书 SAN 中，手机也必须能访问该地址；电脑回环地址不能作为手机节点地址。

验证：3 项证书输入测试及 2 项真实 SUPERVM WSS 运行测试通过，真实连接使用与 App 相同的编译证书解析函数；4 文件静态分析无问题。真实 WSS 测试运行在电脑，不是 Android 证书兼容性验收。节点私钥、证书、真实地址未纳入 Git。
