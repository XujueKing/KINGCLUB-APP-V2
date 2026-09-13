# 返回箭头统一

聊天共用标题栏采用注册页 KingBackButton：8×16 dp 旧箭头素材，48×48 dp 点击区域，56 dp 栏高，顶部偏移4 dp，左侧使用注册页自适应 contentWidth 定位。标题栏撑满可用宽度，避免箭头位于命中区域之外。

清理其它页面独立的 Material 返回图标及11×22旧图标，统一复用 KingBackButton。Stack 标题栏的返回位置、设置页左右留白及显式 AppBar leading 同步注册规则；部分已有 Row 内容栏仍保留原页面容器留白。

验证：flutter analyze --no-pub 通过；messaging_back_layout_test 三种宽度通过，覆盖位置、图形尺寸、点击区域和返回回调。
