#[allow(dead_code)]
mod novorudp {
    include!(concat!(
        env!("NOVORUDP_SOURCE_ROOT"),
        "/crates/novovm-network/src/novorudp.rs"
    ));
}
#[allow(dead_code)]
mod product_overlay {
    include!(concat!(
        env!("NOVORUDP_SOURCE_ROOT"),
        "/crates/novovm-network/src/product_overlay.rs"
    ));
}
#[allow(dead_code)]
mod product_nat {
    include!(concat!(
        env!("NOVORUDP_SOURCE_ROOT"),
        "/crates/novovm-network/src/product_nat.rs"
    ));
}
#[allow(dead_code)]
mod product_directory {
    include!(concat!(
        env!("NOVORUDP_SOURCE_ROOT"),
        "/crates/novovm-network/src/product_directory.rs"
    ));
}
use ed25519_dalek::{Signer, SigningKey};
use novorudp::NovoRudpTransportFrameV0;
use product_nat::*;
use product_overlay::*;
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    ffi::{c_char, CString},
    sync::{Mutex, OnceLock},
};
use zeroize::Zeroize;

enum Object {
    Identity(SigningKey),
    Initiator(NodeHandshakeInitiatorV1),
    Channel(E2eSecureChannelV1),
    Sender(RepairSender),
}
struct RepairSender {
    session: [u8; 16],
    stream: u64,
    object: u64,
    expected: u64,
    state: novorudp::NovoRudpSenderState,
}
struct State {
    next: u64,
    objects: HashMap<u64, Object>,
    replay: HandshakeReplayCacheV1,
}
impl Default for State {
    fn default() -> Self {
        Self {
            next: 1,
            objects: HashMap::new(),
            replay: HandshakeReplayCacheV1::default(),
        }
    }
}
impl State {
    fn insert(&mut self, object: Object) -> Result<u64, String> {
        if self.objects.len() >= 128 || self.next >= (1u64 << 53) {
            return Err("native capacity exceeded".into());
        }
        let id = self.next;
        self.next += 1;
        self.objects.insert(id, object);
        Ok(id)
    }
}
static STATE: OnceLock<Mutex<State>> = OnceLock::new();
fn state() -> &'static Mutex<State> {
    STATE.get_or_init(|| Mutex::new(State::default()))
}
fn number(v: &Value, key: &str) -> Result<u64, String> {
    v[key].as_u64().ok_or_else(|| "invalid handle".into())
}
fn text<'a>(v: &'a Value, key: &str) -> Result<&'a str, String> {
    v[key]
        .as_str()
        .filter(|s| !s.is_empty() && s.len() <= 256)
        .ok_or_else(|| "invalid field".into())
}
fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}
fn command(v: Value) -> Result<Value, String> {
    let mut s = state().lock().map_err(|_| "native state unavailable")?;
    let id = number(&v, "handle")?;
    match text(&v, "op")? {
        "close" => {
            s.objects.remove(&id);
            Ok(json!({"closed":true}))
        }
        "public" => {
            let Some(Object::Identity(key)) = s.objects.get(&id) else {
                return Err("identity unavailable".into());
            };
            Ok(
                json!({"peerId":peer_id_from_ed25519_public_key_v1(&key.verifying_key().to_bytes())}),
            )
        }
        "bindingProof" => {
            let Some(Object::Identity(key)) = s.objects.get(&id) else {
                return Err("identity unavailable".into());
            };
            let scope: [u8; 32] =
                serde_json::from_value(v["scope"].clone()).map_err(|_| "invalid binding scope")?;
            let nonce: [u8; 32] =
                serde_json::from_value(v["nonce"].clone()).map_err(|_| "invalid binding nonce")?;
            // Narrow domain-separated proof, never a general message-signing API.
            let mut bytes = b"kingclub-device-binding-v1\0".to_vec();
            bytes.extend_from_slice(&scope);
            bytes.extend_from_slice(&nonce);
            bytes.extend_from_slice(&key.verifying_key().to_bytes());
            Ok(json!({"signature":key.sign(&bytes).to_bytes().to_vec()}))
        }
        "relayRecord" => {
            let Some(Object::Identity(key)) = s.objects.get(&id) else {
                return Err("identity unavailable".into());
            };
            let endpoints: Vec<product_directory::RelayEndpointV1> =
                serde_json::from_value(v["endpoints"].clone())
                    .map_err(|_| "invalid relay endpoints")?;
            if endpoints.is_empty() || endpoints.len() > 4 {
                return Err("relay endpoint limit".into());
            }
            let record = product_directory::sign_relay_record_v1(
                key,
                text(&v, "recordId")?,
                endpoints,
                now(),
                now() + 60000,
                v["sequence"].as_u64().ok_or("invalid sequence")?,
            )
            .map_err(|e| e.to_string())?;
            Ok(json!({"record":record}))
        }
        "validateRelay" => {
            let record: product_directory::PeerSignedRelayRecordV1 =
                serde_json::from_value(v["record"].clone()).map_err(|_| "invalid relay record")?;
            if record.relay_peer_id != text(&v, "expectedPeer")? {
                return Err("untrusted relay identity".into());
            }
            if record.endpoints.len() > 4 {
                return Err("relay endpoint limit".into());
            }
            let verified = product_directory::validate_relay_record_v1(&record, now())
                .map_err(|e| e.to_string())?;
            Ok(json!({"record":verified.record}))
        }
        "natProbe" => {
            let Some(Object::Identity(key)) = s.objects.get(&id) else {
                return Err("identity unavailable".into());
            };
            let packet = if v["targetPeer"].is_null() {
                NatDatagramV1::ObservedProbe(build_observed_endpoint_probe_v1(key, now(), 10000))
            } else {
                NatDatagramV1::PunchRequest(build_nat_punch_request_v1(
                    key,
                    text(&v, "targetPeer")?,
                    now(),
                    10000,
                ))
            };
            Ok(json!({"packet":packet}))
        }
        "natRespond" => {
            let Some(Object::Identity(key)) = s.objects.get(&id) else {
                return Err("identity unavailable".into());
            };
            let packet: NatDatagramV1 =
                serde_json::from_value(v["packet"].clone()).map_err(|_| "invalid NAT packet")?;
            let expected = text(&v, "expectedPeer")?;
            let endpoint: std::net::SocketAddr = text(&v, "observedEndpoint")?
                .parse()
                .map_err(|_| "invalid endpoint")?;
            if endpoint.port() == 0 {
                return Err("invalid endpoint".into());
            }
            let ack = match packet {
                NatDatagramV1::ObservedProbe(probe) if probe.requester_peer_id == expected => {
                    NatDatagramV1::ObservedAck(
                        handle_observed_endpoint_probe_v1(key, &probe, endpoint, now(), 10000)
                            .map_err(|e| e.to_string())?,
                    )
                }
                NatDatagramV1::PunchRequest(request) if request.source_peer_id == expected => {
                    NatDatagramV1::PunchAck(
                        handle_nat_punch_request_v1(key, &request, endpoint, now(), 10000)
                            .map_err(|e| e.to_string())?,
                    )
                }
                _ => return Err("unexpected NAT requester".into()),
            };
            Ok(json!({"packet":ack}))
        }
        "natValidate" => {
            let Some(Object::Identity(key)) = s.objects.get(&id) else {
                return Err("identity unavailable".into());
            };
            let own = peer_id_from_ed25519_public_key_v1(&key.verifying_key().to_bytes());
            let request: NatDatagramV1 =
                serde_json::from_value(v["request"].clone()).map_err(|_| "invalid NAT request")?;
            let ack: NatDatagramV1 =
                serde_json::from_value(v["packet"].clone()).map_err(|_| "invalid NAT response")?;
            let expected = text(&v, "expectedPeer")?;
            let endpoint = match (request, ack) {
                (NatDatagramV1::ObservedProbe(probe), NatDatagramV1::ObservedAck(ack))
                    if probe.requester_peer_id == own =>
                {
                    validate_observed_endpoint_ack_v1(&ack, &probe, expected, now())
                        .map_err(|e| e.to_string())?;
                    ack.observed_endpoint
                }
                (NatDatagramV1::PunchRequest(request), NatDatagramV1::PunchAck(ack))
                    if request.source_peer_id == own && request.target_peer_id == expected =>
                {
                    validate_nat_punch_ack_v1(&ack, &request, expected, now())
                        .map_err(|e| e.to_string())?;
                    ack.observed_source_endpoint
                }
                _ => return Err("NAT response scope mismatch".into()),
            };
            let parsed: std::net::SocketAddr =
                endpoint.parse().map_err(|_| "invalid observed endpoint")?;
            if parsed.port() == 0 {
                return Err("invalid observed endpoint".into());
            }
            Ok(json!({"endpoint":parsed.to_string()}))
        }
        "start" => {
            if s.objects.len() >= 128 {
                return Err("native capacity exceeded".into());
            }
            let Some(Object::Identity(key)) = s.objects.get(&id) else {
                return Err("identity unavailable".into());
            };
            let init =
                NodeHandshakeInitiatorV1::start(key, text(&v, "expectedPeer")?, now(), 30000)
                    .map_err(|e| e.to_string())?;
            let offer = init.offer().clone();
            let handle = s.insert(Object::Initiator(init))?;
            Ok(json!({"handle":handle,"offer":offer}))
        }
        "respond" => {
            if s.objects.len() >= 128 {
                return Err("native capacity exceeded".into());
            }
            let offer: NodeHandshakeOfferV1 =
                serde_json::from_value(v["offer"].clone()).map_err(|_| "invalid offer")?;
            if offer.initiator_peer_id != text(&v, "expectedPeer")? {
                return Err("untrusted peer".into());
            }
            let State {
                objects, replay, ..
            } = &mut *s;
            let Some(Object::Identity(key)) = objects.get(&id) else {
                return Err("identity unavailable".into());
            };
            let responder = NodeHandshakeResponderV1::respond(&offer, key, now(), 30000, replay)
                .map_err(|e| e.to_string())?;
            let response = responder.response().clone();
            let handle = s.insert(Object::Channel(responder.into_channel()))?;
            Ok(json!({"handle":handle,"response":response}))
        }
        "complete" => {
            let response: NodeHandshakeResponseV1 =
                serde_json::from_value(v["response"].clone()).map_err(|_| "invalid response")?;
            if !matches!(s.objects.get(&id), Some(Object::Initiator(_))) {
                return Err("handshake unavailable".into());
            }
            let Some(Object::Initiator(init)) = s.objects.remove(&id) else {
                unreachable!()
            };
            let channel = init
                .complete(&response, now(), &mut s.replay)
                .map_err(|e| e.to_string())?;
            let session = channel.session_id();
            let handle = s.insert(Object::Channel(channel))?;
            Ok(json!({"handle":handle,"sessionId":session}))
        }
        "seal" => {
            let bytes: Vec<u8> =
                serde_json::from_value(v["frame"].clone()).map_err(|_| "invalid frame")?;
            if bytes.len() > 1200 {
                return Err("frame too large".into());
            }
            let frame = NovoRudpTransportFrameV0::decode(&bytes).map_err(|e| e.to_string())?;
            let Some(Object::Channel(channel)) = s.objects.get_mut(&id) else {
                return Err("channel unavailable".into());
            };
            if frame.session_id != channel.session_id() {
                return Err("frame session mismatch".into());
            }
            let envelope = channel
                .seal_novorudp_frame(&frame)
                .map_err(|e| e.to_string())?;
            Ok(json!({"envelope":envelope}))
        }
        "sender" => {
            let Some(Object::Channel(channel)) = s.objects.get(&id) else {
                return Err("channel unavailable".into());
            };
            let expected = number(&v, "expected")?;
            if expected == 0 || expected > 1_000_000 {
                return Err("invalid fragment count".into());
            }
            let sender = RepairSender {
                session: channel.session_id(),
                stream: text(&v, "stream")?.parse().map_err(|_| "invalid stream")?,
                object: text(&v, "object")?.parse().map_err(|_| "invalid object")?,
                expected,
                state: novorudp::NovoRudpSenderState::new(),
            };
            Ok(json!({"handle":s.insert(Object::Sender(sender))?}))
        }
        "repairAck" => {
            let bytes: Vec<u8> =
                serde_json::from_value(v["frame"].clone()).map_err(|_| "invalid ack frame")?;
            if bytes.len() > 1200 {
                return Err("ack frame too large".into());
            }
            let frame = NovoRudpTransportFrameV0::decode(&bytes).map_err(|e| e.to_string())?;
            let Some(Object::Sender(sender)) = s.objects.get_mut(&id) else {
                return Err("sender unavailable".into());
            };
            if frame.kind != novorudp::NovoRudpTransportFrameKindV0::Ack
                || frame.session_id != sender.session
                || frame.stream_id != sender.stream
                || frame.object_id != sender.object
            {
                return Err("ack transfer mismatch".into());
            }
            let ack: novorudp::NovoRudpAckFrame =
                serde_json::from_slice(&frame.payload).map_err(|_| "invalid ack payload")?;
            // Validate before mutating the upstream sender state. Its normalizer
            // is a planning helper, not validation of an authenticated peer's ACK.
            if ack.header.version != 1
                || ack.header.kind != novorudp::NovoRudpFrameKind::Ack
                || ack.header.session_id != sender.session
                || ack.header.epoch != frame.ack_epoch
                || ack.header.epoch == 0
                || ack.expected_total != sender.expected
                || ack.missing_count > sender.expected
                || ack.receiver_done != (ack.missing_count == 0)
                || ack.current_window_missing_ranges.len() > 64
            {
                return Err("invalid ack scope".into());
            }
            match ack.current_window {
                None if !ack.receiver_done || !ack.current_window_missing_ranges.is_empty() => {
                    return Err("missing ack window".into())
                }
                Some(window) => {
                    if ack.receiver_done
                        || window.start > window.end_inclusive
                        || window.end_inclusive >= sender.expected
                        || window.count() > 64
                    {
                        return Err("invalid ack window".into());
                    }
                    let mut end = None;
                    for range in &ack.current_window_missing_ranges {
                        if range.start > range.end_inclusive
                            || range.start < window.start
                            || range.end_inclusive > window.end_inclusive
                            || end.is_some_and(|last| range.start <= last)
                        {
                            return Err("invalid missing ranges".into());
                        }
                        end = Some(range.end_inclusive);
                    }
                    if novorudp::missing_count(&ack.current_window_missing_ranges)
                        > ack.missing_count
                    {
                        return Err("invalid missing count".into());
                    }
                }
                None => {}
            }
            let decision = novorudp::sender_repair_decision_from_ack(
                &mut sender.state,
                &ack,
                &novorudp::NovoRudpWindowConfig::default(),
                &novorudp::NovoRudpPacingProfile::default(),
            );
            Ok(json!({"decision":decision}))
        }
        "open" => {
            let envelope: SecureNovoRudpEnvelopeV1 =
                serde_json::from_value(v["envelope"].clone()).map_err(|_| "invalid envelope")?;
            if envelope.ciphertext.len() > 1216 {
                return Err("envelope too large".into());
            }
            let Some(Object::Channel(channel)) = s.objects.get_mut(&id) else {
                return Err("channel unavailable".into());
            };
            let frame = channel
                .open_novorudp_frame(&envelope)
                .map_err(|e| e.to_string())?;
            if frame.session_id != channel.session_id() {
                return Err("frame session mismatch".into());
            }
            Ok(json!({"frame":frame.encode()}))
        }
        _ => Err("unknown native operation".into()),
    }
}

