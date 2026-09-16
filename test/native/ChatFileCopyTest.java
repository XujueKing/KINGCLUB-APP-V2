import com.lingmei.kingclub.ChatFileCopy;
import java.io.*;
import java.security.MessageDigest;
import java.util.concurrent.atomic.AtomicBoolean;

public class ChatFileCopyTest {
    static class Generated extends InputStream {
        long remaining;
        Generated(long count) { remaining = count; }
        public int read() { throw new AssertionError("Must use bounded bulk reads"); }
        public int read(byte[] b, int off, int len) {
            if (len > 65536) throw new AssertionError("Unbounded buffer");
            if (remaining == 0) return -1;
            int n = (int)Math.min(remaining, len);
            java.util.Arrays.fill(b, off, off+n, (byte)7);
            remaining -= n;
            return n;
        }
    }
    static String hash(long count) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] block = new byte[32768]; java.util.Arrays.fill(block, (byte)7);
        while (count > 0) { int n=(int)Math.min(count, block.length); md.update(block,0,n); count-=n; }
        StringBuilder result=new StringBuilder();
        for(byte b:md.digest()) result.append(String.format("%02x",b & 255));
        return result.toString();
    }
    interface Checked { void run() throws Exception; }
    static void fails(Checked code) throws Exception {
        try { code.run(); } catch(IOException expected) { return; }
        throw new AssertionError("Expected rejection");
    }
    public static void main(String[] args) throws Exception {
        OutputStream discard=OutputStream.nullOutputStream();
        for(long size:new long[]{0, 65537, 268435456}) {
            final long[] written={0};
            ChatFileCopy.copy(new Generated(size),new OutputStream() {
                public void write(int b) { throw new AssertionError(); }
                public void write(byte[] b,int off,int len) { written[0]+=len; }
            },size,hash(size),()->false);
            if(written[0]!=size) throw new AssertionError("Wrong size");
        }
        fails(()->ChatFileCopy.copy(new Generated(2),discard,3,hash(3),()->false));
        fails(()->ChatFileCopy.copy(new Generated(4),discard,3,hash(3),()->false));
        fails(()->ChatFileCopy.copy(new Generated(3),discard,3,hash(4),()->false));
        AtomicBoolean cancel=new AtomicBoolean();
        fails(()->ChatFileCopy.copy(new Generated(131072),new OutputStream(){
            public void write(int b) { throw new AssertionError(); }
            public void write(byte[] b,int off,int len) { cancel.set(true); }
        },131072,hash(131072),cancel::get));
        fails(()->ChatFileCopy.copy(new Generated(1),new OutputStream(){
            public void write(int b) throws IOException { throw new IOException("Disk full"); }
        },1,hash(1),()->false));
        AtomicBoolean cancelledDuringRead = new AtomicBoolean();
        final long[] afterCancelWrites = {0};
        fails(()->ChatFileCopy.copy(new Generated(3) {
            public int read(byte[] b, int off, int len) {
                int count = super.read(b, off, len);
                cancelledDuringRead.set(true);
                return count;
            }
        }, new OutputStream() {
            public void write(int b) { afterCancelWrites[0]++; }
            public void write(byte[] b, int off, int len) { afterCancelWrites[0] += len; }
        }, 3, hash(3), cancelledDuringRead::get));
        if (afterCancelWrites[0] != 0) throw new AssertionError("Write after cancelled read");
        AtomicBoolean cancelledDuringFlush = new AtomicBoolean();
        fails(()->ChatFileCopy.copy(new Generated(0), new OutputStream() {
            public void write(int b) { throw new AssertionError(); }
            public void flush() { cancelledDuringFlush.set(true); }
        }, 0, hash(0), cancelledDuringFlush::get));
        System.out.println("CHAT_FILE_NATIVE_COPY_EMPTY_LARGE_DIGEST_BOUNDS_CANCEL_IO_PASSED");
    }
}
