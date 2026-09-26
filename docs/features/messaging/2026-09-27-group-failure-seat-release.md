# 群媒体失败主动释放席位

群媒体 open 或运行中回调失败，原 GroupCallSession 只 close 本机媒体和控制器，未发 leave，服务端需等待席位到期。修正为复用幂等 hangUp：先停止本机采集，再等未完成的 enter 收敛，发送 leave/decline，最终关闭控制器。

enter 的 catch 不等待 hangUp，避免 hangUp 等 enter、enter 又等 hangUp 的循环等待。异步清理失败交给已有 onError，不形成未处理异常；重复媒体错误不重复退出。登录失效和被动服务端结束仍沿用 close，不跨账号发送命令。

测试覆盖启动超时主动 leave 且无死锁、运行错误与 native close 失败仍 leave、重复错误只退出一次；结合已有待完成 join/挂断竞争和媒体清理测试共 34 项通过。此为代码及自动化证据，尚未代替双机实测，也尚未安装到手机。
