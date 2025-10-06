#!/usr/bin/env python3
"""
IPTV Player using MPV - Optimized for Raspberry Pi 3
MPV is 30-50% more efficient than VLC on constrained hardware
"""
import subprocess
import time
import os
import sys
import signal
import logging
import json
from datetime import datetime
import platform

# Load config from main player
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
            "log_file": "/home/jeremy/gtv/iptv_player_mpv.log",
            "working_streams_file": "/home/jeremy/gtv/working_streams.json",
            "use_vlc": False,
            "test_mode": False,
            "display": {"setup_display": True, "setup_audio": True},
            "player_command": "mpv"
        }

# Load configuration
CONFIG = load_config()

# Configure logging with read-only filesystem support
log_handlers = [logging.StreamHandler(sys.stdout)]

# Try to create file handler, fallback to stdout-only if filesystem is read-only
try:
    # First try to create the directory if it doesn't exist
    log_dir = os.path.dirname(CONFIG['log_file'])
    if log_dir and not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)
    
    # Try to create the log file handler
    log_handlers.append(logging.FileHandler(CONFIG['log_file'], encoding='utf-8'))
    print(f"IPTV Player: Logging to file: {CONFIG['log_file']}")
except (OSError, IOError, PermissionError) as e:
    # Read-only filesystem or permission issue - continue with stdout only
    print(f"IPTV Player: Cannot write to log file ({e}), using stdout only")
except Exception as e:
    # Any other error - try without encoding parameter
    try:
        log_handlers.append(logging.FileHandler(CONFIG['log_file']))
        print(f"IPTV Player: Logging to file: {CONFIG['log_file']} (no encoding)")
    except Exception:
        print(f"IPTV Player: Cannot write to log file ({e}), using stdout only")

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=log_handlers
)

