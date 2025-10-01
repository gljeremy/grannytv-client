@echo off
echo Testing VLC with different caching settings for smooth playback
echo.

set TEST_URL=http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/60b4d6c806ad2a00073b3108/master.m3u8?appName=web^&appVersion=unknown^&clientTime=0^&deviceDNT=0^&deviceId=8e0614c0-1f2c-11ef-86d8-5d587df108c6^&deviceMake=Chrome^&deviceModel=web^&deviceType=web^&deviceVersion=unknown^&includeExtendedEvents=false^&serverSideAds=false^&sid=d329ef28-8c5a-4451-bc8a-ab7d7083f320

echo.
echo [TEST 1] VLC Default Settings (baseline)
echo Press Ctrl+C to stop and try next test
"C:\Program Files\VideoLAN\VLC\vlc.exe" --intf dummy %TEST_URL%
timeout /t 3

echo.
echo [TEST 2] Minimal Optimizations
echo Press Ctrl+C to stop and try next test  
"C:\Program Files\VideoLAN\VLC\vlc.exe" --intf dummy --network-caching=300 --live-caching=50 %TEST_URL%
timeout /t 3

echo.
echo [TEST 3] Balanced Settings
echo Press Ctrl+C to stop when satisfied
"C:\Program Files\VideoLAN\VLC\vlc.exe" --intf dummy --network-caching=500 --live-caching=100 --file-caching=100 --no-drop-late-frames %TEST_URL%

echo.
echo Test complete!