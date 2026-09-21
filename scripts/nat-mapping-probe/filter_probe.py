"""Run against an explicitly selected authorized device and SSH observer.

Mapped endpoints and random tokens stay in subprocess pipes, never reports.
No remote listener/firewall change: three outbound UDP datagrams only.
"""
import argparse
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
proc = subprocess.Popen([args.adb, '-s', args.serial, 'shell',
    'CLASSPATH=/data/local/tmp/kc-nat-mapping.dex', 'app_process',
    '/system/bin', 'NatMappingProbe', observer, '--filter'],
    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
deadline = threading.Timer(25, proc.kill)
deadline.start()
try:
    for line in proc.stdout:
        match = re.fullmatch(r'FILTER_READY ([0-9a-f]{12}) ([0-9a-f]{32})\s*', line)
        if match:
            raw = bytes.fromhex(match[1])
            port = int.from_bytes(raw[:2], 'big') ^ 0x2112
            host = str(ipaddress.IPv4Address(int.from_bytes(raw[2:], 'big') ^ 0x2112a442))
            if not ipaddress.ip_address(host).is_global or not 0 < port <= 65535:
                raise RuntimeError('Invalid mapped endpoint')
            script = '''import socket,time,json,sys,subprocess
v=json.loads(sys.stdin.readline())
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
s.bind(('0.0.0.0',0))
assert s.getsockname()[1]!=3478
capture=subprocess.Popen(['sudo','-n','timeout','4','tcpdump','-ni','any',
 '-c','1','-w','/dev/null','udp and src port '+str(s.getsockname()[1])+
 ' and dst host '+v['host']+' and dst port '+str(v['port'])],
 stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
time.sleep(.4)
for _ in range(3):
 s.sendto(bytes.fromhex(v['token']),(v['host'],v['port']))
 time.sleep(.15)
s.close()
capture.communicate(timeout=5)
print('SENT_THREE')
print('EGRESS_CAPTURED' if capture.returncode==0 else 'EGRESS_UNCONFIRMED')
'''
            # Code is fixed; endpoint/token are passed as JSON over stdin.
            import base64
            encoded = base64.b64encode(script.encode()).decode()
            result = subprocess.run(['ssh', args.ssh,
                "python3 -c \"import base64;exec(base64.b64decode('"+encoded+"'))\""],
                input=json.dumps({'host': host, 'port': port, 'token': match[2]})+'\n',
                capture_output=True, text=True, timeout=8)
            print('SERVER_SEND', result.returncode == 0 and 'SENT_THREE' in result.stdout)
            print('SERVER_EGRESS_CAPTURED', result.returncode == 0 and 'EGRESS_CAPTURED' in result.stdout)
        elif line.startswith('FILTER '):
            print(line.strip())
    proc.wait(timeout=2)
    if proc.returncode:
        raise RuntimeError('Device probe failed; private stderr not printed')
finally:
    deadline.cancel()
    if proc.poll() is None:
        proc.kill()
    proc.communicate()
