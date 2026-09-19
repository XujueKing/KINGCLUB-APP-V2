# Cloud relay transfer check

The Linux standalone SuperVM relay is installed and enabled on the chat test
host, listening only on loopback. Client verification used an SSH tunnel,
the relay certificate and the expected signed peer identity. It did not use
public STUN or establish a cross-carrier mobile route.

All five `supervm_relay_file_test.dart` cases passed: candidate failover and
rebinding, lost final receipts through relay and LAN, LAN interruption with
relay recovery, and LAN interruption through `NovoRudpFileDownload`. Transfer
cases checked 262,161 bytes end to end. Relay-only transfer took about 3 seconds;
interrupted transfers took about 15 seconds. These are synthetic file checks,
not evidence of media playback or a satisfactory mobile switching delay.

The initial run used a host DLL left from September 15 and failed handshake
freshness validation. Rebuilding from the same reviewed SuperVM revision used
by Android (`579008d18db917bd2e12610a8d1f93bebbef3f51`) resolved it. Security
checks were not weakened. `scripts/test-supervm-relay.ps1` now builds the host
library before running this suite and checks the source pin and source diff,
preventing a repeat of this stale-artifact check. Its PowerShell syntax was
validated; the build and test commands passed in this session.

Public STUN ingress, a public relay route, and A/B cross-network acceptance
remain outstanding. B also needs its existing test account login. Local
and tunnel success must not be reported as completion of those items.
