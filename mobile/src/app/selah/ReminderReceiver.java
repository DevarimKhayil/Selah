package app.selah;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import java.util.Calendar;

/** Shows the practice notification at 10:00, 12:30, 14:00 and 16:30, and keeps the next alarm scheduled. */
public class ReminderReceiver extends BroadcastReceiver {
    static final int FLAG_IMMUTABLE = 0x04000000;
    static final String ACTION_REMIND = "app.selah.REMIND";
    static final String ACTION_DAILY = "app.selah.DAILY";
    static final String ACTION_MIDNIGHT = "app.selah.MIDNIGHT";
    private static final int[][] TIMES = { { 10, 0 }, { 12, 30 }, { 14, 0 }, { 16, 30 } };
    private static final String CHANNEL = "practice";

    @Override
    public void onReceive(Context ctx, Intent intent) {
        if (intent != null && ACTION_REMIND.equals(intent.getAction())) {
            SharedPreferences p = ctx.getSharedPreferences("selah", Context.MODE_PRIVATE);
            if (p.getBoolean("reminders", true)) show(ctx, p.getString("title", "A moment to remember"), p.getString("body", "Read and memorize today's verse."));
        } else if (intent != null && ACTION_DAILY.equals(intent.getAction())) {
            DailyVerse.updateWidgets(ctx);
            if (ctx.getSharedPreferences("selah", Context.MODE_PRIVATE).getBoolean("dailyOn", true)) DailyVerse.showNotification(ctx);
        }
        DailyVerse.updateWidgets(ctx);
        scheduleNext(ctx);
    }

    static void scheduleNext(Context ctx) {
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        SharedPreferences prefs = ctx.getSharedPreferences("selah", Context.MODE_PRIVATE);
        String[] hm = prefs.getString("dailyTime", "06:30").split(":");
        int dh = 6, dm = 30;
        try { dh = Integer.parseInt(hm[0]); dm = Integer.parseInt(hm[1]); } catch (Exception ignored) { }
        scheduleDaily(ctx, am, ACTION_DAILY, 4, dh, dm);
        scheduleDaily(ctx, am, ACTION_MIDNIGHT, 5, 0, 1);
        Intent i = new Intent(ctx, ReminderReceiver.class);
        i.setAction(ACTION_REMIND);
        PendingIntent pi = PendingIntent.getBroadcast(ctx, 3, i, PendingIntent.FLAG_UPDATE_CURRENT | FLAG_IMMUTABLE);
        am.cancel(pi);
        if (!ctx.getSharedPreferences("selah", Context.MODE_PRIVATE).getBoolean("reminders", true)) return;
        Calendar now = Calendar.getInstance();
        Calendar next = null;
        for (int day = 0; day < 2 && next == null; day++) {
            for (int[] t : TIMES) {
                Calendar c = Calendar.getInstance();
                c.add(Calendar.DAY_OF_YEAR, day);
                c.set(Calendar.HOUR_OF_DAY, t[0]);
                c.set(Calendar.MINUTE, t[1]);
                c.set(Calendar.SECOND, 0);
                c.set(Calendar.MILLISECOND, 0);
                if (c.getTimeInMillis() > now.getTimeInMillis() + 30000) { next = c; break; }
            }
        }
        if (next != null) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.getTimeInMillis(), pi);
    }

    private static void scheduleDaily(Context ctx, AlarmManager am, String action, int code, int hour, int minute) {
        Intent i = new Intent(ctx, ReminderReceiver.class);
        i.setAction(action);
        PendingIntent pi = PendingIntent.getBroadcast(ctx, code, i, PendingIntent.FLAG_UPDATE_CURRENT | FLAG_IMMUTABLE);
        Calendar c = Calendar.getInstance();
        c.set(Calendar.HOUR_OF_DAY, hour);
        c.set(Calendar.MINUTE, minute);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        if (c.getTimeInMillis() <= System.currentTimeMillis() + 5000) c.add(Calendar.DAY_OF_YEAR, 1);
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, c.getTimeInMillis(), pi);
    }

    static void show(Context ctx, String title, String body) {
        NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        Notification.Builder b = new Notification.Builder(ctx);
        if (Build.VERSION.SDK_INT >= 26) {
            try {
                Class<?> chClass = Class.forName("android.app.NotificationChannel");
                Object channel = chClass.getConstructor(String.class, CharSequence.class, int.class).newInstance(CHANNEL, "Practice reminders", 3);
                NotificationManager.class.getMethod("createNotificationChannel", chClass).invoke(nm, channel);
                Notification.Builder.class.getMethod("setChannelId", String.class).invoke(b, CHANNEL);
            } catch (Exception ignored) { }
        }
        b.setSmallIcon(R.drawable.ic_stat)
         .setContentTitle(title)
         .setContentText(body)
         .setStyle(new Notification.BigTextStyle().bigText(body))
         .setColor(0xFF0F6CBD)
         .setAutoCancel(true)
         .setContentIntent(MainActivity.openAppIntent(ctx, true));
        nm.notify(1, b.build());
    }
}
