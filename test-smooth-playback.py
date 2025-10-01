#!/usr/bin/env python3
"""
VLC Settings Test Script for Windows
Tests different caching combinations to find the smoothest playback
"""

import subprocess
import time
import os

# Test stream (one of your fastest)
TEST_STREAM = "http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/60b4d6c806ad2a00073b3108/master.m3u8?appName=web&appVersion=unknown&clientTime=0&deviceDNT=0&deviceId=8e0614c0-1f2c-11ef-86d8-5d587df108c6&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false&sid=d329ef28-8c5a-4451-bc8a-ab7d7083f320"

VLC_PATH = r"C:\Program Files\VideoLAN\VLC\vlc.exe"

test_configs = [
    {
        "name": "VLC Default (No custom caching)",
        "args": [VLC_PATH, "--intf", "dummy", "--play-and-exit", TEST_STREAM]
    },
    {
        "name": "Minimal Caching (Low latency)",
        "args": [VLC_PATH, "--intf", "dummy", "--network-caching=300", "--live-caching=50", "--file-caching=50", "--play-and-exit", TEST_STREAM]
    },
    {
        "name": "Balanced Caching (Current settings)",
        "args": [VLC_PATH, "--intf", "dummy", "--network-caching=500", "--live-caching=100", "--file-caching=100", "--clock-jitter=0", "--no-drop-late-frames", "--play-and-exit", TEST_STREAM]
    },
    {
        "name": "Conservative Caching (Smooth playback focus)",
        "args": [VLC_PATH, "--intf", "dummy", "--network-caching=1000", "--live-caching=200", "--file-caching=200", "--play-and-exit", TEST_STREAM]
    },
    {
        "name": "Windows Optimized",
        "args": [VLC_PATH, "--intf", "dummy", "--network-caching=800", "--live-caching=150", "--file-caching=150", "--aout", "directsound", "--vout", "directx", "--no-video-title-show", "--play-and-exit", TEST_STREAM]
    }
]

def test_vlc_config(config):
    print(f"\n{'='*50}")
    print(f"Testing: {config['name']}")
    print(f"{'='*50}")
    print("Command:", " ".join(config['args']))
    print("\nStarting VLC... Watch for smooth playback!")
    print("Press Ctrl+C to stop this test and move to next")
    print("-" * 50)
    
    try:
        process = subprocess.Popen(config['args'])
        process.wait()  # Wait for VLC to finish
        print(f"✅ {config['name']} completed successfully")
    except KeyboardInterrupt:
        print(f"\n⏹️ {config['name']} stopped by user")
        try:
            process.terminate()
            time.sleep(1)
            if process.poll() is None:
                process.kill()
        except:
            pass
    except Exception as e:
        print(f"❌ {config['name']} failed: {e}")

def main():
    print("🎬 VLC Settings Test for Smooth IPTV Playback")
    print("=" * 60)
    print("This script will test different VLC caching settings.")
    print("Watch each test and note which one has the smoothest playback.")
    print("Press Ctrl+C to skip to the next test.")
    print("\nStream: Wild Side TV (Pluto TV)")
    
    input("\nPress Enter to start testing...")
    
    for i, config in enumerate(test_configs, 1):
        print(f"\n🔄 Test {i}/{len(test_configs)}")
        test_vlc_config(config)
        
        if i < len(test_configs):
            choice = input(f"\nContinue to next test? (y/n): ").lower()
            if choice == 'n':
                break
    
    print("\n🎯 Test Results Summary:")
    print("=" * 40)
    print("Which test had the smoothest playback?")
    print("1. VLC Default")
    print("2. Minimal Caching") 
    print("3. Balanced Caching (current)")
    print("4. Conservative Caching")
    print("5. Windows Optimized")
    
    choice = input("\nEnter the number of the best performing test (1-5): ")
    
    recommendations = {
        "1": "Use VLC defaults - remove custom caching from the player",
        "2": "Use minimal caching: --network-caching=300 --live-caching=50 --file-caching=50", 
        "3": "Keep current balanced settings",
        "4": "Use conservative caching: --network-caching=1000 --live-caching=200 --file-caching=200",
        "5": "Use Windows optimized: --network-caching=800 --live-caching=150 --file-caching=150 --aout directsound --vout directx"
    }
    
    if choice in recommendations:
        print(f"\n✅ Recommendation: {recommendations[choice]}")
    else:
        print("\n💡 Try testing again or use VLC defaults for now")

if __name__ == "__main__":
    main()