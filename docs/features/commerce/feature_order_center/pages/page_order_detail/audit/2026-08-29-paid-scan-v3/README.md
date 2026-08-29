# Paid Scan Order Detail v3 Android Evidence

- device: Xiaomi 14 Pro
- viewport: 1080 × 2400 px
- [03-paid-top-final.png](03-paid-top-final.png): paid status, order/store/table, products and amount summary
- [02-paid-lower.png](02-paid-lower.png): products, `3710 / -30 / 3680` and payment-confirmed timeline
- result: payment success opens the same paid scan order; no stale V8/1156 pending state remains
- verification: order-detail + payment tests 23/23 passed; relevant Dart analysis passed
