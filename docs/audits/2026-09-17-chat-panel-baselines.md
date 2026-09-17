# Current composer panel baselines

Resolved the two legacy visual failures from the broad regression run without changing production UI. Tests now use the current plus-menu gift entry instead of the removed dedicated composer gift button. Attachment assertions verify the approved first-page order and two aligned rows, left swipe reveals file/coupon entries, and returning from gifts via plus shows the attachment panel.

New explicitly named current baselines were generated and visually inspected at 393x852. Legacy golden images remain unchanged for historical reference. Panel image precaching now happens after opening the panel, so PNG action icons are present before capture. The test font is Flutter's deterministic placeholder font: these images validate layout/assets, not Chinese typography or a real-device acceptance.

Verification: normal comparison run (without --update-goldens) passed all 9 tests across direct_chat_extensions_visual_test and chat_composer_panel_test. Dart analysis passed. All eleven failures from the earlier broad run now have targeted passing reruns; the broad suite was not rerun and the ten skipped checks remain unverified.

This validates presentation and navigation only. Gift, coin, red-packet and coupon transactions are not completed by these tests. No APK installation and no production behavior change.
