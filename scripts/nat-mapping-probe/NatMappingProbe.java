import java.net.*;
import java.nio.*;
import java.security.SecureRandom;
import java.util.Arrays;
import java.io.BufferedReader;
import java.io.InputStreamReader;

/** Bounded diagnostic; filter mode requires a private coordinator pipe. */
public final class NatMappingProbe {
  static byte[] query(DatagramSocket socket, InetAddress server, int port) throws Exception {
    byte[] request = new byte[20];
    ByteBuffer b = ByteBuffer.wrap(request);
    b.putShort((short)1).putShort((short)0).putInt(0x2112a442);
    byte[] nonce = new byte[12]; new SecureRandom().nextBytes(nonce); b.put(nonce);
    for(int attempt=0; attempt<2; attempt++) {
      socket.send(new DatagramPacket(request, request.length, server, port));
      long until = System.nanoTime() + 2000000000L;
      while(System.nanoTime()<until) {
        socket.setSoTimeout(Math.max(1, (int)((until-System.nanoTime())/1000000L)));
        byte[] buf=new byte[1024]; DatagramPacket packet=new DatagramPacket(buf,buf.length);
        try { socket.receive(packet); } catch(SocketTimeoutException ex) { break; }
        if(!packet.getAddress().equals(server)||packet.getPort()!=port) continue;
        int n=packet.getLength(); if(n<20) continue;
        ByteBuffer v=ByteBuffer.wrap(buf);
        if(v.getShort(0)!=0x101 || (v.getShort(2)&65535)+20!=n || v.getInt(4)!=0x2112a442
            || !Arrays.equals(nonce,Arrays.copyOfRange(buf,8,20))) continue;
        for(int i=20;i+4<=n;) {
          int type=v.getShort(i)&65535, length=v.getShort(i+2)&65535;
          if(i+4+length>n) break;
          if(type==0x20 && length==8 && buf[i+5]==1) {
            // Raw XOR-mapped value is comparable with the fixed STUN cookie.
            return Arrays.copyOfRange(buf,i+6,i+12);
          }
          i+=4+((length+3)&~3);
        }
      }
    }
    return null;
  }
  static InetAddress ipv4(String host) throws Exception {
    for(InetAddress ip:InetAddress.getAllByName(host)) if(ip instanceof Inet4Address) return ip;
    throw new IllegalStateException("No IPv4 observer");
  }
  public static void main(String[] args) throws Exception {
    if(args.length==2 && args[1].equals("--active-filter")) { activeFilter(ipv4(args[0])); return; }
    if(args.length==2 && args[1].equals("--filter")) { filter(ipv4(args[0])); return; }
    if(args.length!=2) throw new IllegalArgumentException("Two observer hosts required");
    InetAddress first=ipv4(args[0]), second=ipv4(args[1]);
    if(first.equals(second)) throw new IllegalArgumentException("Observers must differ");
    try(DatagramSocket socket=new DatagramSocket(0,InetAddress.getByName("0.0.0.0"))) {
      byte[] a=query(socket,first,3478), b=query(socket,second,3478), c=query(socket,first,3478);
      boolean complete=a!=null && b!=null && c!=null;
      System.out.println("MAPPING first="+(a!=null)+" second="+(b!=null)+" repeat="+(c!=null)
        +" stableFirst="+(a!=null && c!=null && Arrays.equals(a,c))
        +" sameAddress="+(a!=null && b!=null && Arrays.equals(Arrays.copyOfRange(a,2,6),Arrays.copyOfRange(b,2,6)))
        +" samePort="+(a!=null && b!=null && a[0]==b[0] && a[1]==b[1])
        +" comparison="+(!complete?"inconclusive":!Arrays.equals(a,c)?"unstable":Arrays.equals(a,b)?"same":"destination-dependent"));
    }
  }
  static void filter(InetAddress server) throws Exception {
    try(DatagramSocket socket=new DatagramSocket(0,InetAddress.getByName("0.0.0.0"))) {
      byte[] mapped=query(socket,server,3478);
      if(mapped==null) { System.out.println("FILTER baseline=false"); return; }
      byte[] token=new byte[16]; new SecureRandom().nextBytes(token);
      // Private machine-readable coordination only; the host prints booleans.
      StringBuilder line=new StringBuilder("FILTER_READY ");
      for(byte value:mapped) line.append(String.format("%02x",value&255));
      line.append(' ');
      for(byte value:token) line.append(String.format("%02x",value&255));
      System.out.println(line); System.out.flush();
      boolean received=false; long until=System.nanoTime()+12000000000L;
      while(System.nanoTime()<until) {
        socket.setSoTimeout(Math.max(1,(int)((until-System.nanoTime())/1000000L)));
        DatagramPacket packet=new DatagramPacket(new byte[1024],1024);
        try { socket.receive(packet); } catch(SocketTimeoutException ex) { break; }
        if(packet.getAddress().equals(server) && packet.getPort()!=3478
            && Arrays.equals(token,Arrays.copyOf(packet.getData(),packet.getLength()))) {
          received=true; break;
        }
      }
      byte[] after=query(socket,server,3478);
      System.out.println("FILTER baseline=true alternatePortReceived="+received
        +" baselineAfter="+(after!=null)+" mappingStable="+(after!=null && Arrays.equals(mapped,after)));
    }
  }
  static boolean receiveToken(DatagramSocket socket, InetAddress server, int port,
      byte[] token, int seconds) throws Exception {
    long until=System.nanoTime()+seconds*1000000000L;
    while(System.nanoTime()<until) {
      socket.setSoTimeout(Math.max(1,(int)((until-System.nanoTime())/1000000L)));
      DatagramPacket packet=new DatagramPacket(new byte[1024],1024);
      try { socket.receive(packet); } catch(SocketTimeoutException ex) { break; }
      if(packet.getAddress().equals(server) && packet.getPort()==port
          && Arrays.equals(token,Arrays.copyOf(packet.getData(),packet.getLength()))) return true;
    }
    return false;
  }
  static void activeFilter(InetAddress server) throws Exception {
    try(DatagramSocket socket=new DatagramSocket(0,InetAddress.getByName("0.0.0.0"))) {
      byte[] mapped=query(socket,server,3478);
      if(mapped==null) { System.out.println("FILTER baseline=false"); return; }
      byte[] token=new byte[16]; new SecureRandom().nextBytes(token);
      StringBuilder line=new StringBuilder("FILTER_READY ");
      for(byte value:mapped) line.append(String.format("%02x",value&255));
      line.append(' ');
      for(byte value:token) line.append(String.format("%02x",value&255));
      System.out.println(line); System.out.flush();
      int port=Integer.parseInt(new BufferedReader(new InputStreamReader(System.in)).readLine());
      if(port<1 || port>65535 || port==3478) throw new IllegalArgumentException("Invalid alternate port");
      boolean before=receiveToken(socket,server,port,token,4);
      // Phase two uses a different token so queued phase-one replies cannot count.
      token[0]^=1;
      socket.send(new DatagramPacket(token,token.length,server,port));
      System.out.println("FILTER_OUTBOUND"); System.out.flush();
      boolean after=receiveToken(socket,server,port,token,7);
      byte[] repeat=query(socket,server,3478);
      System.out.println("FILTER baseline=true beforeOutbound="+before+" afterOutbound="+after
        +" baselineAfter="+(repeat!=null)+" mappingStable="+(repeat!=null && Arrays.equals(mapped,repeat)));
    }
  }
}
