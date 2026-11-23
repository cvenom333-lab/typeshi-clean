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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "typeshi/noisy").setStreamHandler(
            object : EventChannel.StreamHandler {
                private var receiver: BroadcastReceiver? = null
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                                events?.success("noisy")
                            }
                        }
                    }
                    registerReceiver(receiver, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
                }
                override fun onCancel(arguments: Any?) {
                    receiver?.let { unregisterReceiver(it) }
                    receiver = null
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "typeshi/shake").setStreamHandler(
            object : EventChannel.StreamHandler, SensorEventListener {
                private var sensorManager: SensorManager? = null
                private var sink: EventChannel.EventSink? = null
                private var lastShakeTime = 0L

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                    sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                    val accel = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                    sensorManager?.registerListener(this, accel, SensorManager.SENSOR_DELAY_UI)
                }

                override fun onCancel(arguments: Any?) {
                    sensorManager?.unregisterListener(this)
                    sink = null
                }

                override fun onSensorChanged(event: SensorEvent?) {
                    val v = event?.values ?: return
                    val gForce = sqrt((v*v + v*v + v*v).toDouble()) / 9.81
                    val now = System.currentTimeMillis()
                    if (gForce > 2.35 && now - lastShakeTime > 1200) {
                        lastShakeTime = now
                        sink?.success("shake")
                    }
                }

                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
            }
        )
    }
}

