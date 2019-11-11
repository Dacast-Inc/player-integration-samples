package com.dacast.dacastandroidsdk;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.AsyncTask;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.View;
import android.widget.ImageView;
import android.widget.RelativeLayout;

import com.google.gson.Gson;
import com.theoplayer.android.api.THEOplayerView;
import com.theoplayer.android.api.source.SourceDescription;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

class DownloadImageTask extends AsyncTask<String, Void, Bitmap> {
    ImageView bmImage;

    public DownloadImageTask(ImageView bmImage) {
        this.bmImage = bmImage;
    }

    protected Bitmap doInBackground(String... urls) {
        String urldisplay = urls[0];
        Bitmap mIcon11 = null;
        try {
            InputStream in = new URL(urldisplay).openStream();
            mIcon11 = BitmapFactory.decodeStream(in);
        } catch (Exception e) {
            Log.e("Error", e.getMessage());
            e.printStackTrace();
        }
        return mIcon11;
    }

    protected void onPostExecute(Bitmap result) {
        bmImage.setImageBitmap(result);
    }
}

class ContentId{
    public int broadcasterId, mediaId;
    public String contentType;

    private ContentId(){}

    public static ContentId parse(String contentIdStr) throws Exception{
        ContentId contentId = new ContentId();

        String[] split = contentIdStr.split("_", 3);
        contentId.broadcasterId = Integer.parseInt(split[0]);
        contentId.mediaId = Integer.parseInt(split[2]);

        if(!split[1].equals("c") && !split[1].equals("f") && !split[1].equals("l") && !split[1].equals("p")){
            throw new Exception("invalid content type: " + split[1]);
        }
        contentId.contentType = split[1];

        return contentId;
    }
}

class ContentInfo{
    public String m3u8Link;
    public String posterLink;
    public String adUrl;

    public ContentInfo(JsonResponse json, ServiceResponse service, String adUrl){
        this.m3u8Link = json.hls + service.token;
        this.posterLink = json.stream.splash;
        this.adUrl = adUrl;
    }
}

class JsonResponse{
    String hls;
    JsonResponseStream stream;
    JsonResponseTheme theme;
}

class JsonResponseTheme{
    JsonResponseWatermark watermark;
}

class JsonResponseWatermark{
    String url;
}

class JsonResponseStream{
    String splash;
}

class ServiceResponse{
    String token;
}

class PlayerHandler extends Handler {
    public static final int SET_CONTENT_INFO = 1;

    THEOplayerView theoplayer;

    public PlayerHandler(THEOplayerView theoplayer){
        this.theoplayer = theoplayer;
    }

    @Override
    public void handleMessage(Message msg) {
        switch (msg.what){
            case SET_CONTENT_INFO:
                ContentInfo contentInfo = (ContentInfo)msg.obj;
                SourceDescription.Builder sourceDescription = SourceDescription.Builder.sourceDescription(contentInfo.m3u8Link)
                        .poster(contentInfo.posterLink);

                if(contentInfo.adUrl != null){
                    sourceDescription.ads(contentInfo.adUrl);
                }

                theoplayer.getPlayer().setSource(sourceDescription.build());
                break;
        }
    }
}

public class DacastPlayer {

    private static String TAG = "DacastPlayer";
    private static String JSON_URL_BASE = "https://json.dacast.com/b/";
    private static String SERVICE_URL_BASE = "https://services.dacast.com/token/i/b/";

    private THEOplayerView theoplayer;
    private PlayerHandler handler;
    private RelativeLayout layout;
    private ImageView watermarkImage;

    public DacastPlayer(Activity activity, String contentIdStr) {
        this(activity, contentIdStr, null);
    }

    public DacastPlayer(Activity activity, String contentIdStr, String adUrl) {
        theoplayer = new THEOplayerView(activity);
        handler = new PlayerHandler(theoplayer);
        watermarkImage = new ImageView(activity);
        layout = new RelativeLayout(activity);

        watermarkImage.setClickable(false);
        watermarkImage.setFocusable(false);

        RelativeLayout.LayoutParams paramsPlayer = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        paramsPlayer.leftMargin = 0;
        paramsPlayer.topMargin = 0;
        layout.addView(theoplayer, paramsPlayer);

        RelativeLayout.LayoutParams paramsImage = new RelativeLayout.LayoutParams(300, 300);
        paramsImage.leftMargin = 50;
        paramsImage.topMargin = 10;
        layout.addView(watermarkImage, paramsImage);
        watermarkImage.setImageAlpha(90);


        ContentId contentId;
        try {
            contentId = ContentId.parse(contentIdStr);
        } catch (Exception e) {
            e.printStackTrace();
            Log.v(TAG, "Invalid content id provided: " + contentIdStr);
            return;
        }
        fetchVideoInfo(contentId, adUrl);
    }

    public View getView(){
        return layout;
    }

    public THEOplayerView getTHEOplayer(){
        return theoplayer;
    }

    public void onPause() {
        theoplayer.onPause();
    }

    public void onResume() {
        theoplayer.onResume();
    }

    public void onDestroy() {
        theoplayer.onDestroy();
    }

    private void fetchVideoInfo(final ContentId contentId, final String adUrl){
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    String rawJson = httpGet( JSON_URL_BASE + contentId.broadcasterId + "/" + contentId.contentType + "/" + contentId.mediaId);
                    String rawToken = httpGet(SERVICE_URL_BASE + contentId.broadcasterId + "/" + contentId.contentType + "/" + contentId.mediaId);

                    Gson gson = new Gson();
                    JsonResponse json = gson.fromJson(rawJson, JsonResponse.class);
                    ServiceResponse token = gson.fromJson(rawToken, ServiceResponse.class);

                    ContentInfo contentInfo = new ContentInfo(json, token, adUrl);
                    handler.sendMessage(handler.obtainMessage(PlayerHandler.SET_CONTENT_INFO, contentInfo));

                    if(json.theme.watermark.url != null){
                        new DownloadImageTask(watermarkImage)
                                .execute("https:" + json.theme.watermark.url);
                    }

                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }).start();
    }

    private static String httpGet(String urlToRead) throws Exception {
        StringBuilder result = new StringBuilder();
        URL url = new URL(urlToRead);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        BufferedReader rd = new BufferedReader(new InputStreamReader(conn.getInputStream()));
        String line;
        while ((line = rd.readLine()) != null) {
            result.append(line);
        }
        rd.close();
        return result.toString();
    }
}
