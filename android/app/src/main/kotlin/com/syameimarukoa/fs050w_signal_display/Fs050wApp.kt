package com.syameimarukoa.fs050w_signal_display

import android.app.Application

class Fs050wApp : Application() {
    override fun onCreate() {
        super.onCreate()
        // Native migration: the singleton repository is created lazily by MainActivity.
    }
}
