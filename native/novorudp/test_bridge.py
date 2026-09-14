"""Exercise the real C ABI with synthetic identities; no member data/network."""
import ctypes
import hashlib
import json
import os
import struct
import unittest

lib = ctypes.CDLL(os.environ['NOVORUDP_NATIVE_LIBRARY'])
lib.kingclub_novorudp_identity.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
lib.kingclub_novorudp_identity.restype = ctypes.c_uint64
lib.kingclub_novorudp_request.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
lib.kingclub_novorudp_request.restype = ctypes.c_void_p
lib.kingclub_novorudp_free.argtypes = [ctypes.c_void_p]
lib.kingclub_novorudp_free.restype = None

def request(value):
    wire = json.dumps(value).encode()
    ptr = lib.kingclub_novorudp_request(wire, len(wire))
    try:
        return json.loads(ctypes.string_at(ptr))
    finally:
        lib.kingclub_novorudp_free(ptr)

class BridgeTest(unittest.TestCase):
    def setUp(self):
        self.handles = []
    def tearDown(self):
        for handle in self.handles:
            self.assertTrue(request({'op':'close','handle':handle})['ok'])
    def identity(self, value):
        handle = lib.kingclub_novorudp_identity(bytes([value])*32, 32)
        self.assertNotEqual(handle, 0)
        self.handles.append(handle)
        return handle
    def call(self, op, handle, **fields):
        result = request(dict(op=op, handle=handle, **fields))
        self.assertTrue(result['ok'], result)
        data = result['data']
        if 'handle' in data:
            self.handles.append(data['handle'])
        return data
    def test_real_handshake_cipher_and_lifecycle(self):
        a, b = self.identity(31), self.identity(47)
        ap, bp = self.call('public', a)['peerId'], self.call('public', b)['peerId']
        start = self.call('start', a, expectedPeer=bp)
        self.assertFalse(request(dict(op='respond',handle=b,expectedPeer=bp,offer=start['offer']))['ok'])
        response = self.call('respond', b, expectedPeer=ap, offer=start['offer'])
        self.assertFalse(request(dict(op='respond',handle=b,expectedPeer=ap,offer=start['offer']))['ok'])
        completed = self.call('complete',start['handle'],response=response['response'])
        self.assertFalse(request(dict(op='complete',handle=start['handle'],response=response['response']))['ok'])
        sid = bytes(completed['sessionId'])
        payload = b'synthetic-native-ffi'
        values = struct.pack('<QQQQ',2**64-1,8,9,10)
        checksum = hashlib.sha256(b'novorudp-transport-frame-v0'+b'NOVRUDP0'+b'\x01\x00\x01'+sid+values+struct.pack('<Q',len(payload))+payload).digest()
        frame = b'NOVRUDP0'+b'\x01\x00\x01\x00'+sid+values+struct.pack('<I',len(payload))+checksum+payload
        envelope = self.call('seal',completed['handle'],frame=list(frame))['envelope']
        bad = json.loads(json.dumps(envelope));bad['ciphertext'][0] ^= 1
        self.assertFalse(request(dict(op='open',handle=response['handle'],envelope=bad))['ok'])
        self.assertEqual(bytes(self.call('open',response['handle'],envelope=envelope)['frame']),frame)
        self.assertFalse(request(dict(op='open',handle=response['handle'],envelope=envelope))['ok'])
        self.call('close',completed['handle'])
        self.assertFalse(request(dict(op='seal',handle=completed['handle'],frame=list(frame)))['ok'])
    def test_invalid_requests_and_handles(self):
        self.assertEqual(lib.kingclub_novorudp_identity(None,32),0)
        self.assertEqual(lib.kingclub_novorudp_identity(bytes(31),31),0)
        for op in ['public','start','complete','seal','open','respond','invalid']:
            self.assertFalse(request(dict(op=op,handle=0))['ok'])
        self.assertFalse(request({'op':'public','handle':1,'padding':'x'*17000})['ok'])

if __name__ == '__main__':
    unittest.main()
