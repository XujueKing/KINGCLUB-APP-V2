# Route recovery device build

Source: `4eb93154af76efebc023a6813e9c6cc906529d76`, built from a new clean
detached worktree. Uncommitted onboarding work in the main checkout was excluded
and left untouched. Profile ARM64 build completed; the script verified the
packaged native ELF. SuperVM native source remained pinned to
`579008d18db917bd2e12610a8d1f93bebbef3f51`.

APK SHA-256:
`c5701bba1e0ca6f20613ab1086b8b125e998e2faf389efaf260f382525a3325d`.

Both authorized test devices returned `Success` for an in-place install and
passed foreground activity verification. A displayed its signed-in home page;
B displayed the unauthenticated welcome/login entry. No application data was
cleared. The configured relay remains the existing LAN test relay; its report
showed one active connection with TLS and signed-node authentication enabled.
The new proxy endpoint is supported by this build but is not configured as the
active route while public deployment approval is pending.

This installs the receipt-driven route recovery and reviewed proxy-path changes.
It does not prove A/B message delivery, public UDP punching, or cross-carrier
fallback/recovery. B's existing test-account login and public network approval
remain required for those acceptance checks.
