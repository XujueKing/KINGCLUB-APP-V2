# Receipt-driven route recovery

After two consecutive acknowledgement timeouts, the file sender now gives an
optional recovery hint to the adaptive frame link. The link invalidates the
old UDP readiness proof and outstanding probe nonces, then sends a fresh probe.
Until a new authenticated probe succeeds, subsequent frames use the existing
relay. One lost receipt alone does not switch routes; an uninterrupted timeout
sequence emits only one hint. Receipt arrival resets that sequence.

This preserves the six-second idle heartbeat expiry, end-to-end authentication,
replay rejection, final digest verification, cancellation and authorization
checks. Other link implementations are unaffected. The actual peer-file sender
used by the application's media/file channel shares this logic.

Validation: 39 sender/probe/real-relay cases passed, including an 18 MiB real UDP
transfer with 3,595 injected packet drops and lost final receipt. The final LAN
test also passed after retaining its existing heartbeat-expiry assertion and
adding immediate invalidation and healthy reprobe checks. Static analysis passed.

Against the cloud relay through an SSH tunnel, interrupted 262,161-byte file
samples completed in 11.5 and 10.7 seconds, compared with approximately 15 seconds
in the preceding run. These are observed samples, not a latency guarantee or
cross-network mobile acceptance. This change has not yet been installed on A/B;
public ingress and B's test-account login remain pending.
