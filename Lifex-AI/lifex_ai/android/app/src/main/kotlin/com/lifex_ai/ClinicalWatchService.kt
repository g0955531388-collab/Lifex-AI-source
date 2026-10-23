package com.lifex_ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class ClinicalWatchService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val camera = intent?.getBooleanExtra(EXTRA_CAMERA, false) == true
        ensureChannel()
        val notification = buildNotice()
        if (Build.VERSION.SDK_INT >= 34) {
            var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            if (camera) {
                type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            }
            startForeground(NOTICE_ID, notification, type)
        } else {
            startForeground(NOTICE_ID, notification)
        }
        return START_NOT_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "مراقبة صحية ظاهرة",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description =
                    "إشعار دائم طالما الميكروفون أو العدسة مفتوحان بموافقتك. ليس تصويراً خفياً ولا أرشيفاً."
            },
        )
    }

    private fun buildNotice(): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, ClinicalWatchService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ليفكس — حماية ظاهرة")
            .setContentText("الاستماع للأوامر مستمر بموافقتك. ليس تصويراً خفياً. اضغط لإيقاف.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(0, "إيقاف", stop)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "lifex_clinical_watch"
        private const val NOTICE_ID = 42
        private const val ACTION_STOP = "com.lifex_ai.STOP_CLINICAL_WATCH"
        private const val EXTRA_CAMERA = "camera"

        fun start(context: Context, camera: Boolean) {
            val intent = Intent(context, ClinicalWatchService::class.java)
                .putExtra(EXTRA_CAMERA, camera)
            if (Build.VERSION.SDK_INT >= 26) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ClinicalWatchService::class.java))
        }
    }
}
