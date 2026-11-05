package com.gym.app.gym

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Po restarcie telefonu (albo aktualizacji apki) flutter_local_notifications
 * przywraca zaplanowane powiadomienia z własnej pamięci. Jednorazowe
 * powiadomienie, którego czas już minął, odpala się wtedy od razu. Dla końca
 * przerwy (pełnoekranowy alarm) oznacza to, że apka wyskakuje na ekranie
 * blokady zaraz po starcie telefonu.
 *
 * Dlatego najpierw wyrzucamy takie przeterminowane jednorazowe powiadomienia,
 * a dopiero potem oddajemy resztę (np. cotygodniowe przypomnienia o
 * treningu) do zwykłego przywracania przez wtyczkę.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                try {
                    dropExpiredOneShotNotifications(context)
                } catch (e: Exception) {
                    Log.w(TAG, "Nie udało się wyczyścić starych powiadomień", e)
                }
                ScheduledNotificationBootReceiver().onReceive(context, intent)
            }
        }
    }

    private fun dropExpiredOneShotNotifications(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(PREFS_KEY, null) ?: return
        val all = JSONArray(json)
        val kept = JSONArray()
        val now = System.currentTimeMillis()
        for (i in 0 until all.length()) {
            val item = all.getJSONObject(i)
            if (isOneShot(item) && isExpired(item, now)) continue
            kept.put(item)
        }
        if (kept.length() != all.length()) {
            prefs.edit().putString(PREFS_KEY, kept.toString()).commit()
        }
    }

    /** Powtarzalne powiadomienia wtyczka sama przesuwa na kolejny termin. */
    private fun isOneShot(item: JSONObject): Boolean =
        REPEAT_FIELDS.none { item.has(it) && !item.isNull(it) }

    private fun isExpired(item: JSONObject, now: Long): Boolean {
        val date = item.optString("scheduledDateTime", "")
        val zone = item.optString("timeZoneName", "")
        if (date.isEmpty() || zone.isEmpty()) return false
        val at = LocalDateTime.parse(date).atZone(ZoneId.of(zone)).toInstant().toEpochMilli()
        return at <= now
    }

    private companion object {
        const val TAG = "GymBootReceiver"

        // Nazwy z flutter_local_notifications (FlutterLocalNotificationsPlugin
        // i pola NotificationDetails zapisywane przez Gson).
        const val PREFS_NAME = "scheduled_notifications"
        const val PREFS_KEY = "scheduled_notifications"
        val REPEAT_FIELDS = listOf(
            "repeatInterval",
            "repeatIntervalMilliseconds",
            "matchDateTimeComponents",
            "scheduledNotificationRepeatFrequency",
        )
    }
}
