# 私有表情云同步（进行中）

保持现有表情分类与格子布局。后端676提供版本化目录、677提供本人库内图片私有下载。客户端 StickerLibraryRepository 实现目录读取、版本化写入和私有图片流式下载（20MB上限、精确大小及SHA256校验）；只接受预期相对路径、不跟随重定向，不将鉴权头发往其他地址。登录变化或销毁后取消下载并拒绝迟到响应。版本冲突交给调用方处理，不盲目覆盖。

当前仅完成协议层。表情面板接入、本地图片上传映射、离线变更保存/合并、重新登录恢复及双机验收仍待完成；未上线、未安装，不算表情同步可用。已有本地表情库仍保留。

验证：两个文件 analyze 通过；5项受控测试覆盖迟到响应、冲突不重写、正常下载、损坏内容、非法下载目的地。未使用真实会员表情测试。

## 2026-09-16 导入容量校验

本机导入必须与云端契约一致：包含默认收藏在内最多20个分类，每类最多200张，合计最多500张。在复制选中图片及修改本地索引前检查，超限明确提示并保留原有库；不把容量错误提示为相册权限问题。已有超限旧库不自动裁剪或删除。验收覆盖超限拒绝和恰好达到边界的正常导入；不改变已确认的布局。

实现已完成，28项表情相关本地测试通过，包含6项容量边界页面测试（拒绝时零文件复制、索引不变、提示可见；恰好达到限制时正常保存）。尚未安装本轮改动，云端部署与双手机同步仍待验收。

## 面板接入

ChatEmojiPanel 由真实会话传入 repository，本地恢复后后台调用同步；添加/删除成功后再同步，不用网络加载页替换已有表情。StickerLibrarySync 复用加密图片上传，恢复私有图片到账号目录；cloud.json 保存已同步版本、本地快照和文件/资产映射。只有面板仍对应原快照且成功写入本地索引后才更新同步基线。同步期间新增修改不被旧响应覆盖。网络失败保留本机数据。

未完成：两端同时修改/首次迁移两端都有数据时，目前拒绝覆盖而不是自动合并，尚无冲突解决UI；丢失同步回执或写本地基线前崩溃也可能进入冲突待处理。实时通知尚未接通，以打开面板/本地编辑触发同步。云接口未部署，当前手机未安装这一批；真实双机恢复和发送未验证。

验证：4文件 analyze 通过；9项同步、导入、删除及账号隔离测试通过。同步测试采用受控云对象，不当作真实云端通过。

## 冲突交互补齐
发生双端修改时可选择稍后或保留两边并合并。确认后重新读取云端版本，用该版本写入并集；第一分类合并到单个表情，同名其他分类合并、资产ID去重，不同分类保留。提示明确另一端仍有的表情会恢复。合并超出数量上限仍拒绝提交并保留本地；并发版本再次变化仍由服务端拒绝，不强行重写。三个文件 analyze 通过，11项同步/导入/账号隔离测试通过。弹窗真实手机交互及后端同步仍未验收。

## 在线更新触发
面板监听 chat.stickers.changed 与 connection.ready，后台重新同步；同步前等待本地恢复完成，账号切换后迟到触发作废。面板销毁解除监听。尚未打开面板时仍在下次打开恢复，不在后台下载全部表情。11项现有同步/导入/账号测试及面板 analyze 通过，真实通知端到端未验证。

## 重连不打断浏览
云版本、本地快照均未变化且图片仍存在时，同步不重新写本地索引/应用面板；图片缺失仍触发恢复。同步不清空内置表情页码，避免正在浏览时页码指示被重置。8项同步测试通过，包含无变化不应用、缺失文件恢复；3文件 analyze 通过。未安装/双机验收。

## Local journal recovery

A malformed or structurally invalid cloud.json now becomes an unknown baseline instead of permanently preventing synchronization. The existing first-sync rules restore remote files when the local library is empty and require explicit keep-both resolution when both sides contain images. Invalid mappings are not reused. Disk read failures still propagate; they are not silently interpreted as a cleared library.

Validation: analyze passed; all 12 sync tests passed, including truncated/invalid records, cloud restore without writes, both-sided conflict protection, unchanged reconnect, missing-file recovery and deliberate local deletion. Earlier tests used the placeholder baseline string old; these fixtures now contain a real serialized local snapshot. This is local controlled recovery coverage, not online deployment or dual-phone acceptance. Not included in the 08:29 installed APK.
