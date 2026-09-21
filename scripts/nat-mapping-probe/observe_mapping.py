"""Compare STUN and an existing authorized UDP destination; no new listener.

Remote raw capture matches only the ephemeral random token. No packet contents
or IP addresses are returned, persisted or logged. Requires Linux sudo python3.
"""
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
p.add_argument('--destination-port', type=int, required=True)
args = p.parse_args()
if not 0 < args.destination_port <= 65535:
    raise ValueError('Invalid comparison port')
observer = str(ipaddress.IPv4Address(args.observer))
code = '''import socket,json,sys,time
v=json.loads(sys.stdin.readline())
with socket.socket(socket.AF_PACKET,socket.SOCK_RAW,socket.htons(0x0800)) as s:
 s.settimeout(1)
 print('READY',flush=True)
 until=time.monotonic()+8
 found=False
 while time.monotonic()<until:
  try: data=s.recv(65535)
  except socket.timeout: continue
  if len(data)<34 or data[12:14]!=b'\\x08\\x00': continue
  data=data[14:]
  if data[9]!=17: continue
  ihl=(data[0]&15)*4
  if len(data)<ihl+8 or data[0]>>4!=4: continue
  udp=data[ihl:]
  if int.from_bytes(udp[2:4],'big')!=v['destination']: continue
  length=int.from_bytes(udp[4:6],'big')
  if length!=24 or len(udp)<length or udp[8:length]!=bytes.fromhex(v['token']): continue
  found=True
  print('OBSERVED sameAddress='+str(socket.inet_ntoa(data[12:16])==v['host'])+
   ' samePort='+str(int.from_bytes(udp[:2],'big')==v['port']),flush=True)
  distance=abs(int.from_bytes(udp[:2],'big')-v['port'])
  print('OBSERVED portDistanceBucket='+('zero' if distance==0 else
   'within8' if distance<=8 else 'within64' if distance<=64 else
   'within1024' if distance<=1024 else 'over1024'),flush=True)
  break
 print('OBSERVED received='+str(found),flush=True)
'''
encoded = base64.b64encode(code.encode()).decode()
phone = subprocess.Popen([args.adb, '-s', args.serial, 'shell', '-T',
    'CLASSPATH=/data/local/tmp/kc-nat-mapping.dex', 'app_process', '/system/bin',
    'NatMappingProbe', observer, '--observe-mapping'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
remote = None
def stop():
    for process in (phone, remote):
        if process is not None and process.poll() is None:
            process.kill()
deadline = threading.Timer(25, stop)
deadline.start()
try:
    for line in phone.stdout:
        match = re.fullmatch(r'FILTER_READY ([0-9a-f]{12}) ([0-9a-f]{32})\s*', line)
        if match:
            raw = bytes.fromhex(match[1])
            host = str(ipaddress.IPv4Address(int.from_bytes(raw[2:], 'big') ^ 0x2112a442))
            port = int.from_bytes(raw[:2], 'big') ^ 0x2112
            if not ipaddress.ip_address(host).is_global or not port:
                raise ValueError('Invalid mapped endpoint')
            remote = subprocess.Popen(['ssh', args.ssh,
                "sudo -n timeout 12 python3 -u -c \"import base64;exec(base64.b64decode('"+encoded+"'))\""],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            remote.stdin.write(json.dumps({'host': host, 'port': port,
                'token': match[2], 'destination': args.destination_port})+'\n')
            remote.stdin.flush()
            if remote.stdout.readline().strip() != 'READY':
                raise RuntimeError('Remote capture not ready; private stderr withheld')
            phone.stdin.write(str(args.destination_port)+'\n')
            phone.stdin.flush()
            for result in remote.stdout:
                if result.startswith('OBSERVED '):
                    print(result.strip())
            if remote.wait(timeout=2):
                raise RuntimeError('Remote capture failed')
        elif line.startswith('OBSERVE '):
            print(line.strip())
    if phone.wait(timeout=2):
        raise RuntimeError('Phone diagnostic failed')
finally:
    deadline.cancel()
    stop()
    phone.communicate()
    if remote is not None:
        remote.communicate()