/// Caller supplies a readable 32-byte seed; neither JSON nor errors contain it.
#[no_mangle]
pub unsafe extern "C" fn kingclub_novorudp_identity(seed: *const u8, len: usize) -> u64 {
    if seed.is_null() || len != 32 {
        return 0;
    }
    std::panic::catch_unwind(|| {
        let mut copied = [0u8; 32];
        copied.copy_from_slice(std::slice::from_raw_parts(seed, len));
        let key = SigningKey::from_bytes(&copied);
        copied.zeroize();
        state()
            .lock()
            .ok()
            .and_then(|mut s| s.insert(Object::Identity(key)).ok())
            .unwrap_or(0)
    })
    .unwrap_or(0)
}
/// Input must point to len valid UTF-8 bytes. Free returned pointer exactly once.
#[no_mangle]
pub unsafe extern "C" fn kingclub_novorudp_request(input: *const u8, len: usize) -> *mut c_char {
    let result = std::panic::catch_unwind(|| {
        if input.is_null() || len == 0 || len > 16384 {
            return Err("invalid native request size".to_string());
        }
        let value = serde_json::from_slice(std::slice::from_raw_parts(input, len))
            .map_err(|_| "invalid native request".to_string())?;
        command(value)
    })
    .unwrap_or_else(|_| Err("native operation failed".into()));
    let value = match result {
        Ok(data) => json!({"ok":true,"data":data}),
        Err(error) => json!({"ok":false,"error":error}),
    };
    CString::new(value.to_string()).unwrap().into_raw()
}
#[no_mangle]
pub unsafe extern "C" fn kingclub_novorudp_free(output: *mut c_char) {
    if !output.is_null() {
        drop(CString::from_raw(output));
    }
}
