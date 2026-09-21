"""Positive control for Java selector/token exchange, not public NAT evidence.

Requires compiled classes in build/nat-mapping/classes and a free local UDP
3478. A loopback STUN stub advertises this host's private interface address.
"""
import ipaddress
import secrets
import socket
import struct
import subprocess
import threading

with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
    route.connect(('47.103.59.206', 3478))  # Route selection only; sends no packet.
    local = route.getsockname()[0]
assert ipaddress.ip_address(local).is_private and not ipaddress.ip_address(local).is_loopback
servers = []
for host in ('127.0.0.1', '127.0.0.2'):
    server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server.bind((host, 3478))
    server.settimeout(.2)
    servers.append(server)
closed = threading.Event()

def stun(server):
    while not closed.is_set():
        try:
            request, source = server.recvfrom(1024)
        except socket.timeout:
            continue
        if len(request) != 20 or request[:2] != b'\x00\x01':
            continue
        attr = struct.pack('!HHBBHI', 0x20, 8, 0, 1,
            source[1] ^ 0x2112, int(ipaddress.ip_address(local)) ^ 0x2112a442)
        server.sendto(struct.pack('!HHI', 0x101, len(attr), 0x2112a442) + request[8:20] + attr, source)

threads = [threading.Thread(target=stun, args=(server,)) for server in servers]
for thread in threads:
    thread.start()
processes = []
try:
    for role in ('pool', 'single'):
        extra = ['127.0.0.2'] if role == 'pool' else []
        processes.append(subprocess.Popen(['java', '-cp', 'build/nat-mapping/classes',
            'PoolPunchProbe', '127.0.0.1', role, *extra], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True))
    endpoints = []
    for role, process in zip(('pool', 'single'), processes):
        line = process.stdout.readline()
        assert line.startswith('POOL_READY ')
        assert len(line.split()) == (9 if role == 'pool' else 2)
        raw = bytes.fromhex(line.split()[1])
        endpoints.append((int.from_bytes(raw[:2], 'big') ^ 0x2112))
    token = secrets.token_hex(16)
    for process, port in zip(processes, reversed(endpoints)):
        process.stdin.write(f'{local} {port} {token}\n')
        process.stdin.flush()
    for role, process in zip(('pool', 'single'), processes):
        output, _ = process.communicate(timeout=12)
        assert process.returncode == 0 and 'ping=true pong=true' in output
        print(role, 'bidirectional_token_exchange=True')
finally:
    for process in processes:
        if process.poll() is None:
            process.kill()
        process.communicate()
    closed.set()
    for thread in threads:
        thread.join(timeout=2)
    for server in servers:
        server.close()
