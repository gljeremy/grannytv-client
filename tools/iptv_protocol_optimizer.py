#!/usr/bin/env python3
"""
IPTV Protocol Detection and Optimization Engine
Automatically detects stream protocol and applies optimal VLC configurations
"""

import re
import urllib.parse
from typing import Dict, List

class IPTVProtocolOptimizer:
    def __init__(self):
        self.protocol_patterns = {
            'hls': [
                r'\.m3u8',                    # HLS manifest files
                r'/hls/',                     # HLS path indicator
                r'master\.m3u8',              # Master playlist
                r'playlist\.m3u8',            # Media playlist
                r'index\.m3u8',               # Index playlist
            ],
            'dash': [
                r'\.mpd',                     # DASH manifest
                r'/dash/',                    # DASH path indicator
                r'manifest\.mpd',             # DASH manifest
            ],
            'rtmp': [
                r'^rtmp://',                  # RTMP protocol
                r'^rtmps://',                 # RTMP secure
                r'^rtmpe://',                 # RTMP encrypted
            ],
            'rtsp': [
                r'^rtsp://',                  # RTSP protocol
                r'^rtsps://',                 # RTSP secure
            ],
            'udp': [
                r'^udp://',                   # UDP multicast
                r'@\d+\.\d+\.\d+\.\d+:\d+',  # Multicast address pattern
            ],
            'http_ts': [
                r'\.ts$',                     # Transport Stream
                r'\.ts\?',                    # Transport Stream with params
                r'/mpegts/',                  # MPEG-TS path
            ],
            'http_progressive': [
                r'\.mp4',                     # MP4 progressive
                r'\.mkv',                     # MKV progressive
                r'\.avi',                     # AVI progressive
                r'\.mov',                     # MOV progressive
            ]
        }
        
        # Protocol-specific optimizations
        self.protocol_optimizations = {
            'hls': self._get_hls_optimizations,
            'dash': self._get_dash_optimizations,
            'rtmp': self._get_rtmp_optimizations,
            'rtsp': self._get_rtsp_optimizations,
            'udp': self._get_udp_optimizations,
            'http_ts': self._get_http_ts_optimizations,
            'http_progressive': self._get_progressive_optimizations,
        }
    
    def detect_protocol(self, url: str) -> str:
        """Detect the streaming protocol from URL"""
        url_lower = url.lower()
        
        # Check each protocol pattern
        for protocol, patterns in self.protocol_patterns.items():
            for pattern in patterns:
                if re.search(pattern, url_lower):
                    return protocol
        
        # Fallback based on URL scheme
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme in ['rtmp', 'rtmps', 'rtmpe']:
            return 'rtmp'
        elif parsed.scheme in ['rtsp', 'rtsps']:
            return 'rtsp'
        elif parsed.scheme == 'udp':
            return 'udp'
        elif parsed.scheme in ['http', 'https']:
            return 'http_progressive'  # Default HTTP fallback
        
        return 'unknown'
    
    def get_optimized_vlc_args(self, url: str, vlc_version_info: Dict) -> List[str]:
        """Get optimized VLC arguments for the detected protocol"""
        protocol = self.detect_protocol(url)
        
        if protocol in self.protocol_optimizations:
            return self.protocol_optimizations[protocol](url, vlc_version_info)
        else:
            return self._get_fallback_optimizations(url, vlc_version_info)
    
    def _get_hls_optimizations(self, url: str, vlc_version_info: Dict) -> List[str]:
        """Ultra-optimized HLS configuration with adaptive profiles"""
        args = []
        
        # Detect HLS type for optimal configuration
        hls_type = self._detect_hls_type(url)
        
        if hls_type == 'live':
            # Balanced low latency for live HLS streams (like Pluto TV)
            args.extend([
                '--network-caching=800',      # Balanced HLS caching for smooth playback
                '--live-caching=200',         # Enough buffering to prevent stutters
                '--file-caching=200',         # Smooth file segment loading
            ])
        elif hls_type == 'vod':
            # Optimized for VOD HLS
            args.extend([
                '--network-caching=1000',
                '--live-caching=300',
                '--file-caching=300',
            ])
        else:
            # Default HLS optimizations
            args.extend([
                '--network-caching=600',      
                '--live-caching=150',          
                '--file-caching=150',         # Increased for smoother playback
            ])
        
        # Version-specific HLS enhancements
        if vlc_version_info.get('major', 0) >= 3:
            args.extend([
                '--adaptive-logic=2',         # Aggressive adaptive bitrate
                '--adaptive-bw-up=0.8',       # Quick bitrate increases
                '--adaptive-bw-down=0.2',     # Quick bitrate decreases
                '--hls-segment-threads=4',    # Parallel segment loading
                '--network-timeout=3000',     # Fast timeout (3s)
                '--http-timeout=5000',        # HTTP timeout (5s)
                '--no-audio-time-stretch',    # Prevent audio lag
            ])
        
        # Advanced HLS optimizations for modern VLC
        if vlc_version_info.get('supports_advanced_caching', False):
            args.extend([
                '--clock-jitter=0',           # Eliminate clock jitter
                '--clock-synchro=0',          # Disable sync delays
                '--avcodec-skip-frame=0',     # Don't skip frames
                '--avcodec-skip-idct=0',      # Don't skip IDCT
            ])
        
        # Performance tweaks (less aggressive for smooth playback)
        if vlc_version_info.get('major', 0) >= 3:
            args.extend([
                '--avcodec-threads=0',        # Auto CPU threads
                # Removed aggressive frame dropping for smoother playback
            ])
        
        return args
    
    def _get_dash_optimizations(self, url: str, vlc_version_info: Dict) -> List[str]:
        """DASH-specific optimizations"""
        args = [
            '--network-caching=300',
            '--live-caching=100',
            '--file-caching=100',
        ]
        
        if vlc_version_info.get('major', 0) >= 3:
            args.extend([
                '--adaptive-logic=1',         # Conservative adaptive bitrate
                '--dash-segment-threads=4',   # Parallel segment loading
                '--network-timeout=5000',
                '--http-timeout=8000',
            ])
        
        return args
    
    def _get_rtmp_optimizations(self, url: str, vlc_version_info: Dict) -> List[str]:
        """RTMP-specific optimizations"""
        args = [
            '--network-caching=800',      # Higher caching for RTMP
            '--rtmp-caching=500',         # RTMP-specific caching
            '--no-audio-time-stretch',
        ]
        
        if vlc_version_info.get('major', 0) >= 3:
            args.extend([
                '--rtmp-connect-timeout=10000',
                '--rtmp-seek-threshold=1000',
            ])
        
        return args
    
    def _get_rtsp_optimizations(self, url: str, vlc_version_info: Dict) -> List[str]:
        """RTSP-specific optimizations"""
        args = [
            '--network-caching=600',
            '--rtsp-caching=400',
            '--rtsp-tcp',                 # Use TCP for reliability
            '--no-audio-time-stretch',
        ]
        
        if vlc_version_info.get('major', 0) >= 3:
            args.extend([
                '--rtsp-timeout=10000',
                '--rtsp-frame-buffer-size=50000',
            ])
        
        return args
    
    def _get_udp_optimizations(self, url: str, vlc_version_info: Dict) -> List[str]:
        """UDP multicast optimizations"""
        return [
            '--network-caching=200',      # Low latency for live UDP
            '--udp-caching=100',
            '--live-caching=50',
            '--ts-es-id-pid',             # Elementary stream ID
            '--no-audio-time-stretch',
        ]
    
    def _get_http_ts_optimizations(self, url: str, vlc_version_info: Dict) -> List[str]:
        """HTTP Transport Stream optimizations"""
        return [
            '--network-caching=400',
            '--ts-es-id-pid',
            '--no-audio-time-stretch',
            '--avcodec-fast',
        ]
    
    def _get_progressive_optimizations(self, url: str, vlc_version_info: Dict) -> List[str]:
        """HTTP Progressive download optimizations"""
        return [
            '--network-caching=1000',     # Higher for progressive
            '--file-caching=500',
            '--http-continuous',          # Continuous HTTP
            '--no-audio-time-stretch',
        ]
    
    def _get_fallback_optimizations(self, url: str, vlc_version_info: Dict) -> List[str]:
        """Safe fallback optimizations for unknown protocols"""
        return [
            '--network-caching=1000',
            '--no-audio-time-stretch',
            '--quiet',
        ]
    
    def _detect_hls_type(self, url: str) -> str:
        """Detect if HLS stream is live or VOD"""
        url_lower = url.lower()
        
        # Live stream indicators
        live_indicators = [
            'live', 'channel', 'stream', 'broadcast', 
            'pluto.tv', 'twitch.tv', 'youtube.com/live'
        ]
        
        # VOD indicators  
        vod_indicators = [
            'vod', 'video', 'media', 'content', 'archive',
            '.mp4', '.mkv', 'recorded'
        ]
        
        # Check for live indicators
        for indicator in live_indicators:
            if indicator in url_lower:
                return 'live'
        
        # Check for VOD indicators
        for indicator in vod_indicators:
            if indicator in url_lower:
                return 'vod'
        
        # Default to live for HLS streams (most IPTV is live)
        return 'live'
    
    def get_protocol_info(self, url: str) -> Dict:
        """Get detailed protocol information"""
        protocol = self.detect_protocol(url)
        
        protocol_info = {
            'hls': {
                'name': 'HTTP Live Streaming (HLS)',
                'description': 'Apple\'s adaptive bitrate streaming protocol',
                'latency': 'Low (2-10 seconds)',
                'reliability': 'High',
                'adaptive': True,
            },
            'dash': {
                'name': 'Dynamic Adaptive Streaming (DASH)',
                'description': 'ISO standard adaptive streaming',
                'latency': 'Low (2-10 seconds)', 
                'reliability': 'High',
                'adaptive': True,
            },
            'rtmp': {
                'name': 'Real-Time Messaging Protocol (RTMP)',
                'description': 'Low-latency streaming protocol',
                'latency': 'Very Low (1-3 seconds)',
                'reliability': 'Medium',
                'adaptive': False,
            },
            'rtsp': {
                'name': 'Real-Time Streaming Protocol (RTSP)',
                'description': 'Network control protocol for streaming',
                'latency': 'Very Low (1-3 seconds)',
                'reliability': 'Medium',
                'adaptive': False,
            },
            'udp': {
                'name': 'UDP Multicast',
                'description': 'Low-latency multicast streaming',
                'latency': 'Ultra Low (<1 second)',
                'reliability': 'Low',
                'adaptive': False,
            },
            'http_ts': {
                'name': 'HTTP Transport Stream',
                'description': 'MPEG-TS over HTTP',
                'latency': 'Low (1-5 seconds)',
                'reliability': 'High',
                'adaptive': False,
            },
            'http_progressive': {
                'name': 'HTTP Progressive Download',
                'description': 'Standard HTTP file download',
                'latency': 'Medium (5-15 seconds)',
                'reliability': 'High',
                'adaptive': False,
            }
        }
        
        return protocol_info.get(protocol, {
            'name': 'Unknown Protocol',
            'description': 'Protocol not recognized',
            'latency': 'Unknown',
            'reliability': 'Unknown',
            'adaptive': False,
        })

def main():
    """Test the protocol optimizer"""
    optimizer = IPTVProtocolOptimizer()
    
    # Test URLs for different protocols
    test_urls = [
        "http://example.com/stream/master.m3u8",
        "http://example.com/manifest.mpd", 
        "rtmp://example.com/live/stream",
        "rtsp://example.com:554/stream",
        "udp://239.255.255.250:1234",
        "http://example.com/stream.ts",
        "http://example.com/video.mp4"
    ]
    
    for url in test_urls:
        protocol = optimizer.detect_protocol(url)
        info = optimizer.get_protocol_info(url)
        print(f"URL: {url}")
        print(f"Protocol: {protocol} - {info['name']}")
        print(f"Latency: {info['latency']}")
        print("---")

if __name__ == "__main__":
    main()