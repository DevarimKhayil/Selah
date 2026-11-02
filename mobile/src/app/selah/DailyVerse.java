package app.selah;

import android.app.Notification;
import android.app.NotificationManager;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** Today's verse, read from the 60-day plan the web app saves, for notifications and the widget. */
final class DailyVerse {
    static final String CHANNEL = "daily_verse";
    final String reference, text, translation;

    private DailyVerse(String reference, String text, String translation) {
        this.reference = reference; this.text = text; this.translation = translation;
    }

    static String today() { return new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(new Date()); }

    static DailyVerse forToday(Context ctx) {
        SharedPreferences p = ctx.getSharedPreferences("selah", Context.MODE_PRIVATE);
        String tr = p.getString("translation", "Berean Standard Bible");
        try {
            JSONArray plan = new JSONArray(p.getString("plan", "[]"));
            String today = today();
            for (int i = 0; i < plan.length(); i++) {
                JSONObject o = plan.getJSONObject(i);
                if (today.equals(o.optString("date"))) return new DailyVerse(o.optString("reference"), o.optString("text"), tr);
            }
        } catch (Exception ignored) { }
        return null;
    }

    static void showNotification(Context ctx) {
        DailyVerse v = forToday(ctx);
        String title = v == null ? "Verse of the day" : v.reference;
        String body = v == null ? "Open Selah to see today's verse." : "“" + v.text + "”";
        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        Notification.Builder b = new Notification.Builder(ctx);
        if (Build.VERSION.SDK_INT >= 26) {
            try {
                Class<?> chClass = Class.forName("android.app.NotificationChannel");
                // IMPORTANCE_HIGH (4) makes it pop up at the top of the screen like a message.
                Object channel = chClass.getConstructor(String.class, CharSequence.class, int.class).newInstance(CHANNEL, "Verse of the day", 4);
                chClass.getMethod("setDescription", String.class).invoke(channel, "Today's verse each morning");
                NotificationManager.class.getMethod("createNotificationChannel", chClass).invoke(nm, channel);
                Notification.Builder.class.getMethod("setChannelId", String.class).invoke(b, CHANNEL);
            } catch (Exception ignored) { }
        }
        b.setSmallIcon(R.drawable.ic_stat)
         .setContentTitle(title)
         .setContentText(body)
         .setSubText("Verse of the day")
         .setStyle(new Notification.BigTextStyle().bigText(body).setSummaryText(v == null ? "Selah" : "Verse of the day"))
         .setColor(0xFF0F6CBD)
         .setPriority(Notification.PRIORITY_HIGH)
         .setDefaults(Notification.DEFAULT_SOUND | Notification.DEFAULT_VIBRATE)
         .setCategory(Notification.CATEGORY_MESSAGE)
         .setAutoCancel(true)
         .setContentIntent(MainActivity.openAppIntent(ctx, false));
        nm.notify(2, b.build());
    }

    static void updateWidgets(Context ctx) {
        AppWidgetManager m = AppWidgetManager.getInstance(ctx);
        int[] ids = m.getAppWidgetIds(new ComponentName(ctx, VerseWidget.class));
        if (ids != null && ids.length > 0) VerseWidget.update(ctx, m, ids);
    }
}
