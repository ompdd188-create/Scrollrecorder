 Path: android/app/src/main/kotlin/com/example/scrollrecorder/Application.kt
    kotlin
    package com.example.scrollrecorder

    import io.flutter.app.FlutterApplication
    import io.flutter.plugin.generated.FlutterPluginRegistrant

    class Application : FlutterApplication() {
        override fun onCreate() {
            super.onCreate()
            FlutterPluginRegistrant.registerWith(this)
        }
    }
