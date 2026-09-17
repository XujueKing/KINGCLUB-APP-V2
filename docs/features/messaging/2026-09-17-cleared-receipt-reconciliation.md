# Cleared-message receipt reconciliation

Direct history merge previously skipped every received message at/below hiddenThrough before acknowledgement reconciliation. An explicit matching receipt could therefore leave a failed outgoing entry permanently visible in the durable pending queue even though the server had confirmed it and its history range was cleared.

The merge now delegates visibility to the existing acknowledgement path, which excludes messages below the monotonic local boundary while settling validated own receipts. The initial payload checks and successful persistent commit still precede queue removal. A clear boundary alone never acknowledges pending messages; explicit matching message identity/content remains required.

Evidence: the focused test failed before the fix with a nonempty pending queue. After the fix, 132 direct-history/text/media/deletion tests passed, including SQLite verification of the empty cleared range and a separate boundary-without-receipt case that preserves pending content. Two-file analysis passed. Logs: build/chat-cleared-receipt-before.log and build/chat-cleared-receipt-after.log.

No UI, server or device changes. Source postdates the built 758ab7d APK and is not phone acceptance.
