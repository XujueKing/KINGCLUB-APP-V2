package com.lingmei.kingclub;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.function.BooleanSupplier;

/** Bounded stream copy shared by Android export and JVM verification. */
public final class ChatFileCopy {
    private ChatFileCopy() {}
    public static void copy(InputStream input, OutputStream output, long size,
                            String expectedHash, BooleanSupplier cancelled) throws IOException {
        if (size < 0 || size > 268435456L || expectedHash == null ||
                !expectedHash.matches("[0-9a-f]{64}")) throw new IOException("Invalid file metadata");
        final MessageDigest digest;
        try { digest = MessageDigest.getInstance("SHA-256"); }
        catch (NoSuchAlgorithmException e) { throw new IOException(e); }
        byte[] buffer = new byte[65536];
        long total = 0;
        while (true) {
            if (cancelled.getAsBoolean()) throw new IOException("Cancelled");
            int count = input.read(buffer);
            if (cancelled.getAsBoolean()) throw new IOException("Cancelled");
            if (count < 0) break;
            if (count == 0) throw new IOException("Stream did not advance");
            total += count;
            if (total > size) throw new IOException("Oversize file");
            digest.update(buffer, 0, count);
            output.write(buffer, 0, count);
        }
        if (total != size) throw new IOException("Truncated file");
        StringBuilder actual = new StringBuilder(64);
        for (byte b : digest.digest()) actual.append(String.format("%02x", b & 255));
        if (!actual.toString().equals(expectedHash)) throw new IOException("Digest mismatch");
        if (cancelled.getAsBoolean()) throw new IOException("Cancelled");
        output.flush();
        if (cancelled.getAsBoolean()) throw new IOException("Cancelled");
    }
}
