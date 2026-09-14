package com.lingmei.kingclub.videoprobe;

import android.app.Instrumentation;
import android.content.Context;
import android.os.Bundle;
import java.io.*;
import java.lang.reflect.*;
import java.util.*;
import java.util.concurrent.*;

/** Runs the installed native bridge against a synthetic asset. No network/send. */
public final class VideoUploadProbe extends Instrumentation {
  @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }
  @Override public void onStart() {
    Bundle report = new Bundle();
    File input = new File(getTargetContext().getCacheDir(), "synthetic-video-probe.mp4");
    Object[] bridge = new Object[1];
    Class<?>[] bridgeClass = new Class<?>[1];
    try {
      try (InputStream from = getContext().getAssets().open("source.mp4"); OutputStream to = new FileOutputStream(input)) {
        byte[] buffer = new byte[65536]; int n;
        while ((n = from.read(buffer)) != -1) to.write(buffer, 0, n);
      }
      CountDownLatch done = new CountDownLatch(1);
      Object[] output = new Object[1];
      Throwable[] failure = new Throwable[1];
      long started = android.os.SystemClock.elapsedRealtime();
      runOnMainSync(() -> {
        try {
          ClassLoader loader = getTargetContext().getClassLoader();
          bridgeClass[0] = loader.loadClass("com.lingmei.kingclub.ChatVideoUpload");
          bridge[0] = bridgeClass[0].getConstructor(Context.class).newInstance(getTargetContext());
          Class<?> call = loader.loadClass("io.flutter.plugin.common.MethodCall");
          Class<?> result = loader.loadClass("io.flutter.plugin.common.MethodChannel$Result");
          Map<String,Object> args = new HashMap<>();
          args.put("id", UUID.randomUUID().toString());
          // Fixed synthetic fixture identity; release removes this cache entry.
          args.put("key", "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"); args.put("path", input.getAbsolutePath());
          Object request = call.getConstructor(String.class, Object.class).newInstance("prepare", args);
          Object callback = Proxy.newProxyInstance(loader, new Class<?>[]{result}, (p,m,a) -> {
            if (m.getName().equals("success")) { output[0] = a[0]; done.countDown(); }
            else if (m.getName().equals("error") || m.getName().equals("notImplemented")) {
              failure[0] = new IllegalStateException(m.getName()); done.countDown();
            }
            return null;
          });
          bridgeClass[0].getMethod("handle", call, result).invoke(bridge[0], request, callback);
        } catch (Throwable e) { failure[0] = e; done.countDown(); }
      });
      if (!done.await(130, TimeUnit.SECONDS)) throw new IllegalStateException("timeout");
      if (failure[0] != null) throw new IllegalStateException("bridge failure", failure[0]);
      report.putLong("elapsedMs", android.os.SystemClock.elapsedRealtime() - started);
      report.putLong("sourceBytes", input.length());
      if (output[0] instanceof String) {
        File copy = new File((String) output[0]);
        report.putLong("outputBytes", copy.length());
        report.putString("result", copy.length() > 0 && copy.length() < input.length() ? (copy.length() <= 2_000_000 ? "COMPRESSED" : "BITRATE_OVERSHOOT") : "INVALID_OUTPUT");
        copy.delete();
      } else report.putString("result", "FELL_BACK_TO_SOURCE");
    } catch (Throwable error) {
      report.putString("result", "FAILED");
      report.putString("errorType", error.getClass().getSimpleName());
      if (error.getCause() != null) report.putString("causeType", error.getCause().getClass().getSimpleName());
    } finally {
      runOnMainSync(() -> { try { if (bridge[0] != null) bridgeClass[0].getMethod("dispose").invoke(bridge[0]); } catch (Exception ignored) {} });
      input.delete();
      finish(-1, report);
    }
  }
}
