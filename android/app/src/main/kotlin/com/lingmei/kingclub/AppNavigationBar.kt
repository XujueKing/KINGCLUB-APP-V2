package com.lingmei.kingclub

import android.view.Window
import android.os.SystemClock
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/** Hide only this window's navigation bar, while preserving system escape gestures. */
class AppNavigationBar(private val window: Window) {
    private val view = window.decorView
    private var active = false
    private var keyboardVisible = false
    private var keyboardDismissedAt = 0L
    private val hide = Runnable {
        if (active && view.hasWindowFocus() &&
            ViewCompat.getRootWindowInsets(view)?.isVisible(WindowInsetsCompat.Type.ime()) != true) {
            WindowCompat.getInsetsController(window, view).apply {
                systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsetsCompat.Type.navigationBars())
            }
        }
    }

    init {
        ViewCompat.setOnApplyWindowInsetsListener(view) { _, insets ->
            val visible = insets.isVisible(WindowInsetsCompat.Type.ime())
            if (keyboardVisible && !visible && active) {
                // Android temporarily rejects bar changes immediately after IME dismissal.
                keyboardDismissedAt = SystemClock.uptimeMillis()
                focus()
            }
            keyboardVisible = visible
            insets
        }
    }

    fun resume() {
        active = true
        focus()
    }

    fun focus() {
        view.removeCallbacks(hide)
        val delay = (keyboardDismissedAt + 1200 - SystemClock.uptimeMillis()).coerceAtLeast(0)
        view.postDelayed(hide, delay)
    }

    fun pause() {
        active = false
        view.removeCallbacks(hide)
    }

    fun dispose() {
        pause()
        ViewCompat.setOnApplyWindowInsetsListener(view, null)
    }
}
