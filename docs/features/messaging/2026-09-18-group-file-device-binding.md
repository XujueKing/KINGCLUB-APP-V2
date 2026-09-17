# Group file device binding

Consume directory migration 125 with a separate group-file scope object.
Require matching group, message, canonical sender/recipient and both membership
epochs. Never save this lookup into offline friend identity observations.
Native handshake initiation, response and completion revalidate the exact
device public key and the original group-file scope. Direct APIs unchanged.

This foundation does not enable downloader routing. Relay offer scope binding,
runtime demultiplexing and real server/phone acceptance remain pending.

Validation: 7 native device-binding tests passed with real NovoRUDP DLL
B18317E2C587A58C45A6628FF58E86E13A9B0F2227778064FB56A8FB553DFC7C,
including group initiation/completion, responder handshake and membership
change denial. Two pure scope-validation tests passed. HTTP directory responses
are fixtures, not deployed service acceptance. No APK install or phone operation.
