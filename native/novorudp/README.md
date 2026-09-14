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

未接会员公钥目录、撤销/恢复、安全存储、Dart生命周期、UDP安全信封和自动切换。不能把原生接口完成当作KINGCLUB聊天已端到端加密。
