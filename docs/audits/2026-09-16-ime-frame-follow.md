# Chat IME frame following

The composer previously interpolated an already changing keyboard inset over
200 ms. Each platform update retargeted that animation, causing the composer
and message viewport to trail the keyboard. Only custom panel height is now
interpolated; the current keyboard inset is applied directly in the same layout.
Keyboard and custom panel heights still replace, rather than add to, one another.

The first outgoing message in an empty conversation now receives the existing
bottom-entry animation. Its text keeps its final dimensions during entry.

Validation: 8 widget tests passed across chat_composer_panel_test and
direct_chat_outgoing_scroll_test. The tests check both opening and closing IME
frames without settling, panel replacement, stable latest-message anchoring,
and first-message upward movement with unchanged text dimensions. Analyzer
reported no issues for the changed conversation page.

ADB listed no devices during this change. This patch has not been installed or
visually accepted on A/B. Widget checks do not establish real-device smoothness
or prove that the reported ghosting is resolved.
