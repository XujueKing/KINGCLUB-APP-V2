"""Bounded before/after outbound UDP test; private endpoints stay in pipes."""
import argparse
import base64
import ipaddress
import json
import re
import subprocess
import threading

p = argparse.ArgumentParser()
p.add_argument('--adb', required=True)
p.add_argument('--serial', required=True)
p.add_argument('--observer', required=True)
p.add_argument('--ssh', required=True)
args = p.parse_args()
observer = str(ipaddress.IPv4Address(args.observer))
remote_code = '''import socket,json,sys
v=json.loads(sys.stdin.readline())
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:
 s.bind(('0.0.0.0',0))
 assert s.getsockname()[1]!=3478
 print(s.getsockname()[1],flush=True)
 assert sys.stdin.readline().strip()=='START'
 token=bytearray.fromhex(v['token'])
 for _ in range(3): s.sendto(token,(v['host'],v['port']))
 print('PHASE_ONE_SENT',flush=True)
 assert sys.stdin.readline().strip()=='OUTBOUND'
 token[0]^=1
 for _ in range(3): s.sendto(token,(v['host'],v['port']))
 print('PHASE_TWO_SENT',flush=True)
'''
encoded = base64.b64encode(remote_code.encode()).decode()
phone = subprocess.Popen([args.adb, '-s', args.serial, 'shell', '-T',
    'CLASSPATH=/data/local/tmp/kc-nat-mapping.dex', 'app_process',
    '/system/bin', 'NatMappingProbe', observer, '--active-filter'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
remote = None

def stop():
    phone.kill()
    if remote is not None and remote.poll() is None:
        remote.kill()

deadline = threading.Timer(25, stop)
deadline.start()
try:
    for line in phone.stdout:
        match = re.fullmatch(r'FILTER_READY ([0-9a-f]{12}) ([0-9a-f]{32})\s*', line)
        if match:
            raw = bytes.fromhex(match[1])
            port = int.from_bytes(raw[:2], 'big') ^ 0x2112
            host = str(ipaddress.IPv4Address(int.from_bytes(raw[2:], 'big') ^ 0x2112a442))
            if not ipaddress.ip_address(host).is_global or not 0 < port <= 65535:
                raise RuntimeError('Invalid mapped endpoint')
            remote = subprocess.Popen(['ssh', args.ssh,
                "timeout 20 python3 -u -c \"import base64;exec(base64.b64decode('"+encoded+"'))\""],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            remote.stdin.write(json.dumps({'host': host, 'port': port, 'token': match[2]})+'\n')
            remote.stdin.flush()
            alternate = int(remote.stdout.readline())
            if not 0 < alternate <= 65535 or alternate == 3478:
                raise RuntimeError('Invalid alternate port')
            phone.stdin.write(str(alternate)+'\n')
            phone.stdin.flush()
            remote.stdin.write('START\n')
            remote.stdin.flush()
            print('SERVER_PHASE_ONE_SEND', remote.stdout.readline().strip() == 'PHASE_ONE_SENT')
        elif line.strip() == 'FILTER_OUTBOUND':
            remote.stdin.write('OUTBOUND\n')
            remote.stdin.flush()
            print('SERVER_PHASE_TWO_SEND', remote.stdout.readline().strip() == 'PHASE_TWO_SENT')
        elif line.startswith('FILTER '):
            print(line.strip())
    phone.wait(timeout=2)
    if phone.returncode:
        raise RuntimeError('Device probe failed; private stderr not printed')
    if remote is not None and remote.wait(timeout=2):
        raise RuntimeError('Observer probe failed; private stderr not printed')
finally:
    deadline.cancel()
    stop()
    phone.communicate()
    if remote is not None:
        remote.communicate()