class MPVIPTVPlayer:
    def __init__(self):
        self.config = CONFIG
        self.working_streams_file = os.path.join(self.config['base_path'], 'working_streams.json')
        self.working_streams = {}
        self.current_process = None
        self.current_stream = None
        self.running = True
        
        # Backup streams
        self.backup_streams = [
            "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
        ]
        
        logging.info(f"[SETUP] MPV Player - Running in {self.config['platform']} mode")
        self.check_mpv_available()
        self.load_working_streams()

    def check_mpv_available(self):
        """Check if MPV is available"""
        try:
            result = subprocess.run(['mpv', '--version'], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version_line = result.stdout.split('\n')[0]
                logging.info(f"[MPV] {version_line}")
                return True
        except subprocess.TimeoutExpired:
            logging.warning("[WARNING] MPV version check slow - continuing anyway")
            return True  # Assume it's installed if command exists
        except Exception as e:
            logging.error(f"[ERROR] MPV not found: {e}")
            logging.error("   Please install MPV: sudo apt install mpv")
            return False

    def load_working_streams(self):
        """Load working streams from database"""
        # Try optimized database first
        optimized_file = os.path.join(self.config['base_path'], 'working_streams_optimized.json')
        
        try:
            if os.path.exists(optimized_file):
                with open(optimized_file, 'r') as f:
                    self.working_streams = json.load(f)
                logging.info(f"[OK] Loaded {len(self.working_streams)} optimized streams")
                return
        except Exception as e:
            logging.warning(f"Could not load optimized streams: {e}")
        
        # Fallback to original database
        try:
            if os.path.exists(self.working_streams_file):
                with open(self.working_streams_file, 'r') as f:
                    self.working_streams = json.load(f)
                logging.info(f"[OK] Loaded {len(self.working_streams)} working streams")
        except Exception as e:
            logging.error(f"Error loading streams: {e}")

    def get_best_streams_for_category(self, category_keywords, limit=10):
        """Get best working streams for a specific category"""
        if not self.working_streams:
            return []
        
        matching_streams = []
        
        for url, data in self.working_streams.items():
            stream_text = f"{data['name']} {data['group']}".lower()
            
            if any(keyword in stream_text for keyword in category_keywords):
                last_working = datetime.fromisoformat(data['last_working'])
                hours_ago = (datetime.now() - last_working).total_seconds() / 3600
                freshness_score = max(0, 100 - hours_ago)
                
                data['score'] = freshness_score
                matching_streams.append(data)
        
        matching_streams.sort(key=lambda x: x['score'], reverse=True)
        return matching_streams[:limit]

    def launch_mpv(self, stream_url, env):
        """Launch MPV with optimal settings for Raspberry Pi 3"""
        try:
            logging.info("[MPV] Starting MPV player...")
            
            # Kill existing MPV processes (but not this script!)
            if platform.system() != 'Windows':
                # Only kill actual mpv player processes, not this Python script
                subprocess.run(['pkill', '-9', '^mpv$'], check=False)
            time.sleep(0.5)
            
            # Detect Pi hardware
            is_raspberry_pi = False
            try:
                with open('/proc/cpuinfo', 'r') as f:
                    cpuinfo = f.read()
                    if 'BCM' in cpuinfo or 'Raspberry Pi' in cpuinfo:
                        is_raspberry_pi = True
                        logging.info("   Detected Raspberry Pi - using optimized settings")
            except:
                pass
            
            # MPV configurations optimized for Pi 3
            # MPV is MUCH more efficient than VLC on Pi hardware
            mpv_configs = []
            
            if is_raspberry_pi:
                # Pi 3 optimized - uses ~30% less CPU than VLC
                mpv_configs = [
                    # Config 1: Performance optimized (best)
                    [
                        'mpv',
                        '--hwdec=no',                    # Software decode (stable on Pi 3)
                        '--vo=gpu',                      # GPU output (efficient)
                        '--cache=yes',                   # Enable cache
                        '--cache-secs=2',                # 2 second cache (low latency)
                        '--demuxer-max-bytes=20M',       # Reasonable buffer
                        '--demuxer-readahead-secs=2',    # 2 sec readahead
                        '--framedrop=vo',                # Smart frame dropping
                        '--no-osc',                      # No on-screen controls
                        '--no-input-default-bindings',   # No keyboard bindings
                        '--really-quiet',                # Quiet mode
                        '--fullscreen',                  # Fullscreen
                        '--loop-playlist=inf',           # Loop forever (continuous play)
                        '--user-agent=Mozilla/5.0 (Smart-IPTV-Player)',
                        stream_url
                    ],
                    # Config 2: Even lighter (fallback)
                    [
                        'mpv',
                        '--hwdec=no',
                        '--vo=gpu',
                        '--cache=yes',
                        '--cache-secs=1',                # Minimal cache
                        '--no-osc',
                        '--really-quiet',
                        '--fullscreen',
                        '--loop-playlist=inf',
                        stream_url
                    ],
                    # Config 3: Minimal (last resort)
                    [
                        'mpv',
                        '--vo=gpu',
                        '--cache=yes',
                        '--no-osc',
                        '--quiet',
                        '--fullscreen',
                        '--loop-playlist=inf',
                        stream_url
                    ]
                ]
            else:
                # Desktop/Windows - can use more features
                mpv_configs = [
                    [
                        'mpv',
                        '--hwdec=auto',
                        '--vo=gpu',
                        '--cache=yes',
                        '--cache-secs=3',
                        '--no-osc',
                        '--fullscreen',
                        stream_url
                    ]
                ]
            
            # Try each configuration
            for i, cmd in enumerate(mpv_configs, 1):
                logging.info(f"[MPV] Trying config {i}/{len(mpv_configs)}")
                logging.info(f"   Command: {' '.join(cmd[:6])}...")
                
                if self._start_mpv_process(cmd, env, f"Config {i}"):
                    return True
                
                if i < len(mpv_configs):
                    logging.info("   Waiting 1 second before next config...")
                    time.sleep(1)
            
            logging.error("[FAIL] All MPV configurations failed")
            return False
            
        except Exception as e:
            logging.error(f"MPV launch failed: {e}")
            return False

    def _start_mpv_process(self, cmd, env, config_name):
        """Start MPV process and monitor"""
        try:
            # Platform-specific environment
            if platform.system() != 'Windows':
                env['DISPLAY'] = ':0'
            
            popen_kwargs = {
                'env': env,
                'stdout': subprocess.PIPE,  # Changed to PIPE to capture output
                'stderr': subprocess.PIPE,
                'text': True
            }
            
            if platform.system() != 'Windows':
                def setup_process():
                    os.setsid()
                popen_kwargs['preexec_fn'] = setup_process
            
            self.current_process = subprocess.Popen(cmd, **popen_kwargs)
            self.current_stream = cmd[-1]
            
            logging.info(f"[LOADING] Quick startup check for MPV {config_name}...")
            
            # Quick check (0.5s) for immediate crashes
            time.sleep(0.5)
            
            if self.current_process.poll() is not None:
                try:
                    _, stderr_output = self.current_process.communicate(timeout=0.5)
                    if stderr_output.strip():
                        logging.error(f"   MPV Error: {stderr_output.strip()[:200]}")
                except:
                    pass
                logging.warning(f"[FAIL] MPV {config_name} crashed (exit: {self.current_process.returncode})")
                return False
            
            # Stability check (2s total - MPV starts faster than VLC)
            for i in range(2):
                if self.current_process.poll() is not None:
                    try:
                        _, stderr_output = self.current_process.communicate(timeout=0.5)
                        if stderr_output.strip():
                            logging.error(f"   MPV Error: {stderr_output.strip()[:200]}")
                    except:
                        pass
                    logging.warning(f"[FAIL] MPV {config_name} crashed after {i+1}s")
                    return False
                time.sleep(1)
            
            logging.info(f"[OK] SUCCESS! MPV {config_name} stable (PID: {self.current_process.pid})")
            logging.info("[VIDEO] MPV playing - optimized for Pi 3!")
            logging.info("   Startup time: ~2.5 seconds (MPV is faster than VLC)")
            return True
            
        except Exception as e:
            logging.error(f"MPV process start failed: {e}")
            return False

    def launch_video_player(self, stream_data, env):
        """Launch video player with stream"""
        try:
            stream_url = stream_data['url']
            stream_name = stream_data['name']
            
            logging.info(f"PLAYING: {stream_name}")
            logging.info(f"URL: {stream_url[:100]}...")
            logging.info(f"Group: {stream_data['group']}")
            
            return self.launch_mpv(stream_url, env)
            
        except Exception as e:
            logging.error(f"Launch failed: {e}")
            return False

    def setup_environment(self):
        """Setup audio/video environment"""
        logging.info("[SETUP] Setting up environment...")
        
        if self.config['platform'] == 'windows':
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
        
        # Setup audio
        if self.config['display']['setup_audio']:
            try:
                subprocess.run(['sudo', 'amixer', 'cset', 'numid=3', '2'], check=False)
                subprocess.run(['amixer', 'set', 'Master', '90%', 'unmute'], check=False)
                logging.info("[AUDIO] Audio configured (HDMI, 90%)")
            except:
                logging.warning("[WARNING] Audio setup failed")
        
        return env

    def try_category_streams(self, category_name, keywords, env):
        """Try streams from a specific category"""
        logging.info(f"[TV] Trying {category_name} streams...")
        
        streams = self.get_best_streams_for_category(keywords, 10)
        
        if not streams:
            logging.warning(f"No {category_name} streams found")
            return False
        
        logging.info(f"Found {len(streams)} {category_name} streams")
        
        for i, stream in enumerate(streams):
            logging.info(f"[ATTEMPT] {i+1}/{len(streams)}: {stream['name']}")
            
            if self.launch_video_player(stream, env):
                return True
            else:
                logging.warning(f"[FAIL] Failed: {stream['name']}")
                time.sleep(2)
        
        logging.warning(f"All {category_name} streams failed")
        return False

    def start_player(self):
        """Start the MPV IPTV player"""
        logging.info("[START] === MPV IPTV PLAYER STARTING ===")
        
        def signal_handler(signum, frame):
            logging.info(f"Received signal {signum}, shutting down...")
            self.shutdown()
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        env = self.setup_environment()
        
        if not self.working_streams:
            logging.error("[FAIL] No working streams! Run scanner first")
            return False
        
        logging.info("[INIT] Ready to start...")
        time.sleep(1)
        
        # Try categories
        categories = [
            ("Classic/Movies", ['classic', 'movies', 'cinema', 'film', 'tcm']),
            ("General TV", ['tv', 'general', 'entertainment']),
            ("Any Working Stream", [])
        ]
        
        success = False
        
        for category_name, keywords in categories:
            if self.try_category_streams(category_name, keywords, env):
                success = True
                break
            time.sleep(2)
        
        # Fallback to backup streams
        if not success:
            logging.info("[LOADING] Trying backup videos...")
            
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
                    # Process ended - try to get exit info
                    exit_code = self.current_process.returncode
                    logging.warning(f"[WARNING] Player ended (exit code: {exit_code})")
                    
                    # Try to get error output
                    try:
                        stdout_data, stderr_data = self.current_process.communicate(timeout=1)
                        if stderr_data and stderr_data.strip():
                            logging.error(f"   MPV Error Output: {stderr_data.strip()[-500:]}")  # Last 500 chars
                    except:
                        pass
                    
                    # If stream just finished normally, try next stream
                    if exit_code == 0:
                        logging.info("[INFO] Stream ended normally - trying next stream...")
                        # Try to restart with next stream
                        break
                    else:
                        logging.error(f"[ERROR] Stream crashed with exit code {exit_code}")
                        break
                
                time.sleep(60)
                if self.current_process:
                    logging.info(f"[TV] Status: Playing (PID: {self.current_process.pid})")
                
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
            except:
                self.current_process.kill()
        
        # Kill any remaining MPV processes
        if platform.system() != 'Windows':
            subprocess.run(['pkill', '-9', '-f', 'mpv'], check=False)
        logging.info("Shutdown complete")

def main():
    player = MPVIPTVPlayer()
    player.start_player()

if __name__ == "__main__":
    main()
