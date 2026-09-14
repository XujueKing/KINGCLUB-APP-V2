# Rust 主网互通样本

仅使用合成数据。设置 `NOVORUDP_SOURCE_ROOT` 为用户主网仓库绝对路径（正斜杠），设置 `CARGO_TARGET_DIR` 到本 App 的 build/novorudp-frame-fixture，然后在 App 根目录运行：

```powershell
$frames = cargo run --offline --quiet --manifest-path scripts/novorudp-frame-fixture/Cargo.toml
if ($LASTEXITCODE -ne 0) { throw 'Rust fixture generation failed' }
[IO.File]::WriteAllText((Join-Path (Get-Location) 'test/fixtures/novorudp-rust-frames.json'), ($frames -join "`n"), [Text.UTF8Encoding]::new($false))
flutter test test/novorudp_frame_test.dart
```

`main.rs`直接include主网novorudp.rs，未复制/改写Rust协议。样本基线12c1f3b，覆盖所有帧种类、高位u64和二进制载荷。本测试没有建立网络连接，不能用于宣称手机UDP/NAT/端到端加密已经接通。


实际UDP验证：构建后将`NOVORUDP_FIXTURE_EXE`指向CARGO_TARGET_DIR/debug内的可执行文件，运行`flutter test test/novorudp_datagram_link_test.dart test/novorudp_frame_test.dart`。Rust端udp模式仅绑定127.0.0.1随机端口，10秒接收超时，单个合成请求响应后退出；未设置可执行文件时Rust互通用例明确skip，不能当作通过。
