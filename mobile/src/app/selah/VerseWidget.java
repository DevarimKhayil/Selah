package app.selah;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.os.Bundle;
import android.util.TypedValue;
import android.widget.RemoteViews;

/** Home screen widget showing the verse of the day. */
public class VerseWidget extends AppWidgetProvider {
    @Override
    public void onUpdate(Context ctx, AppWidgetManager m, int[] ids) {
        update(ctx, m, ids);
        ReminderReceiver.scheduleNext(ctx);
    }

    @Override
    public void onAppWidgetOptionsChanged(Context ctx, AppWidgetManager m, int id, Bundle options) {
        update(ctx, m, new int[] { id });
    }

    /** Largest text size (sp) that lets the whole verse fit the widget's current size. */
    static float fitTextSize(String text, int widthDp, int heightDp) {
        if (widthDp <= 0) widthDp = 250;
        if (heightDp <= 0) heightDp = 110;
        float usableW = widthDp - 40;          // side padding
        float usableH = heightDp - 64;         // label, reference and padding
        int len = text.length();
        for (float sp = 17f; sp >= 9f; sp -= 0.5f) {
            float charsPerLine = usableW / (sp * 0.52f);
            int lines = (int) Math.ceil(len / Math.max(8f, charsPerLine)) + 1;
            if (lines * sp * 1.32f <= usableH) return sp;
        }
        return 9f;
    }

    static void update(Context ctx, AppWidgetManager m, int[] ids) {
        DailyVerse v = DailyVerse.forToday(ctx);
        for (int id : ids) {
            RemoteViews rv = new RemoteViews(ctx.getPackageName(), R.layout.widget_verse);
            Bundle o = m.getAppWidgetOptions(id);
            // Use the smaller (portrait) height so the verse fits in both orientations.
            int w = o == null ? 0 : o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH);
            int h = o == null ? 0 : o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT);
            if (v != null) {
                String body = "\u201C" + v.text + "\u201D";
                rv.setTextViewText(R.id.verse_text, body);
                rv.setTextViewTextSize(R.id.verse_text, TypedValue.COMPLEX_UNIT_SP, fitTextSize(body, w, h));
                rv.setTextViewText(R.id.verse_ref, v.reference);
                rv.setTextViewText(R.id.verse_label, "VERSE OF THE DAY  ·  " + (v.translation.startsWith("King") ? "KJV" : "BSB"));
            } else {
                rv.setTextViewText(R.id.verse_text, "Open Selah once to load your verses.");
                rv.setTextViewText(R.id.verse_ref, "Selah");
                rv.setTextViewText(R.id.verse_label, "VERSE OF THE DAY");
            }
            rv.setOnClickPendingIntent(R.id.widget_root, MainActivity.openAppIntent(ctx, false));
            m.updateAppWidget(id, rv);
        }
    }
}
