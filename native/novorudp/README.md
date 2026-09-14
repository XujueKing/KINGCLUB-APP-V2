# KINGCLUB NovoRUDP 原生安全层

直接include用户SUPERVM的novorudp.rs和product_overlay.rs，基线12c1f3b。构建设置NOVORUDP_SOURCE_ROOT为主网绝对根目录（正斜杠）；CARGO_TARGET_DIR设在App build目录。

```text
cargo build --offline --manifest-path native/novorudp/Cargo.toml
cargo build --offline --release --target aarch64-linux-android --manifest-path native/novorudp/Cargo.toml
```

Android需安装aarch64-linux-android Rust标准库，并将CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER指向NDK aarch64-linux-android26-clang。当前产物是独立cdylib，尚未打包入App。

C ABI：identity接受可读32字节种子及长度，返回非零身份handle；request接受可读UTF8 JSON指针和长度，返回JSON C字符串；free只接受本库返回的指针且必须恰好调用一次。无效指针/重复free不属于受支持调用；由Dart封装保证所有权。seed调用前后由调用方清零自己的临时缓冲，不放进JSON，源私钥需另接系统安全存储。

操作public/start/respond/complete/seal/open/close。start与respond必须传可信expectedPeer；respond核对发起方绑定，complete成功或失败均消耗已取出的握手handle。每个handle独立释放，关闭身份不会隐式关闭其子通道，App会话层须跟踪并释放全部对象。close幂等；其余操作拒绝错误类型/失效handle。帧session必须和协商session一致。全局对象128个、JSON输入16384字节、裸帧1200字节上限。密钥由主网Rust类型管理，不经JSON输出。

主机真实C ABI验证：设置NOVORUDP_NATIVE_LIBRARY指向生成动态库，执行python native/novorudp/test_bridge.py。Android probe_loader.c通过NDK编译，运行时参数为共享库路径，验证动态加载、身份导入、公开peer读取、关闭后拒绝与结果释放。仅使用合成种子，不读会员资料或发网络数据；运行后删除设备临时文件。

Dart生命周期、设备身份安全存储代码及KINGCLUB安全UDP载体已接在App源码，仍未启用真实聊天。会员公钥目录、撤销/恢复和自动切换未完成。不能把原生接口完成当作KINGCLUB聊天已端到端加密。


sender以channel handle创建传输规划器（stream/object为u64十进制字符串，expected为1..1000000分片数），repairAck以sender handle接收已认证ACK裸帧并调用上游缺片规划。ACK作用域和范围先校验再变更状态。sender通过close释放；Dart负责随channel/session关闭子对象。返回规划不代表实际重传或持久投递，完整可靠传输调度仍待接入。


bindingProof以identity handle和32字节scope/nonce数组生成固定kingclub-device-binding-v1零结尾域签名，消息还包含本机公钥。仅供受信服务端设备登记挑战；不是通用签名接口。签名有效不等于挑战已一次性消费或会员公钥已登记。


Windows ARM64预览打包使用scripts/build-novorudp-android.ps1（默认同级SUPERVM，NDK28.2/API24）及scripts/build-chat-preview.ps1。构建固定上游commit并检查源未改；不提交生成的.so。Gradle仅在KINGCLUB_NOVORUDP_JNI_DIR显式提供时打入库；预览脚本自动设置/恢复并检查APK。其他ABI/iOS及运行入口仍待实现。
