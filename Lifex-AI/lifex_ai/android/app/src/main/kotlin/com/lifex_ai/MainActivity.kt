package com.lifex_ai

import android.app.Activity
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val cueChannel = "lifex_ai/hardware_cue"
    private val watchChannel = "lifex_ai/clinical_watch"
    private val shareChannel = "lifex_ai/share"
    private val contactPickerChannel = "lifex_ai/contact_picker"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pickContactRequest = 9911

    private var cueKind: String = "volumeUpDouble"
    private var tapCount: Int = 2
    private var windowMs: Long = 480
    private var hits: Int = 0
    private var lastHitAt: Long = 0
    private var lastCode: Int = 0
    private var pendingContactResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, cueChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        val args = call.arguments as? Map<*, *>
                        cueKind = args?.get("kind") as? String ?: cueKind
                        tapCount = (args?.get("tapCount") as? Int) ?: tapCount
                        windowMs = ((args?.get("windowMs") as? Int) ?: windowMs.toInt()).toLong()
                        result.success(null)
                    }
                    "playTone" -> {
                        playStartTone()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, watchChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val camera = (call.arguments as? Map<*, *>)?.get("camera") == true
                        ClinicalWatchService.start(this, camera)
                        result.success("إشعار المراقبة الصحية ظاهر. أوقفه من الإشعار أو من الشاشة.")
                    }
                    "stop" -> {
                        ClinicalWatchService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val text = (call.arguments as? Map<*, *>)?.get("text") as? String ?: ""
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            putExtra(Intent.EXTRA_SUBJECT, "Lifex-AI")
                        }
                        startActivity(Intent.createChooser(intent, "مشاركة موسوعة Lifex-AI"))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, contactPickerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickContact" -> {
                        if (pendingContactResult != null) {
                            result.error("BUSY", "منتقي جهات الاتصال قيد الاستخدام.", null)
                            return@setMethodCallHandler
                        }
                        pendingContactResult = result
                        // Pick a phone row directly — minimum data, no full address book.
                        val intent = Intent(
                            Intent.ACTION_PICK,
                            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                        )
                        try {
                            startActivityForResult(intent, pickContactRequest)
                        } catch (e: Exception) {
                            pendingContactResult = null
                            result.error("UNAVAILABLE", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickContactRequest) return
        val reply = pendingContactResult
        pendingContactResult = null
        if (reply == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            reply.success(null)
            return
        }
        try {
            reply.success(readPickedContactMinimum(data.data!!))
        } catch (e: Exception) {
            reply.error("READ_FAILED", e.message, null)
        }
    }

    /**
     * Reads ONLY the selected contact URI (system picker grant).
     * Does not dump the address book. No READ_CALL_LOG / READ_SMS.
     */
    private fun readPickedContactMinimum(contactUri: Uri): Map<String, String?> {
        var displayName: String? = null
        var lookupKey: String? = null
        var contactId: String? = null
        contentResolver.query(
            contactUri,
            arrayOf(
                ContactsContract.Contacts._ID,
                ContactsContract.Contacts.DISPLAY_NAME,
                ContactsContract.Contacts.LOOKUP_KEY,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                contactId = cursor.getString(0)
                displayName = cursor.getString(1)
                lookupKey = cursor.getString(2)
            }
        }

        var phoneNumber: String? = null
        if (contactId != null) {
            contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID}=?",
                arrayOf(contactId),
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    phoneNumber = cursor.getString(0)
                }
            }
        }

        var email: String? = null
        if (contactId != null) {
            contentResolver.query(
                ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                arrayOf(ContactsContract.CommonDataKinds.Email.ADDRESS),
                "${ContactsContract.CommonDataKinds.Email.CONTACT_ID}=?",
                arrayOf(contactId),
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    email = cursor.getString(0)
                }
            }
        }

        return mapOf(
            "displayName" to displayName,
            "phoneNumber" to phoneNumber,
            "email" to email,
            "lookupKey" to lookupKey,
            "contactId" to contactId,
        )
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) {
            return super.dispatchKeyEvent(event)
        }
        val wanted = when (cueKind) {
            "volumeUpDouble" -> KeyEvent.KEYCODE_VOLUME_UP
            "volumeDownDouble" -> KeyEvent.KEYCODE_VOLUME_DOWN
            "headsetHook" -> KeyEvent.KEYCODE_HEADSETHOOK
            else -> -1
        }
        if (wanted == -1 || event.keyCode != wanted) {
            return super.dispatchKeyEvent(event)
        }
        val now = android.os.SystemClock.uptimeMillis()
        if (event.keyCode != lastCode || now - lastHitAt > windowMs) {
            hits = 0
        }
        lastCode = event.keyCode
        lastHitAt = now
        hits += 1
        if (hits >= tapCount) {
            hits = 0
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, cueChannel).invokeMethod("fired", null)
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun playStartTone() {
        mainHandler.post {
            val tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 80)
            tone.startTone(ToneGenerator.TONE_PROP_BEEP, 160)
            mainHandler.postDelayed({ tone.release() }, 220)
        }
    }
}
