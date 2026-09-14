#[allow(dead_code)]
mod upstream {
    include!(concat!(env!("NOVORUDP_SOURCE_ROOT"), "/crates/novovm-network/src/novorudp.rs"));
}
use upstream::{NovoRudpTransportFrameKindV0 as Kind, NovoRudpTransportFrameV0 as Frame};
fn main() {
    if std::env::args().nth(1).as_deref() == Some("udp") {
        use std::io::Write;
        let socket = std::net::UdpSocket::bind("127.0.0.1:0").unwrap();
        socket.set_read_timeout(Some(std::time::Duration::from_secs(10))).unwrap();
        println!("{}", socket.local_addr().unwrap().port());
        std::io::stdout().flush().unwrap();
        let mut buffer = [0u8; 1200];
        let (size, peer) = socket.recv_from(&mut buffer).unwrap();
        let input = Frame::decode(&buffer[..size]).unwrap();
        assert_eq!(input.kind, Kind::Data);
        let reply = Frame::new(Kind::Ack, input.session_id, input.stream_id,
            input.object_id, input.sequence, input.ack_epoch, input.payload);
        socket.send_to(&reply.encode(), peer).unwrap();
        return;
    }

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
