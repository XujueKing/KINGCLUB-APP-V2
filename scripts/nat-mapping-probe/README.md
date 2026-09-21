# Android UDP mapping diagnostic

`NatMappingProbe.java` runs through Android `app_process`, without installing
an application or changing network settings. Compile to Java 8 bytecode, use
Android build-tools D8 to produce `classes.dex`, push it to a temporary path,
and run:

```sh
CLASSPATH=/data/local/tmp/kc-nat-mapping.dex app_process /system/bin NatMappingProbe FIRST_HOST SECOND_HOST
```

Both observers must provide IPv4 STUN on UDP 3478 and resolve to different
addresses. The same unconnected socket probes first, second, then first again.
Each transaction has at most two two-second attempts. Responses must match the
source, transaction ID, cookie and declared length. Only comparison booleans
are printed; mapped IP addresses and ports are not logged. Remove the temporary
dex after the run. DNS resolution uses the platform resolver.

`destination-dependent` with `stableFirst=true` means these two destinations
produced different mappings during this run. `same` does not establish universal
endpoint-independent behavior. Missing responses are inconclusive; this does
not classify inbound filtering or identify the exact NAT device. Shell UID
and a separate socket are used, so results are evidence about this diagnostic
flow, not packet capture of the production chat socket.

Public observer used during acceptance: `stun.cloudflare.com:3478`, documented
at https://developers.cloudflare.com/realtime/turn/ . No TURN allocation,
credentials, chat data or media is sent.

## Alternate-source-port check

After pushing the dex, run `filter_probe.py --adb PATH --serial DEVICE
--observer IPV4 --ssh ALIAS` with the authorized device and its STUN server's
SSH alias. This invokes `--filter` mode over a private subprocess pipe. Do not
run this mode directly in an interactive log: its coordination line contains
the mapped endpoint and random token. The coordinator only prints booleans.

The device contacts observer UDP 3478, holds the same socket, and waits up to
12 seconds for the random token from that observer's IP and a different port.
The server sends three 16-byte datagrams from an ephemeral port; an exact-flow
tcpdump (four-second limit, one packet, output to `/dev/null`) verifies server
egress. Then the device repeats STUN on its original socket. No listener or
firewall configuration is changed. Requires `sudo -n tcpdump` on the observer.
Remove the phone's temporary dex afterwards.

Failure to receive with successful egress and stable baseline is evidence of
failure on this alternate-source-port path. It does not locate which network
device filtered the traffic, rule out protocol filtering, or establish a full
RFC 5780 NAT classification. This still uses a separate shell-UID socket.
