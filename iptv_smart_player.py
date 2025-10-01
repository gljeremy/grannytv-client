#!/usr/bin/env python3
import subprocess
import time
import os
import sys
import signal
import logging
import json
from datetime import datetime
import platform

# Import protocol optimizer
tools_path = os.path.join(os.path.dirname(__file__), 'tools')
if tools_path not in sys.path:
    sys.path.append(tools_path)

try:
    from iptv_protocol_optimizer import IPTVProtocolOptimizer  # noqa: F401
except ImportError:
    # Fallback if optimizer not available
    class IPTVProtocolOptimizer:
        def detect_protocol(self, url): return 'unknown'
        def get_optimized_vlc_args(self, url, vlc_info): return []
        def get_protocol_info(self, url): return {
            'name': 'Unknown Protocol',
            'description': 'Protocol not recognized',
            'latency': 'Unknown',
            'reliability': 'Unknown',
            'adaptive': False,
        }

def load_config():
    """Load configuration based on environment"""
    config_file = os.path.join(os.path.dirname(__file__), 'config.json')
    
    try:
        with open(config_file, 'r') as f:
            configs = json.load(f)
        
        # Detect environment
        if platform.system() == 'Windows' or os.getenv('IPTV_ENV') == 'development':
            return configs['development']
        else:
            return configs['production']
    except Exception:
        # Fallback to production config
        return {
            "platform": "raspberry_pi",
            "base_path": "/home/jeremy/gtv",
            "log_file": "/home/jeremy/gtv/iptv_player.log",
            "working_streams_file": "/home/jeremy/gtv/working_streams.json",
            "use_vlc": True,
            "test_mode": False,
            "display": {"setup_display": True, "setup_audio": True},
            "player_command": "vlc --intf dummy --play-and-exit --no-video-title-show --fullscreen"
        }

# Load configuration
CONFIG = load_config()

# Configure logging with Windows-safe encoding
log_handlers = [logging.StreamHandler(sys.stdout)]
try:
    log_handlers.append(logging.FileHandler(CONFIG['log_file'], encoding='utf-8'))
except Exception:
    # Fallback for Windows
    log_handlers.append(logging.FileHandler(CONFIG['log_file']))

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=log_handlers
)

