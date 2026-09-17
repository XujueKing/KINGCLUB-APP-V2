# Chat transaction entry audit — 2026-09-17

This is an implementation dependency audit, not delivery of transaction features. Ordinary chat remains free. No balances, sessions, services or legacy source files were changed.

## Verified current sources

- Native direct_chat_page.dart gates real coin/red-packet/gift actions through _requiresRealMedia; coupon sharing explicitly remains unavailable. Text, image, video, file, voice and location forwarding already share ForwardTextPage and their existing real send paths.
- Legacy pages/send-goldCoin/send-goldCoin.js invokes S231202505010705 with conversation, recipient and amount. It relies on local conversation data and client-side balance checking. Its input handler permits decimal characters; this is not proof that fractional coins are valid.
- Legacy pages/send-redpacket/send-redpacket.js caps the UI at 200.00, offers wallet/WeChat payment, populates an order, and submits to the payment flow. It computes experience and credit rewards client-side. This UI does not establish server claim/refund rules.
- Legacy pages/chat/chat.js invokes S231202505170722 for gifts with giftId, quantity and client price after a 300 ms tap aggregation. Server must price gifts from an authoritative catalogue rather than trust this client price.
- Current service database/mysql8/033_kingclub_profile.sql has cashBalance decimal(18,2) and goldCoin bigint unsigned in kingclubProfileAssets. The searched src/kingclub code exposes balances and registration rewards; no coin-transfer/red-packet/gift transaction service was found there. No payment-password implementation was found in the searched service TypeScript sources.

## Work needed before connecting the entries

Use server-authenticated sender identity, validate recipient and conversation permission, and persist an idempotent transaction ID. Coin amounts must match the integer storage contract; currency arithmetic must use exact minor units. The debit, credit/escrow, ledger entries and corresponding message must commit atomically. Repeated callbacks and client retries must return the existing transaction rather than charge again. Gifts require a server price snapshot. Red packets require explicit claim ownership, expiry/refund and competing claim handling. Payment credentials must not enter messages or generic chat outbox payloads.

These are implementation requirements, not assertions that a new ledger or payment API exists. Existing UI is unchanged. No production funds may be used as test fixtures; isolated synthetic balances suffice for development.

The user was asked whether to retain legacy business rules or change scope. Still unverified: authoritative legacy routines, red-packet claim/refund timing, fees, payment-password requirements, gift revenue allocation and catalogue ownership alongside the concurrent commerce work. Do not invent these policies from the old UI or implement duplicate commerce accounting before checking that integration boundary.
