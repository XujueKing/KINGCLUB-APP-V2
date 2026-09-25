# 原生库优化模式与 18MB 回归

前轮 18MB 丢包重传在 90 秒内未完成，使用的库是 `build/novorudp-host/debug/kingclub_novorudp.dll`。实际安卓构建脚本 `build-novorudp-android.ps1` 使用 `cargo build --release`，即使 Flutter 是 profile 预览模式。

本轮保持 Dart 代码、测试、90 秒期限及 SuperVM 固定源码版本 579008d18db917bd2e12610a8d1f93bebbef3f51 不变，只对照原生库优化模式。

| 本机测量 | Debug 原生库 | Release 原生库 |
|---|---:|---:|
| 500 次 frame.encode | 101.7 ms | 92.5 ms |
| 500 次 channel.seal（包含 encode、工作线程及原生调用） | 1400.4 ms | 486.6 ms |
| 500 次 channel.open（包含工作线程、原生调用及 decode） | 1467.4 ms | 525.5 ms |
| 18,874,368 字节，注入丢包及最终 ACK 丢失 | 90 秒超时 | 58,638 ms 完成 |

Release 完整传输观测 25,469 个包，注入/观测丢包 3,569 个；测试验证重传后最终 ACK 再次收到、内容一致、重复运行 sender 被拒绝。没有改变算法、丢包条件或期限，也未关闭加密。上述计时为单轮本机测量，不是统计性基准；不能直接推断公网或手机吞吐。

新增 `scripts/test-novorudp-files.ps1`，默认构建 Release 原生库、核对固定上游源码、显式输出模式，并恢复调用前的环境变量。需要调试时可传 `-NativeProfile debug`；性能验收使用 release。脚本以四项文件完成交接测试验证通过；18MB Release 项单独验证通过。前轮整批的其他 76 项通过记录仍有效，本轮未宣称整批在 Release 下重新运行。

```powershell
./scripts/test-novorudp-files.ps1 -SourceRoot D:/WEB3_AI/SUPERVM-KINGCLUB-PINNED -FlutterCommand D:/SDK/flutter/bin/flutter.bat
```

结论：已找到足以解释此回归超时的构建模式差异。安卓原生库此前已经使用 Release，本轮没有给手机带来额外三倍提速，也没有解决 A/B 跨网络直连。后续手机性能验收仍须使用实际预览包并记录载体路径。
