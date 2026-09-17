# A 聊天键盘真机帧采样

设备 A（PCLM50，1080×2400，60 Hz），已安装 Profile 预览 2cab30c。进入既有 A/B 会话，空输入框，连续三次点击输入框展开键盘、系统返回键收起，每段等待 900 ms；未输入或发送任何消息，B 未操作。

通过当前应用 Dart VM Service 采集 Dart/Embedder/GC 时间线。采样后恢复原记录流并移除临时 ADB 端口转发。原始时间线、汇总存放本机忽略目录 build/chat-keyboard-timeline.json、build/chat-keyboard-frame-summary.json；不提交接口访问地址或私人时间线。

| 事件阶段 | 样本数 | 中位数 ms | P95 ms | 最大 ms |
|---|---:|---:|---:|---:|
| Flutter Frame 异步事件 | 225 | 4.36 | 6.37 | 13.46 |
| LAYOUT 同步事件 | 225 | 2.83 | 4.11 | 10.20 |
| GPURasterizer::Draw 同步事件 | 225 | 5.44 | 7.11 | 16.89 |

Flutter Frame 事件均未超过 16.67 ms；光栅绘制一项超过 16.7 ms。同步事件按线程栈配对，异步 Frame 按进程/id 配对；不能把并行阶段相加，也不能把这些事件直接当成屏幕端到端延迟或 Android 整机掉帧率。

结论：本次已热身会话键盘切换没有持续的 Flutter UI 线程超预算证据；不等于用户主观顺滑度通过。尚未覆盖首次打开键盘、发/收消息并发、长历史、B 或系统 IME/合成器端到端时序。下一步应关注这些场景和实际位移连续性，不凭此结果继续随意调动画时长。

结束时输入框为空，键盘收起，应用保留在会话页面。

## 冷启动后首次键盘切换补测

A 当前预览 26aa51c。先确认位于历史上下文且无输入框，再强制结束应用并冷启动，启动助手第一次确认稳定前台。从消息列表进入既有 A/B 会话；输入框为空且未聚焦。基于本次 UI bounds [144,2129][815,2172] 点击中心附近 (479,2150)，等待 900ms，再系统返回收起、等待 900ms。没有输入、发送或删除消息，B 未操作。采样为这次应用冷启动后的第一次键盘切换，不代表系统输入法进程也被冷启动。

使用当前进程 VM Service 采集 Dart/Embedder/GC，finally 恢复原流并移除新建端口转发。私有数据位于 build/chat-cold-keyboard-timeline.json、build/chat-cold-keyboard-summary.json。

| 阶段 | 样本 | P50 ms | P95 ms | 最大 ms | 超过 16.67ms |
|---|---:|---:|---:|---:|---:|
| Flutter Frame | 81 | 3.796 | 5.407 | 10.089 | 0 |
| LAYOUT | 81 | 2.408 | 3.587 | 7.945 | 0 |
| GPURasterizer::Draw | 81 | 5.381 | 9.757 | 22.637 | 2 |

两个较慢的光栅事件分别包含 SurfaceFrame::Submit 22.245ms 和 18.615ms，占对应 22.637ms/18.938ms 的大部分。证据提示下一步应关注画面提交/呈现及系统输入法合成时序；不能简单归因为气泡重建、GPU 算力不足或直接继续改布局动画时长。时间线也有并发 GC 事件，不能把并行时长相加当作掉帧证明。没有测量完整触摸至屏幕延迟，主观顺滑度仍未验收。

结束时输入仍为空、bounds 回到采样前位置；系统 mInputShown=false。A 留在原会话，未改业务状态。

## 系统呈现时间补充

检查当前 Android 源码：Activity 使用标准 FlutterActivity、hardwareAccelerated=true、adjustResize，没有自定义重复 IME 动画回调；聊天页只为自定义面板插值，键盘高度直接读取局部 MediaQuery。没有证据支持再次添加/调整一套键盘缓动。

A 系统当前显示模式为 1080×2400、60Hz，SurfaceFlinger 记录刷新周期 16666666ns。清除呈现统计后，在空输入框上执行一次展开/收起，各等待 900ms，读取应用对应 BLAST SurfaceView 的 latency 数据。三列含义按 [AOSP FrameTracker::dumpStats](https://android.googlesource.com/platform/frameworks/native/+/cdb6b16dec3a541b455be99d075004cb2f0a0cd7/services/surfaceflinger/FrameTracker.cpp) 的 desiredPresentTime、actualPresentTime、frameReadyTime 顺序解释，忽略零值和未完成时间戳。

展开阶段 45 条有效呈现，actual-desired 差值中位 21.855ms、最大 32.889ms；收起读取包含前阶段，按前阶段最后实际呈现时间去重后新增 38 条，中位 23.107ms、最大 41.775ms。该差值不是触摸延迟或 Flutter 帧计算耗时。记录包含动画结束后的空闲/光标绘制，没有对应的逐帧动画区间，因此不把大于一刷新周期的呈现间隔直接统计成丢帧率，也不能据此单独判定系统输入法有故障。

原始统计在忽略目录 build/kc-ime-open-present.txt、kc-ime-close-present.txt。结束时输入框未修改、mInputShown=false，B 未操作。当前缺口是应用与 IME 的同一时间轴位移/帧截止时间关联，现有证据不足以对动画再作猜测性改动。
