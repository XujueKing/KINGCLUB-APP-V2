"""Probe the actual SUPERVM signed NAT runtime; no account or private key input."""
import argparse
import ctypes
import json
import secrets
import socket
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--library', required=True)
    parser.add_argument('--host', required=True)
    parser.add_argument('--peer-id', required=True)
    parser.add_argument('--observer-port', type=int, default=45170)
    parser.add_argument('--punch-port', type=int, default=45171)
    args = parser.parse_args()
    lib = ctypes.CDLL(args.library)
    lib.kingclub_novorudp_identity.argtypes = [ctypes.POINTER(ctypes.c_ubyte), ctypes.c_size_t]
    lib.kingclub_novorudp_identity.restype = ctypes.c_uint64
    lib.kingclub_novorudp_request.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
    lib.kingclub_novorudp_request.restype = ctypes.c_void_p
    lib.kingclub_novorudp_free.argtypes = [ctypes.c_void_p]
    seed = secrets.token_bytes(32)
    handle = lib.kingclub_novorudp_identity((ctypes.c_ubyte * 32).from_buffer_copy(seed), 32)
    if not handle:
        raise RuntimeError('Native test identity failed')

    def call(op, **values):
        wire = json.dumps({'op': op, 'handle': handle, **values}).encode()
        pointer = lib.kingclub_novorudp_request(wire, len(wire))
        try:
            response = json.loads(ctypes.string_at(pointer))
        finally:
            lib.kingclub_novorudp_free(pointer)
        if not response['ok']:
            raise RuntimeError(response['error'])
        return response['data']

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
            udp.bind(('0.0.0.0', 0))
            udp.settimeout(0.5)
            results = []
            for punch, port in [(False, args.observer_port), (True, args.punch_port)]:
                request = call('natProbe', targetPeer=args.peer_id if punch else None)['packet']
                deadline = time.monotonic() + 5
                endpoint = None
                while time.monotonic() < deadline:
                    udp.sendto(json.dumps(request).encode(), (args.host, port))
                    try:
                        wire, source = udp.recvfrom(4096)
                    except socket.timeout:
                        continue
                    if source != (args.host, port):
                        continue
                    ack = json.loads(wire)
                    try:
                        endpoint = call('natValidate', request=request, packet=ack, expectedPeer=args.peer_id)['endpoint']
                    except RuntimeError:
                        continue
                    tampered = json.loads(json.dumps(ack))
                    tampered['body']['signature'][0] ^= 1
                    try:
                        call('natValidate', request=request, packet=tampered, expectedPeer=args.peer_id)
                    except RuntimeError:
                        pass
                    else:
                        raise AssertionError('Tampered acknowledgement accepted')
                    break
                if endpoint is None:
                    raise TimeoutError('SUPERVM signed NAT service did not respond')
                results.append({'mode': 'punch' if punch else 'observer', 'verified': True,
                                'observedEndpoint': endpoint, 'tamperRejected': True})
            print(json.dumps({'results': results, 'scope': 'computer-to-SUPERVM-network-runtime'}, indent=2))
    finally:
        call('close')


if __name__ == '__main__':
    main()
