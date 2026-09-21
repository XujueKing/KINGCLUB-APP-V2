import java.net.*;
import java.nio.*;
import java.nio.channels.*;
import java.io.*;
import java.security.SecureRandom;
import java.util.*;

/** Reachability experiment only, not an encrypted production transport. */
public final class PoolPunchProbe {
  public static void main(String[] args) throws Exception {
    boolean pool=args.length==2 && args[1].equals("pool");
    if(args.length!=2 || (!pool && !args[1].equals("single"))) throw new IllegalArgumentException();
    ArrayList<DatagramChannel> channels=new ArrayList<>();
    try(Selector selector=Selector.open()) {
      StringBuilder report=new StringBuilder("POOL_READY");
      for(int i=0;i<(pool?128:1);i++) {
        DatagramChannel c=DatagramChannel.open(); channels.add(c);
        c.socket().bind(new InetSocketAddress(InetAddress.getByName("0.0.0.0"),0));
        if(i<(pool?4:1)) {
          byte[] mapped=NatMappingProbe.query(c.socket(),NatMappingProbe.ipv4(args[0]),3478);
          if(mapped==null) throw new IOException("Mapping unavailable");
          report.append(' ');
          for(byte value:mapped) report.append(String.format("%02x",value&255));
        }
        c.configureBlocking(false); c.register(selector,SelectionKey.OP_READ);
      }
      System.out.println(report); System.out.flush();
      String line=new BufferedReader(new InputStreamReader(System.in)).readLine();
      String[] fields=line.split(" ");
      if(fields.length!=3 || !fields[2].matches("[0-9a-f]{32}")) throw new IOException("Invalid instruction");
      String[] hosts=fields[0].split(",");
      if(hosts.length<1 || hosts.length>4) throw new IOException("Too many hosts");
      InetAddress[] peers=new InetAddress[hosts.length];
      for(int i=0;i<hosts.length;i++) {
        peers[i]=NatMappingProbe.ipv4(hosts[i]);
        if(peers[i].isAnyLocalAddress() || peers[i].isLoopbackAddress() || peers[i].isMulticastAddress())
          throw new IOException("Invalid peer");
      }
      int port=Integer.parseInt(fields[1]);
      if(port<1 || port>65535) throw new IOException("Invalid port");
      byte[] ping=new byte[17];
      for(int i=0;i<16;i++) ping[i+1]=(byte)Integer.parseInt(fields[2].substring(i*2,i*2+2),16);
      byte[] pong=ping.clone(); pong[0]=1;
      SecureRandom random=new SecureRandom();
      HashSet<String> targets=new HashSet<>();
      int sent=0,replies=0,rounds=0; boolean gotPing=false,gotPong=false;
      long start=System.nanoTime(),next=start+(pool?0:300000000L);
      while(System.nanoTime()-start<8000000000L) {
        long now=System.nanoTime();
        if(!gotPong && now>=next && now-start<4500000000L) {
          if(pool && rounds<8) {
            for(DatagramChannel c:channels) { c.send(ByteBuffer.wrap(ping),new InetSocketAddress(peers[0],port)); sent++; }
            rounds++; next=now+500000000L;
          } else if(!pool && sent<2048) {
            for(int i=0;i<8 && sent<2048;i++) {
              int candidate=1024+random.nextInt(65536-1024);
              int index=sent%peers.length;
              if(!targets.add(index+":"+candidate)) continue;
              channels.get(0).send(ByteBuffer.wrap(ping),new InetSocketAddress(peers[index],candidate)); sent++;
            }
            next=now+16000000L;
          }
        }
        selector.select(10);
        Iterator<SelectionKey> iterator=selector.selectedKeys().iterator();
        while(iterator.hasNext()) {
          SelectionKey key=iterator.next(); iterator.remove();
          DatagramChannel c=(DatagramChannel)key.channel();
          for(int i=0;i<8;i++) {
            ByteBuffer buffer=ByteBuffer.allocate(128);
            InetSocketAddress source=(InetSocketAddress)c.receive(buffer);
            if(source==null) break;
            if(buffer.position()!=17) continue;
            byte[] data=Arrays.copyOf(buffer.array(),17);
            if(!Arrays.equals(Arrays.copyOfRange(data,1,17),Arrays.copyOfRange(ping,1,17))) continue;
            if(pool && (!source.getAddress().equals(peers[0]) || source.getPort()!=port)) continue;
            if(data[0]==0) {
              gotPing=true;
              if(replies<64) { c.send(ByteBuffer.wrap(pong),source); replies++; }
            } else if(data[0]==1) gotPong=true;
          }
        }
      }
      System.out.println("POOL_RESULT sockets="+channels.size()+" probes="+sent+
        " replies="+replies+" ping="+gotPing+" pong="+gotPong);
    } finally { for(DatagramChannel c:channels) c.close(); }
  }
}
