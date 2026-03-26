plugins {
    id("com.android.application")      apply false
    id("com.android.library")          apply false
    id("org.jetbrains.kotlin.android") apply false

    // ── Firebase / Google Services ──────────────────────────
    id("com.google.gms.google-services") version "4.4.4" apply false
}
