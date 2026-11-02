package app.selah;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.print.PrintManager;
import android.view.View;
import android.view.Window;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;

/** Selah for Android: hosts the offline web app and bridges reminders, printing and files. */
public class MainActivity extends Activity {
    static final String EXTRA_REMINDER = "app.selah.REMINDER";
    private static final int REQ_SAVE = 41, REQ_OPEN = 42, REQ_NOTIFY = 43;
    private WebView web;
    private WebView printView;
    private String pendingSaveText;
    private boolean pendingReminder;
    private boolean darkTheme;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        darkTheme = getSharedPreferences("selah", MODE_PRIVATE).getBoolean("dark", false);
        applyBars();
        web = new WebView(this);
        web.setBackgroundColor(darkTheme ? Color.rgb(15, 18, 23) : Color.rgb(243, 245, 250));
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowFileAccessFromFileURLs(true);
        s.setTextZoom(100);
        web.setWebChromeClient(new WebChromeClient());
        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                if (url.startsWith("file:")) return false;
                openExternal(url);
                return true;
            }
            // API 24+ variant (no @Override because this build compiles against API 23)
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return shouldOverrideUrlLoading(view, request.getUrl().toString());
            }
        });
        web.addJavascriptInterface(new Bridge(), "SelahAndroid");
        pendingReminder = getIntent() != null && getIntent().getBooleanExtra(EXTRA_REMINDER, false);
        setContentView(web);
        web.loadUrl("file:///android_asset/www/index.html");
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        if (intent != null && intent.getBooleanExtra(EXTRA_REMINDER, false) && web != null) {
            web.evaluateJavascript("window.Selah && Selah.onReminder && Selah.onReminder()", null);
        }
    }

    @Override
    public void onBackPressed() {
        web.evaluateJavascript("(window.Selah && Selah.back) ? Selah.back() : false", new ValueCallback<String>() {
            public void onReceiveValue(String value) {
                if (!"true".equals(value)) moveTaskToBack(true);
            }
        });
    }

    private void applyBars() {
        Window w = getWindow();
        int bar = darkTheme ? Color.rgb(22, 26, 33) : Color.rgb(246, 248, 252);
        w.setStatusBarColor(bar);
        w.setNavigationBarColor(bar);
        View decor = w.getDecorView();
        int flags = decor.getSystemUiVisibility();
        if (darkTheme) flags &= ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
        else flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
        if (Build.VERSION.SDK_INT >= 26) {
            int lightNav = 0x00000010; // View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            if (darkTheme) flags &= ~lightNav; else flags |= lightNav;
        }
        decor.setSystemUiVisibility(flags);
    }

    private void openExternal(String url) {
        try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))); }
        catch (Exception e) { Toast.makeText(this, "No browser found to open the link.", Toast.LENGTH_SHORT).show(); }
    }

    private void askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission("android.permission.POST_NOTIFICATIONS") != 0) {
            requestPermissions(new String[] { "android.permission.POST_NOTIFICATIONS" }, REQ_NOTIFY);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != RESULT_OK || data == null || data.getData() == null) return;
        Uri uri = data.getData();
        if (requestCode == REQ_SAVE && pendingSaveText != null) {
            try {
                OutputStream out = getContentResolver().openOutputStream(uri);
                out.write(pendingSaveText.getBytes("UTF-8"));
                out.close();
                Toast.makeText(this, "Backup saved", Toast.LENGTH_SHORT).show();
            } catch (Exception e) {
                Toast.makeText(this, "Could not save the file.", Toast.LENGTH_LONG).show();
            }
            pendingSaveText = null;
        } else if (requestCode == REQ_OPEN) {
            try {
                InputStream in = getContentResolver().openInputStream(uri);
                BufferedReader reader = new BufferedReader(new InputStreamReader(in, "UTF-8"));
                StringBuilder sb = new StringBuilder();
                char[] buf = new char[8192];
                int n;
                while ((n = reader.read(buf)) > 0) sb.append(buf, 0, n);
                reader.close();
                String js = "Selah.onFileOpened(" + jsString(sb.toString()) + ", " + jsString(uri.getLastPathSegment() == null ? "" : uri.getLastPathSegment()) + ")";
                web.evaluateJavascript(js, null);
            } catch (Exception e) {
                Toast.makeText(this, "Could not read that file.", Toast.LENGTH_LONG).show();
            }
        }
    }

    static String jsString(String s) {
        StringBuilder b = new StringBuilder("\"");
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"': b.append("\\\""); break;
                case '\\': b.append("\\\\"); break;
                case '\n': b.append("\\n"); break;
                case '\r': b.append("\\r"); break;
                case '\t': b.append("\\t"); break;
                default:
                    if (c < 0x20 || c == 0x2028 || c == 0x2029) b.append(String.format("\\u%04x", (int) c));
                    else b.append(c);
            }
        }
        return b.append('"').toString();
    }

    /** Methods called from JavaScript as window.SelahAndroid.* */
    class Bridge {
        @JavascriptInterface
        public void openUrl(final String url) {
            runOnUiThread(new Runnable() { public void run() { openExternal(url); } });
        }

        @JavascriptInterface
        public boolean consumeReminder() {
            boolean r = pendingReminder;
            pendingReminder = false;
            return r;
        }

        @JavascriptInterface
        public void setDarkTheme(final boolean dark) {
            runOnUiThread(new Runnable() { public void run() {
                darkTheme = dark;
                getSharedPreferences("selah", MODE_PRIVATE).edit().putBoolean("dark", dark).apply();
                applyBars();
            } });
        }

        @JavascriptInterface
        public void scheduleReminders(final boolean enabled, final String title, final String body) {
            runOnUiThread(new Runnable() { public void run() {
                SharedPreferences.Editor e = getSharedPreferences("selah", MODE_PRIVATE).edit();
                e.putBoolean("reminders", enabled).putString("title", title).putString("body", body).apply();
                if (enabled) askNotificationPermission();
                ReminderReceiver.scheduleNext(MainActivity.this);
            } });
        }

        @JavascriptInterface
        public void setDailyPlan(final String json, final String translation) {
            getSharedPreferences("selah", MODE_PRIVATE).edit().putString("plan", json).putString("translation", translation).apply();
            runOnUiThread(new Runnable() { public void run() { DailyVerse.updateWidgets(MainActivity.this); } });
        }

        @JavascriptInterface
        public void setDailySchedule(final boolean enabled, final String time) {
            runOnUiThread(new Runnable() { public void run() {
                getSharedPreferences("selah", MODE_PRIVATE).edit().putBoolean("dailyOn", enabled).putString("dailyTime", time).apply();
                if (enabled) askNotificationPermission();
                ReminderReceiver.scheduleNext(MainActivity.this);
            } });
        }

        @JavascriptInterface
        public void testDailyNotification() {
            runOnUiThread(new Runnable() { public void run() {
                askNotificationPermission();
                DailyVerse.showNotification(MainActivity.this);
            } });
        }

        @JavascriptInterface
        public void printHtml(final String html, final String name) {
            runOnUiThread(new Runnable() { public void run() {
                printView = new WebView(MainActivity.this);
                printView.setWebViewClient(new WebViewClient() {
                    @Override
                    public void onPageFinished(WebView view, String url) {
                        PrintManager pm = (PrintManager) getSystemService(Context.PRINT_SERVICE);
                        pm.print(name, view.createPrintDocumentAdapter(name), null);
                    }
                });
                printView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null);
            } });
        }

        @JavascriptInterface
        public void saveTextFile(final String name, final String mime, final String text) {
            runOnUiThread(new Runnable() { public void run() {
                pendingSaveText = text;
                Intent i = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                i.addCategory(Intent.CATEGORY_OPENABLE);
                i.setType(mime);
                i.putExtra(Intent.EXTRA_TITLE, name);
                try { startActivityForResult(i, REQ_SAVE); }
                catch (Exception ex) { Toast.makeText(MainActivity.this, "No file picker available.", Toast.LENGTH_LONG).show(); }
            } });
        }

        @JavascriptInterface
        public void openTextFile() {
            runOnUiThread(new Runnable() { public void run() {
                Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                i.addCategory(Intent.CATEGORY_OPENABLE);
                i.setType("*/*");
                try { startActivityForResult(i, REQ_OPEN); }
                catch (Exception ex) { Toast.makeText(MainActivity.this, "No file picker available.", Toast.LENGTH_LONG).show(); }
            } });
        }
    }

    static PendingIntent openAppIntent(Context ctx, boolean reminder) {
        Intent i = new Intent(ctx, MainActivity.class);
        i.putExtra(EXTRA_REMINDER, reminder);
        i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(ctx, reminder ? 7 : 8, i, PendingIntent.FLAG_UPDATE_CURRENT | ReminderReceiver.FLAG_IMMUTABLE);
    }
}
