// Synthetic identities only; never load member keys or media in this probe.
#[allow(dead_code)]
mod novorudp {
    include!(concat!(env!("NOVORUDP_SOURCE_ROOT"), "/crates/novovm-network/src/novorudp.rs"));
}
#[allow(dead_code)]
mod product_overlay {
    include!(concat!(env!("NOVORUDP_SOURCE_ROOT"), "/crates/novovm-network/src/product_overlay.rs"));
}
use novorudp::{NovoRudpTransportFrameKindV0 as Kind, NovoRudpTransportFrameV0 as Frame};
use product_overlay::*;
use ed25519_dalek::SigningKey;
fn main() {
    let alice = SigningKey::from_bytes(&[31; 32]);
    let bob = SigningKey::from_bytes(&[47; 32]);
    let peer = peer_id_from_ed25519_public_key_v1(&bob.verifying_key().to_bytes());
    let initiator = NodeHandshakeInitiatorV1::start(&alice, peer, 1000, 5000).unwrap();
    let mut receiver_replay = HandshakeReplayCacheV1::default();
    let responder = NodeHandshakeResponderV1::respond(initiator.offer(), &bob, 1100, 5000, &mut receiver_replay).unwrap();
    assert!(matches!(NodeHandshakeResponderV1::respond(initiator.offer(), &bob, 1100, 5000, &mut receiver_replay), Err(ProductOverlayErrorV1::HandshakeReplay)));
    let response = responder.response().clone();
    let mut receiver = responder.into_channel();
    let mut sender = initiator.complete(&response, 1200, &mut HandshakeReplayCacheV1::default()).unwrap();
    let frame = Frame::new(Kind::Data, sender.session_id(), u64::MAX, 8, 9, 10,
        b"synthetic-native-secure-roundtrip".to_vec());
    let envelope = sender.seal_novorudp_frame(&frame).unwrap();
    assert!(!envelope.ciphertext.windows(frame.payload.len()).any(|v| v == frame.payload));
    let mut tampered = envelope.clone();
    tampered.ciphertext[0] ^= 1;
    assert!(matches!(receiver.open_novorudp_frame(&tampered), Err(ProductOverlayErrorV1::SecureFrameAuthenticationFailed)));
    // A failed authentication must not consume a legitimate receive sequence.
    assert_eq!(receiver.open_novorudp_frame(&envelope).unwrap(), frame);
    assert!(matches!(receiver.open_novorudp_frame(&envelope), Err(ProductOverlayErrorV1::SecureFrameReplay)));
    let reply = receiver.seal_novorudp_frame(&frame).unwrap();
    assert_eq!(sender.open_novorudp_frame(&reply).unwrap(), frame);
    println!("NOVORUDP_NATIVE_HANDSHAKE_ENCRYPT_DECRYPT_TAMPER_REPLAY_PASSED");
}
