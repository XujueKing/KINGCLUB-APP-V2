"""One bounded, authorized A/B reachability run, with private pipe coordination."""
import argparse
import ipaddress
import re
import secrets
import subprocess
import threading

p = argparse.ArgumentParser()
p.add_argument('--adb', required=True)
p.add_argument('--pool-device', required=True)
p.add_argument('--single-device', required=True)
p.add_argument('--observer', required=True)
args = p.parse_args()
observer = str(ipaddress.IPv4Address(args.observer))
if args.pool_device == args.single_device:
    raise ValueError('Two different authorized devices required')
processes = []
def stop():
    for process in processes:
        if process.poll() is None:
            process.kill()
deadline = threading.Timer(40, stop)
deadline.start()
try:
    for serial, role in [(args.pool_device, 'pool'), (args.single_device, 'single')]:
        processes.append(subprocess.Popen([args.adb, '-s', serial, 'shell', '-T',
            'CLASSPATH=/data/local/tmp/kc-nat-mapping.dex', 'app_process',
            '/system/bin', 'PoolPunchProbe', observer, role], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True))
    mappings = []
    for process in processes:
        line = process.stdout.readline().strip()
        if not re.fullmatch(r'POOL_READY(?: [0-9a-f]{12}){1,4}', line):
            raise RuntimeError('Phone mapping failed; private output withheld')
        endpoints = []
        for item in line.split()[1:]:
            raw = bytes.fromhex(item)
            host = ipaddress.IPv4Address(int.from_bytes(raw[2:], 'big') ^ 0x2112a442)
            port = int.from_bytes(raw[:2], 'big') ^ 0x2112
            if not host.is_global or not port:
                raise RuntimeError('Invalid public mapping')
            endpoints.append((str(host), port))
        mappings.append(endpoints)
    token = secrets.token_hex(16)
    host, port = mappings[1][0]
    processes[0].stdin.write(f'{host} {port} {token}\n')
    processes[0].stdin.flush()
    hosts = list(dict.fromkeys(host for host, _ in mappings[0]))
    processes[1].stdin.write(f'{",".join(hosts)} {mappings[0][0][1]} {token}\n')
    processes[1].stdin.flush()
    print('CANDIDATE_ADDRESS_COUNT', len(hosts))
    for role, process in zip(['pool', 'single'], processes):
        for line in process.stdout:
            if re.fullmatch(r'POOL_RESULT sockets=\d+ probes=\d+ replies=\d+ ping=(true|false) pong=(true|false)\s*', line):
                print(role, line.strip())
        if process.wait(timeout=2):
            raise RuntimeError('Phone probe failed; private stderr withheld')
finally:
    deadline.cancel()
    stop()
    for process in processes:
        process.communicate()
