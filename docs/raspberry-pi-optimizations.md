# Raspberry Pi IPTV Streaming Optimizations

## Problem Addressed
Stuttery video playback on Raspberry Pi due to aggressive caching and processing settings designed for more powerful hardware.

## Pi-Specific Optimizations Applied

### 1. **Hardware-Aware Caching**
- `--network-caching=2000` (generous buffering for Pi's slower processing)
- `--live-caching=300` (good live buffer to prevent stutters)  
- `--file-caching=300` (smooth segment loading)
- Much more conservative than the 30-150ms used for other platforms

### 2. **CPU and Threading Limits**
- `--threads=2` (limit to 2 threads for Pi CPU)
- `--avcodec-threads=2` (limit codec threads)
- Prevents CPU overload that causes stuttering

### 3. **Adaptive Streaming**
- `--adaptive-logic=1` (conservative adaptive bitrate)
- `--clock-jitter=0` (eliminate timing jitter)
- `--no-audio-time-stretch` (prevent audio lag)

### 4. **Smart Hardware Decode**
- Automatically detects GPU memory split
- Uses MMAL hardware decode only if GPU memory >= 128MB
- Falls back to software decode for low memory configurations
- `--avcodec-hw=mmal` or `--avcodec-hw=none` based on available memory

### 5. **Conservative Frame Processing**
- `--avcodec-skiploopfilter=nonkey` (skip some post-processing to save CPU)
- No aggressive frame dropping (which causes stutters on Pi)
- Prioritizes smooth playback over ultra-low latency

### 6. **Pi-Optimized VLC Configurations**

#### With X11 Desktop:
1. Conservative X11 with `--no-embedded-video`
2. Software fallback with `--avcodec-hw=none`
3. Basic X11 minimal options

#### Framebuffer Mode (Headless):
1. Conservative framebuffer without deinterlacing (saves CPU)
2. Minimal framebuffer configuration

### 7. **GPU Memory Detection**
- Automatically checks GPU memory split with `vcgencmd`
- Logs recommendations if GPU memory < 128MB
- Adapts hardware decode usage based on available memory

## Before vs After

**Before (Stuttery):**
- Used same aggressive settings as desktop Linux
- 30-150ms caching (too low for Pi)
- Aggressive frame dropping
- Hardware decode regardless of GPU memory
- Full deinterlacing processing

**After (Smooth):**
- Pi-specific conservative settings
- 2000ms network caching (smooth for Pi)
- Limited threading (2 threads max)
- Smart hardware decode based on GPU memory
- Minimal post-processing

## Expected Results
- **Smooth, fluid video playback** without stuttering
- **Adaptive quality** based on Pi model and GPU memory
- **Stable streaming** with proper buffering for Pi's processing speed
- **Good performance** even on older Pi models (Pi 3, etc.)

## Performance Notes
- Pi 4 with 128MB+ GPU memory: Best performance with MMAL hardware decode
- Pi 3 or low GPU memory: Software decode with optimized settings
- Works with both desktop (X11) and headless (framebuffer) configurations
- Automatically adapts to hardware capabilities