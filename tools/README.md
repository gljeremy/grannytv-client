# Performance Tools & System Optimization ⚡

Advanced diagnostic and optimization utilities for MPV-based ultra-low latency IPTV streaming.

## 📄 Files

### Core Analysis Tools
- **`iptv_protocol_optimizer.py`** - Universal IPTV protocol detection & optimization
- **`stream_performance_analyzer.py`** - Stream latency testing & database optimization  
- **`performance-monitor.py`** - Real-time system performance monitoring

### System Optimization
- **`network-optimize.sh`** - Network optimization for streaming performance
- **`gpu-optimize.sh`** - GPU and video acceleration optimization for Pi

### MPV Configuration Testing
- **`batch_test_variants.sh`** - Batch test multiple MPV configuration variants
- **`quick_test_config.sh`** - Quick test individual MPV variants (1-20)
- **`benchmark_mpv_configs.sh`** - Benchmark MPV configurations for performance
- **`test_mpv_configs.sh`** - Test MPV config variations
- **`test_single_config.sh`** - Test a single MPV configuration
- **`test_buffering_fix.sh`** - Test buffering optimizations

## 🚀 Quick Performance Setup

For maximum MPV-based streaming performance, run in this order:

```bash
# 1. System optimization (requires sudo)
sudo ./tools/network-optimize.sh
sudo ./tools/gpu-optimize.sh

# 2. Analyze and optimize stream performance  
python3 ./tools/stream_performance_analyzer.py

# 3. Optimize protocol configurations
python3 ./tools/iptv_protocol_optimizer.py

# 4. Monitor system performance
python3 ./tools/performance-monitor.py --check-only
```

## 🎯 MPV Configuration Testing

Test and find the optimal MPV configuration for your setup:

```bash
# Quick test a specific variant (1-20)
./tools/quick_test_config.sh 14

# Batch test multiple variants to find the best
./tools/batch_test_variants.sh 30 14 15 16

# Benchmark different configurations
./tools/benchmark_mpv_configs.sh

# Test buffering optimizations
./tools/test_buffering_fix.sh
```

**Current Optimal Configuration:** Variant 14 (Balanced optimization)
- cache-secs=3
- demuxer-max-bytes=25M
- demuxer-readahead-secs=3

## 🎬 MPV Performance System

**Platform-Aware MPV Optimization:**

The player automatically detects your platform and applies optimized MPV configurations:

**Platform-Specific Features:**
- **Raspberry Pi:** Balanced settings (Variant 14), 3-second cache, software decode
- **Desktop/Windows:** Same balanced config for consistency
- **Hardware acceleration:** Software decode for maximum stability

**Smart Performance Adaptation:**
- Pi hardware detection with GPU memory checking
- Variant-based configuration system (20 tested variants)
- Cross-platform consistency with platform-specific optimizations
- MPV process monitoring with automatic restart on failure

## 🔧 Individual Tool Usage

### Stream Analysis & Optimization
```bash
# Analyze stream performance and create optimized database
python3 ./tools/stream_performance_analyzer.py

# Test protocol detection and optimization
python3 ./tools/iptv_protocol_optimizer.py
```

### MPV Configuration Testing
```bash
# Interactive variant selection (1-20)
./tools/quick_test_config.sh

# Test specific variant with custom stream
./tools/quick_test_config.sh 14 "http://stream-url" 60

# Batch test multiple variants
./tools/batch_test_variants.sh 30 1 3 8 14 15

# Benchmark configurations
./tools/benchmark_mpv_configs.sh
```

### Performance Monitoring
```bash
# Quick system check
python3 ./tools/performance-monitor.py --check-only

# Monitor for 60 minutes
python3 ./tools/performance-monitor.py --duration 60
```

### System Optimization
```bash
# Optimize network settings for streaming
sudo ./tools/network-optimize.sh

# Configure GPU acceleration for Raspberry Pi
sudo ./tools/gpu-optimize.sh
```

## ⚡ Performance Optimizations

### MPV Variant System
- **20 tested variants:** From minimal (Variant 17) to performance (Variant 15)
- **Balanced optimization (Variant 14):** Current best-in-class configuration
- **Protocol detection:** Automatic detection of HLS, DASH, RTMP, RTSP, UDP streams
- **Stream ranking:** Performance-based stream selection (fastest first)
- **CDN optimization:** Provider-specific optimizations (Pluto, Cloudflare, etc.)

### Ultra Low-Latency Features
- **Stream latency:** Optimized caching and buffering for smooth playback
- **Network caching:** Variant-based (1-5 seconds depending on configuration)
- **Process priority:** MPV runs with optimized settings
- **Hardware considerations:** Software decode for maximum stability on Pi

### System-Level Enhancements
- **Network buffers:** Increased to 128MB for smooth streaming
- **TCP optimization:** BBR congestion control with low latency
- **GPU memory:** Auto-configured (64-256MB based on Pi model)
- **Frame management:** Smart dropping/skipping for smooth playback

## 📊 Expected Performance Results

After applying all optimizations (using Variant 14):
- **Startup time:** ~2-3 seconds to video
- **CPU usage:** 25-40% during streaming (30-50% less than VLC)
- **Memory usage:** ~150MB (25% less than VLC)
- **Network throughput:** Enhanced for HD+ streams
- **Stability:** Software decode, crash-resistant playback
- **Cache efficiency:** 3-second buffer with 25M demuxer buffer