class SmartIPTVPlayer:
    def __init__(self):
        self.config = CONFIG
        self.working_streams_file = os.path.join(self.config['base_path'], 'working_streams.json')
        self.working_streams = {}
        self.current_process = None
        self.current_stream = None
        self.running = True
        self.stream_start_time = None  # Track performance metrics
        self.vlc_version_info = None  # VLC version and compatibility info
        self.protocol_optimizer = IPTVProtocolOptimizer()  # Protocol optimization engine
        
        # Backup streams if no working streams found
        self.backup_streams = [
            "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
        ]
        
        logging.info(f"[SETUP] Running in {self.config['platform']} mode")
        self.detect_vlc_version()
        self.load_working_streams()

    def check_x11_available(self):
        """Check if X11 is available"""
        try:
            subprocess.run(['xset', 'q'], check=True, 
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False

    def find_vlc_executable(self):
        """Find VLC executable path for the current platform"""
        if platform.system() == 'Windows':
            # Common Windows VLC installation paths
            windows_paths = [
                r"C:\Program Files\VideoLAN\VLC\vlc.exe",
                r"C:\Program Files (x86)\VideoLAN\VLC\vlc.exe",
                "vlc"  # Fallback to PATH
            ]
            for path in windows_paths:
                if os.path.exists(path):
                    return path
            return "vlc"  # Final fallback
        else:
            return "vlc"  # Linux/Mac use PATH

    def detect_vlc_version(self):
        """Detect VLC version and set compatibility flags"""
        vlc_cmd = self.find_vlc_executable()
        try:
            result = subprocess.run([vlc_cmd, '--version'], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version_output = result.stdout.strip()
                version_line = version_output.split('\n')[0] if version_output else ""
                
                # Extract version number (e.g., "VLC media player 3.0.18")
                import re
                version_match = re.search(r'VLC.*?(\d+\.\d+\.\d+)', version_line)
                if version_match:
                    version_str = version_match.group(1)
                    version_parts = [int(x) for x in version_str.split('.')]
                    
                    # Try to load compatibility data from JSON
                    compatibility_data = self.load_vlc_compatibility_data(version_str)
                    
                    self.vlc_version_info = {
                        'version_string': version_line,
                        'version_number': version_str,
                        'major': version_parts[0],
                        'minor': version_parts[1],
                        'patch': version_parts[2],
                        'supports_modern_hw_decode': compatibility_data.get('supports_modern_hw_decode', version_parts >= [3, 0, 0]),
                        'supports_mmal': compatibility_data.get('supports_mmal', version_parts >= [2, 2, 0]),
                        'supports_advanced_caching': compatibility_data.get('supports_advanced_caching', version_parts >= [3, 0, 0]),
                        'problematic_options': compatibility_data.get('problematic_options', []),
                    }
                    
                    logging.info(f"[VLC] Version: {version_line}")
                    if version_parts < [3, 0, 0]:
                        logging.warning(f"[WARNING] VLC {version_str} is older - some optimizations may be disabled")
                    
                    # Log version for future compatibility tracking
                    self.log_vlc_version()
                    
                    return True
                else:
                    logging.warning("[WARNING] Could not parse VLC version number")
            else:
                logging.warning("[WARNING] VLC version check failed")
        except (subprocess.TimeoutExpired, FileNotFoundError, Exception) as e:
            logging.error(f"[ERROR] VLC not found or not working: {e}")
            logging.error("   Please install VLC: sudo apt install vlc")
            
        # Fallback for unknown VLC version
        self.vlc_version_info = {
            'version_string': 'Unknown',
            'version_number': '0.0.0',
            'major': 0, 'minor': 0, 'patch': 0,
            'supports_modern_hw_decode': False,
            'supports_mmal': False,
            'supports_advanced_caching': False,
            'problematic_options': [],
        }
        return False

    def load_vlc_compatibility_data(self, version_str):
        """Load VLC compatibility data from JSON file"""
        try:
            compatibility_file = os.path.join(os.path.dirname(__file__), 'vlc_compatibility.json')
            with open(compatibility_file, 'r') as f:
                data = json.load(f)
            
            known_versions = data['vlc_compatibility']['known_versions']
            
            # Check for exact version match first
            if version_str in known_versions:
                return known_versions[version_str]
            
            # Check for major.minor.x pattern
            major_minor = '.'.join(version_str.split('.')[:2]) + '.x'
            if major_minor in known_versions:
                return known_versions[major_minor]
            
        except Exception as e:
            logging.debug(f"Could not load VLC compatibility data: {e}")
        
        return {}

    def log_vlc_version(self):
        """Log VLC version for compatibility tracking"""
        try:
            log_file = os.path.join(self.config['base_path'], 'vlc_version_history.log')
            from datetime import datetime
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            with open(log_file, 'a') as f:
                f.write(f"{timestamp}: Player startup - {self.vlc_version_info['version_string']}\n")
        except Exception:
            pass  # Don't fail if logging doesn't work

    def load_working_streams(self):
        """Load working streams from local database, prefer optimized version"""
        # Try optimized database first
        optimized_file = os.path.join(self.config['base_path'], 'working_streams_optimized.json')
        
        try:
            if os.path.exists(optimized_file):
                with open(optimized_file, 'r') as f:
                    self.working_streams = json.load(f)
                logging.info(f"[OK] Loaded {len(self.working_streams)} performance-optimized streams")
                return
        except Exception as e:
            logging.warning(f"Could not load optimized streams: {e}")
        
        # Fallback to original database
        try:
            if os.path.exists(self.working_streams_file):
                with open(self.working_streams_file, 'r') as f:
                    self.working_streams = json.load(f)
                logging.info(f"[OK] Loaded {len(self.working_streams)} working streams from database")
                logging.info("[HINT] Run 'python3 tools/stream-performance-analyzer.py' to optimize performance")
            else:
                logging.warning("[FAIL] No working streams database found! Run iptv_stream_scanner.py first")
        except Exception as e:
            logging.error(f"Error loading working streams: {e}")

    def setup_environment(self):
        """Setup audio/video environment"""
        logging.info("[SETUP] Setting up environment...")
        
        if self.config['platform'] == 'windows':
            # Windows environment
            env = dict(os.environ)
            logging.info("[DISPLAY] Windows development environment")
            return env
        
        # Raspberry Pi environment
        env = {
            'DISPLAY': ':0',
            'HOME': '/home/jeremy',
            'USER': 'jeremy',
            'PATH': os.environ.get('PATH', '/usr/bin:/bin'),
        }
        
        # Setup audio (only on Pi)
        if self.config['display']['setup_audio']:
            try:
                # Force HDMI audio output (numid=3: 0=auto, 1=headphones, 2=HDMI)
                subprocess.run(['sudo', 'amixer', 'cset', 'numid=3', '2'], check=False)
                # Set reasonable volume
                subprocess.run(['amixer', 'set', 'Master', '90%', 'unmute'], check=False)
                logging.info("[AUDIO] Audio configured (HDMI output, 90% volume)")
            except Exception:
                logging.warning("[WARNING] Audio setup failed - check alsa-utils installation")
        
        return env

    def get_best_streams_for_category(self, category_keywords, limit=10):
        """Get best working streams for a specific category"""
        if not self.working_streams:
            return []
        
        matching_streams = []
        
        for url, data in self.working_streams.items():
            stream_text = f"{data['name']} {data['group']}".lower()
            
            # Check if stream matches category
            if any(keyword in stream_text for keyword in category_keywords):
                # Calculate freshness score
                last_working = datetime.fromisoformat(data['last_working'])
                hours_ago = (datetime.now() - last_working).total_seconds() / 3600
                freshness_score = max(0, 100 - hours_ago)
                
                data['score'] = freshness_score
                matching_streams.append(data)
        
        # Sort by score and return top streams
        matching_streams.sort(key=lambda x: x['score'], reverse=True)
        return matching_streams[:limit]

    def launch_video_player(self, stream_data, env):
        """Launch VLC player with the stream"""
        try:
            stream_url = stream_data['url']
            stream_name = stream_data['name']
            
            logging.info(f"PLAYING: {stream_name}")
            logging.info(f"URL: {stream_url[:100]}...")
            logging.info(f"Group: {stream_data['group']}")
            
            # Kill existing VLC processes (Linux only)
            if platform.system() != 'Windows':
                subprocess.run(['pkill', '-9', '-f', 'vlc'], check=False)
            time.sleep(2)
            
            return self.launch_vlc(stream_url, env)
            
        except Exception as e:
            logging.error(f"Launch failed: {e}")
            return False

    def launch_vlc(self, stream_url, env):
        """Launch VLC with optimal settings for Raspberry Pi"""
        try:
            # Check VLC availability and Pi hardware
            try:
                vlc_cmd = self.find_vlc_executable()
                vlc_version = subprocess.run([vlc_cmd, '--version'], capture_output=True, text=True, timeout=5)
                logging.info(f"   VLC Version: {vlc_version.stdout.split()[2] if vlc_version.stdout else 'Unknown'}")
            except Exception:
                logging.warning("   Could not determine VLC version")
            
            # Check if we're on a Raspberry Pi for hardware-specific optimizations
            is_raspberry_pi = False
            try:
                with open('/proc/cpuinfo', 'r') as f:
                    cpuinfo = f.read()
                    if 'BCM' in cpuinfo or 'Raspberry Pi' in cpuinfo:
                        is_raspberry_pi = True
                        logging.info("   Detected Raspberry Pi - applying hardware optimizations")
                        
                        # Check GPU memory split for video performance
                        try:
                            gpu_mem = subprocess.run(['vcgencmd', 'get_mem', 'gpu'], 
                                                   capture_output=True, text=True, timeout=3)
                            if gpu_mem.returncode == 0:
                                gpu_mb = gpu_mem.stdout.strip()
                                logging.info(f"   GPU Memory: {gpu_mb}")
                                # Check if GPU memory is sufficient for hardware decode
                                if 'gpu=' in gpu_mb:
                                    mem_value = int(gpu_mb.split('=')[1].replace('M', ''))
                                    if mem_value < 64:
                                        logging.warning(f"   GPU memory ({mem_value}MB) may be low for hardware decode")
                                        logging.info("   Consider: sudo raspi-config > Advanced > Memory Split > 128")
                        except Exception:
                            pass
                        
                        # Check Pi model for performance expectations
                        try:
                            model_info = subprocess.run(['cat', '/proc/device-tree/model'], 
                                                      capture_output=True, text=True, timeout=2)
                            if model_info.returncode == 0:
                                model = model_info.stdout.strip().replace('\x00', '')
                                logging.info(f"   Pi Model: {model}")
                                if 'Pi 3' in model or 'Pi Zero' in model:
                                    logging.info("   Note: Older Pi model - performance may be limited")
                        except Exception:
                            pass
            except Exception:
                pass
            
            # Quick network connectivity test for streaming optimization
            try:
                import socket
                test_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                test_socket.settimeout(2)
                result = test_socket.connect_ex(('8.8.8.8', 53))  # Google DNS
                test_socket.close()
                if result == 0:
                    logging.info("   Network connectivity: Good")
                else:
                    logging.warning("   Network connectivity: Limited - may affect streaming")
            except Exception:
                pass
            
            # Detect video output method
            has_x11 = os.environ.get('DISPLAY') and self.check_x11_available()
            
            # VLC configurations optimized for performance now that stability is proven
            vlc_cmd = self.find_vlc_executable()
            
            # Platform-specific audio output
            if platform.system() == 'Windows':
                audio_out = 'directsound'  # Windows DirectSound
                video_out = 'directx'      # Windows DirectX
                logging.info("[DISPLAY] Windows detected - using DirectX output")
            else:
                audio_out = 'alsa'         # Linux ALSA
                video_out = 'x11'          # Linux X11
            
            if has_x11 or platform.system() == 'Windows':
                if platform.system() == 'Windows':
                    logging.info("[DISPLAY] Windows detected - using DirectX output")
                else:
                    logging.info("[DISPLAY] X11 detected - using performance-optimized desktop mode")
                vlc_configs = [
                    # GPU-accelerated for best performance
                    [vlc_cmd, '--intf', 'dummy', '--fullscreen', '--no-osd', '--aout', audio_out, '--vout', 'gl'],
                    # Standard video output with performance tweaks
                    [vlc_cmd, '--intf', 'dummy', '--fullscreen', '--no-osd', '--aout', audio_out, '--vout', video_out,
                     '--no-video-title-show'],
                    # Software fallback if hardware fails (version-aware)
                    [vlc_cmd, '--intf', 'dummy', '--fullscreen', '--no-osd', '--aout', audio_out, '--vout', video_out] + 
                    (['--avcodec-hw=none'] if self.vlc_version_info['supports_modern_hw_decode'] else []),
                ]
            else:
                logging.info("[DISPLAY] No X11 - using performance-optimized framebuffer mode")
                vlc_configs = [
                    # Optimized framebuffer with deinterlacing (Linux only)
                    [vlc_cmd, '--intf', 'dummy', '--vout', 'fb', '--fbdev', '/dev/fb0', '--aout', audio_out, 
                     '--no-osd', '--deinterlace-mode', 'linear'],
                    # Basic framebuffer fallback (Linux only)
                    [vlc_cmd, '--intf', 'dummy', '--vout', 'fb', '--fbdev', '/dev/fb0', '--aout', audio_out, '--no-osd'],
                ]
            
            # Try each configuration with PROTOCOL-AWARE optimizations
            for i, base_cmd in enumerate(vlc_configs, 1):
                if i == 1:
                    # First attempt: Protocol-optimized ultra low-latency
                    
                    # Detect protocol and get optimized args
                    protocol = self.protocol_optimizer.detect_protocol(stream_url)
                    protocol_info = self.protocol_optimizer.get_protocol_info(stream_url)
                    protocol_args = self.protocol_optimizer.get_optimized_vlc_args(stream_url, self.vlc_version_info)
                    
                    logging.info(f"   Protocol: {protocol.upper()} - {protocol_info['name']}")
                    logging.info(f"   Expected latency: {protocol_info['latency']}")
                    
                    # Base performance args
                    performance_args = [
                        '--http-user-agent', 'Mozilla/5.0 (Smart-IPTV-Player)',
                        '--no-video-title-show',
                        '--quiet',
                        '--no-snapshot-preview',
                        '--disable-screensaver',
                    ]
                    
                    # Add protocol-specific optimizations with Windows compatibility
                    if platform.system() == 'Windows':
                        # Windows: Use VLC defaults for most stable playback
                        # Only add essential Windows-specific settings
                        windows_args = [
                            # No custom caching - let VLC handle it automatically
                            # VLC's adaptive algorithms work better than manual tuning
                        ]
                        performance_args.extend(windows_args)
                        logging.info("   Applied Windows default VLC settings (no custom caching)")
                    else:
                        # Use protocol optimizer on Linux/Pi
                        performance_args.extend(protocol_args)
                    
                    # Add general performance options if supported
                    if self.vlc_version_info['major'] >= 3:
                        performance_args.extend([
                            '--no-stats',              # Disable statistics overhead
                            '--no-sub-autodetect-file', # Skip subtitle detection
                            '--no-metadata-network-access', # Skip online metadata
                        ])
                    
                    performance_args.append(stream_url)
                elif i == 2:
                    # Second attempt: Hardware decode + frame management (version-aware)
                    performance_args = [
                        '--network-caching=1000',  # Moderate latency
                        '--http-user-agent', 'Mozilla/5.0 (Smart-IPTV-Player)',
                        '--no-video-title-show',
                        '--quiet',
                        '--no-snapshot-preview',
                        '--disable-screensaver',
                    ]
                    
                    # Add caching options if supported
                    if self.vlc_version_info['supports_advanced_caching']:
                        performance_args.extend([
                            '--live-caching=300',      # Low live buffering
                            '--file-caching=300',      # Low file buffering
                        ])
                    
                    # Add modern hardware decode options
                    if self.vlc_version_info['supports_modern_hw_decode']:
                        hw_decode = 'mmal' if (is_raspberry_pi and self.vlc_version_info['supports_mmal']) else 'any'
                        performance_args.extend([
                            '--codec=avcodec',         # Hardware acceleration
                            f'--avcodec-hw={hw_decode}', # Hardware decode
                        ])
                    
                    # Add frame management if supported
                    if self.vlc_version_info['major'] >= 3:
                        performance_args.extend([
                            '--drop-late-frames',      # Drop frames if behind
                            '--skip-frames',           # Skip frames to catch up
                        ])
                    
                    # Add Raspberry Pi specific optimizations
                    if is_raspberry_pi and self.vlc_version_info['major'] >= 2:
                        pi_options = ['--video-on-top']  # Keep video on top for direct output
                        
                        if self.vlc_version_info['major'] >= 3:
                            pi_options.extend([
                                '--avcodec-skiploopfilter=all', # Skip post-processing for speed
                            ])
                        
                        performance_args.extend(pi_options)
                    
                    performance_args.append(stream_url)
                else:
                    # Fallback: Conservative but still optimized
                    performance_args = [
                        '--network-caching=1500',  # Better than default 3000
                        '--http-user-agent', 'Mozilla/5.0 (Smart-IPTV-Player)',
                        '--no-video-title-show',
                        '--quiet',
                        '--no-snapshot-preview',
                        '--disable-screensaver',
                        stream_url
                    ]
                
                cmd = base_cmd + performance_args
                
                config_name = "X11" if has_x11 else ("Framebuffer" if i == 1 else "Console")
                logging.info(f"[VIDEO] Trying VLC config {i}: {config_name}")
                
                if self._start_vlc_process(cmd, env, config_name):
                    return True
                
                # Add delay between attempts to prevent rapid cycling
                logging.info("   Waiting 3 seconds before next config...")
                time.sleep(3)
            
            logging.error("[FAIL] All VLC configurations failed")
            return False
            
        except Exception as e:
            logging.error(f"VLC launch failed: {e}")
            return False

    def _start_vlc_process(self, cmd, env, config_name):
        """Start VLC process and monitor startup"""
        try:
            # Platform-specific environment setup
            if platform.system() != 'Windows':
                env['DISPLAY'] = ':0'
            
            # Log the exact command being run for debugging
            logging.info(f"   Executing: {' '.join(cmd)}")
            
            # Platform-specific process setup
            popen_kwargs = {
                'env': env,
                'stdout': subprocess.DEVNULL,
                'stderr': subprocess.PIPE,
                'text': True
            }
            
            if platform.system() != 'Windows':
                # Linux-specific: Start VLC with high priority for better performance
                def setup_process():
                    os.setsid()
                    # Set high priority (lower nice value = higher priority)
                    try:
                        os.nice(-10)  # High priority for streaming
                    except OSError:
                        pass  # Not running as root, ignore
                popen_kwargs['preexec_fn'] = setup_process
            
            # For debugging, capture stderr to see VLC errors
            self.current_process = subprocess.Popen(cmd, **popen_kwargs)
            
            self.current_stream = cmd[-1]  # URL is the last argument
            
            # Monitor startup with better crash detection
            logging.info(f"[LOADING] Monitoring VLC {config_name} startup...")
            
            # Wait a bit for VLC to initialize
            time.sleep(2)
            
            # Check if VLC crashed immediately
            if self.current_process.poll() is not None:
                # Try to get error output
                try:
                    _, stderr_output = self.current_process.communicate(timeout=1)
                    if stderr_output.strip():
                        error_msg = stderr_output.strip()[:300]  # Show more error detail
                        logging.error(f"   VLC Error: {error_msg}")
                        
                        # Check for specific known issues
                        if "unknown option" in error_msg.lower():
                            logging.error("   [TIP] Run './tools/vlc-option-validator.sh' to check supported options")
                        elif "missing mandatory argument" in error_msg.lower():
                            logging.error("   [TIP] Some VLC options may be deprecated in your VLC version")
                except Exception:
                    pass
                logging.warning(f"[FAIL] VLC {config_name} crashed immediately (exit code: {self.current_process.returncode})")
                return False
            
            # Monitor for 10 more seconds to ensure stability
            for i in range(10):
                if self.current_process.poll() is not None:
                    # Try to get error output for crashes during monitoring
                    try:
                        _, stderr_output = self.current_process.communicate(timeout=0.5)
                        if stderr_output.strip():
                            logging.error(f"   VLC Error: {stderr_output.strip()[:200]}")
                    except Exception:
                        pass
                    logging.warning(f"[FAIL] VLC {config_name} crashed after {i+2} seconds (exit code: {self.current_process.returncode})")
                    return False
                
                time.sleep(1)
                if i % 3 == 0:
                    logging.info(f"   VLC {config_name} stability check {i+3}/12 seconds...")
            
            # Record successful start time for performance tracking
            import time as time_module
            self.stream_start_time = time_module.time()
            
            logging.info(f"[OK] SUCCESS! VLC {config_name} stable (PID: {self.current_process.pid})")
            logging.info("[VIDEO] VLC playing video with audio - process is stable!")
            logging.info("   Stream startup time: ~12 seconds (including stability check)")
            return True
            
        except Exception as e:
            logging.error(f"VLC {config_name} process start failed: {e}")
            return False

    def try_mplayer(self, stream_url, env):
        """Try to launch mplayer as fallback"""
        try:
            # MPlayer command with working configuration
            cmd = [
                'mplayer',
                '-vo', 'x11',
                '-ao', 'alsa',
                '-fs',
                '-cache', '512',
                '-cache-min', '1',
                '-loop', '0',
                '-user-agent', 'Mozilla/5.0 (compatible; Smart-IPTV-Player/1.0)',
                stream_url
            ]
            
            env['DISPLAY'] = ':0'
            
            self.current_process = subprocess.Popen(
                cmd,
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                preexec_fn=os.setsid
            )
            
            self.current_stream = stream_url
            
            # Monitor startup
            logging.info("[LOADING] Monitoring mplayer startup...")
            for i in range(20):
                if self.current_process.poll() is not None:
                    logging.warning(f"[FAIL] mplayer failed to start (exit code: {self.current_process.returncode})")
                    return False
                
                time.sleep(1)
                if i % 5 == 0:
                    logging.info(f"   mplayer startup check {i+1}/20...")
            
            logging.info(f"[OK] SUCCESS! mplayer playing stream (PID: {self.current_process.pid})")
            logging.info("[VIDEO] You should now see and hear video!")
            return True
                
        except Exception as e:
            logging.error(f"Launch failed: {e}")
            return False

    def try_category_streams(self, category_name, keywords, env):
        """Try streams from a specific category"""
        logging.info(f"[TV] Trying {category_name} streams...")
        
        streams = self.get_best_streams_for_category(keywords, 10)
        
        if not streams:
            logging.warning(f"No {category_name} streams found in database")
            return False
        
        logging.info(f"Found {len(streams)} {category_name} streams, trying best ones...")
        
        failed_attempts = 0
        
        for i, stream in enumerate(streams):
            logging.info(f"[ATTEMPT] Attempt {i+1}/{len(streams)}: {stream['name']}")
            
            if self.launch_video_player(stream, env):
                return True
            else:
                logging.warning(f"[FAIL] Failed: {stream['name']}")
                failed_attempts += 1
                
                # Increase delay after multiple failures to prevent rapid cycling
                if failed_attempts <= 3:
                    time.sleep(2)
                elif failed_attempts <= 6:
                    logging.info("   Multiple failures - waiting 5 seconds...")
                    time.sleep(5)
                else:
                    logging.info("   Many failures - waiting 10 seconds...")
                    time.sleep(10)
        
        logging.warning(f"All {category_name} streams failed")
        return False

    def start_smart_player(self):
        """Start the smart IPTV player"""
        logging.info("[START] === SMART IPTV PLAYER STARTING ===")
        
        def signal_handler(signum, frame):
            logging.info(f"Received signal {signum}, shutting down...")
            self.shutdown()
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        env = self.setup_environment()
        
        if not self.working_streams:
            logging.error("[FAIL] No working streams available! Please run the scanner first:")
            logging.error("   python3 /home/jeremy/gtv/iptv_stream_scanner.py")
            return False
        
        logging.info("[INIT] Waiting for system stability...")
        time.sleep(5)
        
        # Try categories in order of preference
        categories = [
            ("Classic/Movies", ['classic', 'movies', 'cinema', 'film', 'tcm', 'retro', 'vintage']),
            ("General TV", ['tv', 'general', 'entertainment']),
            ("Any Working Stream", [])  # Empty list means any stream
        ]
        
        success = False
        
        for category_name, keywords in categories:
            if self.try_category_streams(category_name, keywords, env):
                success = True
                break
            time.sleep(3)
        
        # Fallback to backup streams
        if not success:
            logging.info("[LOADING] All database streams failed, trying backup videos...")
            
            for i, backup_url in enumerate(self.backup_streams):
                backup_data = {
                    'url': backup_url,
                    'name': f'Backup Video {i+1}',
                    'group': 'Local'
                }
                
                if self.launch_video_player(backup_data, env):
                    success = True
                    break
        
        if not success:
            logging.error("[FAIL] Everything failed!")
            return False
        
        # Monitoring loop
        logging.info("[LOADING] Service running, monitoring playback...")
        try:
            while self.running:
                if self.current_process and self.current_process.poll() is not None:
                    logging.warning("[WARNING] Player ended unexpectedly")
                    break
                
                time.sleep(60)  # Check every minute
                if self.current_process:
                    logging.info(f"[TV] Status: {self.current_stream} running (PID: {self.current_process.pid})")
                
        except KeyboardInterrupt:
            logging.info("Service interrupted by user")
        
        return True

    def shutdown(self):
        """Clean shutdown"""
        logging.info("[STOP] Shutting down...")
        self.running = False
        
        if self.current_process:
            try:
                self.current_process.terminate()
                self.current_process.wait(timeout=5)
            except Exception:
                self.current_process.kill()
        
        # Kill any remaining media player processes (Linux only)
        if platform.system() != 'Windows':
            subprocess.run(['pkill', '-9', '-f', 'mplayer'], check=False)
        logging.info("Shutdown complete")

def main():
    player = SmartIPTVPlayer()
    player.start_smart_player()

if __name__ == "__main__":
    main()

