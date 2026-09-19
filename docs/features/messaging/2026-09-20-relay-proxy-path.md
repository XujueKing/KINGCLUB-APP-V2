# Relay reverse-proxy path

The application and preview build script now accept exactly two relay paths:
`/novovm` for a native relay listener and `/supervm/relay` for the prepared TLS
reverse proxy. Both still require WSS, an expected Ed25519 relay identity, and
URLs without credentials, query parameters or fragments. Unrelated paths remain
rejected. This prevents a future proxy deployment from being rejected locally
before connection.

Eight endpoint checks and static analysis passed. The five real native relay
transfer cases also passed through a temporary, loopback-only Nginx TLS proxy
on the cloud host, accessed via SSH forwarding. Nginx verified the upstream
certificate; the client verified the proxy certificate and signed relay identity.
The test wrapper itself ran successfully, including its pinned native rebuild;
Windows PowerShell native stderr handling was corrected to use process exit
codes instead of interpreting Cargo's success output as failure.

This did not enable the staged public route or change the existing Nginx service.
Public access still awaits approval. This check does not establish cross-carrier
UDP connectivity or A/B media delivery.
