# 语音转文字接入前置核查

当前ccsop-service的src与package.json未发现ASR/speech recognition/Whisper实现；App现有入口保留草稿并提示识别未接通。不能依靠Android系统识别服务存在作为交付前提，此前测试手机未发现可用识别服务。

2026-09-15测试机实测2个CPU、总内存3499MiB、available1254MiB、swap4095MiB未用、/data空余82GiB。共享业务机器不适合未经测量就添加高并发识别负载。自部署与腾讯云识别偏好已向用户询问，付费接口未开通、未调用。

候选官方实现：https://github.com/ggml-org/whisper.cpp ，HTTP接口文档：https://github.com/ggml-org/whisper.cpp/blob/master/examples/server/README.md 。其whisper-server提供/inference multipart上传、语言选择与JSON输出；--convert依赖FFmpeg。选多语言模型并指定中文，不能误用默认英语专用模型。官方样例还有/load管理入口，若采用必须仅限内部网络，App只能经现有鉴权业务API调用。当前没有安装模型或启动服务。

最终接入要求：复用账号隔离语音上传和媒体校验；识别前后验证账号和资源权限；限制时长、并发和超时；保留原录音，允许取消；结果先进入可编辑草稿而非自动发给好友；收到的语音转换仅向有权查看消息的人返回文字。静音/无语音返回明确状态，不把模型幻觉当真实内容。不得使用用户真实聊天音频做未授权对外测试，基础评估用合成音频。

后续需真实中文样本准确率、耗时、内存和错误恢复证据，才能把转文字入口标为接通。目前仍未完成。

开发机实际验证：官方v1.9.4标签927cfce34f31707e17f2bff35c349632fb9e2c3a经MSVC/CMake编译CPU CLI/server成功。官方脚本指向的多语言base模型SHA256为60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe。System.Speech慧慧生成16kHz单声道16bit中文WAV；识别输出“你好,我们明天晚上7点在门口见面。请把照片发给我。”，双线程无GPU总耗时2758.44ms、加载176.48ms。不是共享测试机基准，不是自然人/噪声准确率验收；尚未部署识别服务或接App。复现入口scripts/test-local-transcription.ps1，模型/二进制/音频仅在忽略的build目录，不提交Git。
