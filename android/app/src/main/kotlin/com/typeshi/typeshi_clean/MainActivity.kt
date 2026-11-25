package com.typeshi.typeshi_clean

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioManager
import android.os.BatteryManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "typeshi/system").setMethodCallHandler { call, result ->
            if (call.method == "getBatteryLevel") {
                val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                result.success(bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY))
            } else {
                result.notImplemented()
            }
        }

        EventChannel(messenger, "typeshi/noisy").setStreamHandler(object : EventChannel.StreamHandler {
            private var receiver: BroadcastReceiver? = null
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) events?.success("noisy")
                    }
                }
                registerReceiver(receiver, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
            }
            override fun onCancel(arguments: Any?) {
                receiver?.let { unregisterReceiver(it) }
                receiver = null
            }
        })

        EventChannel(messenger, "typeshi/sensors").setStreamHandler(object : EventChannel.StreamHandler, SensorEventListener {
            private var sm: SensorManager? = null
            private var sink: EventChannel.EventSink? = null
            private var lastShake = 0L

            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                sm?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let { sm?.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
                sm?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)?.let { sm?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
            }

            override fun onCancel(arguments: Any?) {
                sm?.unregisterListener(this)
                sink = null
            }

            override fun onSensorChanged(event: SensorEvent?) {
                val e = event ?: return
                val v = e.values
                if (e.sensor.type == Sensor.TYPE_ACCELEROMETER && v.size >= 3) {
                    val gForce = sqrt((v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).toDouble()) / 9.81
                    val now = System.currentTimeMillis()
                    if (gForce > 2.35 && now - lastShake > 1200) {
                        lastShake = now
                        sink?.success(mapOf("type" to "shake"))
                    }
                } else if (e.sensor.type == Sensor.TYPE_GYROSCOPE && v.size >= 2) {
                    sink?.success(mapOf("type" to "gyro", "x" to v[0].toDouble(), "y" to v[1].toDouble()))
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        })
    }
}

