# Payment Formal Flow v3 Android Evidence

- device: Xiaomi 14 Pro
- viewport: 1080 × 2400 px
- [01-ready.png](01-ready.png): formal payment-ready state reached from scan-order confirmation
- [02-success.png](02-success.png): server-confirmed success state
- result: order context and `¥3680.00` remain consistent across the handoff; normal UI contains no test terminology
- verification: payment + confirmation + app smoke tests 57/57 passed; relevant Dart analysis passed
