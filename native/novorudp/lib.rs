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
use ed25519_dalek::SigningKey;
use novorudp::NovoRudpTransportFrameV0;
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
