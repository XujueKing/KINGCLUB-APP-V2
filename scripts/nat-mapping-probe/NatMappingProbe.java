import java.net.*;
import java.nio.*;
import java.security.SecureRandom;
import java.util.Arrays;

/** Bounded diagnostic, run with app_process; never prints mapped addresses. */
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
}
