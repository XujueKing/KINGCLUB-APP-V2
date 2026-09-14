#[allow(dead_code)]
mod upstream {
    include!(concat!(env!("NOVORUDP_SOURCE_ROOT"), "/crates/novovm-network/src/novorudp.rs"));
}
use upstream::{NovoRudpTransportFrameKindV0 as Kind, NovoRudpTransportFrameV0 as Frame};
fn main() {
    let kinds = [Kind::Data, Kind::Repair, Kind::Ack, Kind::Endpoint, Kind::Done];
    let frames: Vec<_> = kinds.into_iter().enumerate().map(|(i, kind)| {
        let frame = Frame::new(kind, [0x42; 16], u64::MAX, 0x8000000000000000,
            i as u64, 0x0102030405060708, vec![0, 1, 127, 128, 255]);
        let encoded = frame.encode();
        assert_eq!(Frame::decode(&encoded).unwrap(), frame);
        encoded
    }).collect();
    println!("{}", serde_json::to_string(&frames).unwrap());
}
