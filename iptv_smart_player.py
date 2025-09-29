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

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(CONFIG['log_file']),
        logging.StreamHandler(sys.stdout)
    ]
)

class SmartIPTVPlayer:
    def __init__(self):
        self.config = CONFIG
        self.working_streams_file = os.path.join(self.config['base_path'], 'working_streams.json')
        self.working_streams = {}
        self.current_process = None
        self.current_stream = None
        self.running = True
        
        # Backup streams if no working streams found
        self.backup_streams = [
            "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
        ]
        
        logging.info(f"🔧 Running in {self.config['platform']} mode")
        self.load_working_streams()

    def check_x11_available(self):
        """Check if X11 is available"""
        try:
            subprocess.run(['xset', 'q'], check=True, 
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False

    def load_working_streams(self):
        """Load working streams from local database"""
        try:
            if os.path.exists(self.working_streams_file):
                with open(self.working_streams_file, 'r') as f:
                    self.working_streams = json.load(f)
                logging.info(f"[OK] Loaded {len(self.working_streams)} working streams from database")
            else:
                logging.warning("[FAIL] No working streams database found! Run iptv_stream_scanner.py first")
        except Exception as e:
            logging.error(f"Error loading working streams: {e}")

    def setup_environment(self):
        """Setup audio/video environment"""
        logging.info("🔧 Setting up environment...")
        
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
                logging.info("🔊 Audio configured (HDMI output, 90% volume)")
            except Exception:
                logging.warning("⚠️ Audio setup failed - check alsa-utils installation")
        
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
            
            # Kill existing VLC processes
            subprocess.run(['pkill', '-9', '-f', 'vlc'], check=False)
            time.sleep(2)
            
            return self.launch_vlc(stream_url, env)
            
        except Exception as e:
            logging.error(f"Launch failed: {e}")
            return False

    def launch_vlc(self, stream_url, env):
        """Launch VLC with optimal settings for Raspberry Pi"""
        try:
            # Detect video output method
            has_x11 = os.environ.get('DISPLAY') and self.check_x11_available()
            
            # VLC configurations to try (in order of preference)
            if has_x11:
                logging.info("[DISPLAY] X11 detected - using desktop mode")
                vlc_configs = [
                    # Best for desktop/X11
                    ['vlc', '--intf', 'dummy', '--fullscreen', '--no-video-title-show', '--aout', 'alsa'],
                    # Alternative X11 config
                    ['vlc', '--intf', 'dummy', '--vout', 'x11', '--fullscreen', '--aout', 'alsa'],
                ]
            else:
                logging.info("[DISPLAY] No X11 - trying framebuffer/console modes")
                vlc_configs = [
                    # Framebuffer output
                    ['vlc', '--intf', 'dummy', '--vout', 'fb', '--aout', 'alsa'],
                    # Console output (ASCII art but with audio)
                    ['vlc', '--intf', 'dummy', '--vout', 'caca', '--aout', 'alsa'],
                ]
            
            # Try each configuration
            for i, base_cmd in enumerate(vlc_configs, 1):
                cmd = base_cmd + [
                    '--network-caching=3000',
                    '--http-user-agent', 'Mozilla/5.0 (Smart-IPTV-Player)',
                    stream_url
                ]
                
                config_name = "X11" if has_x11 else ("Framebuffer" if i == 1 else "Console")
                logging.info(f"[VIDEO] Trying VLC config {i}: {config_name}")
                
                if self._start_vlc_process(cmd, env, config_name):
                    return True
            
            logging.error("[FAIL] All VLC configurations failed")
            return False
            
        except Exception as e:
            logging.error(f"VLC launch failed: {e}")
            return False

    def _start_vlc_process(self, cmd, env, config_name):
        """Start VLC process and monitor startup"""
        try:
            env['DISPLAY'] = ':0'
            
            self.current_process = subprocess.Popen(
                cmd,
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                preexec_fn=os.setsid
            )
            
            self.current_stream = cmd[-1]  # URL is the last argument
            
            # Monitor startup
            logging.info(f"[LOADING] Monitoring VLC {config_name} startup...")
            for i in range(15):  # 15 second timeout
                if self.current_process.poll() is not None:
                    logging.warning(f"[FAIL] VLC {config_name} failed (exit code: {self.current_process.returncode})")
                    return False
                
                time.sleep(1)
                if i % 5 == 0:
                    logging.info(f"   VLC {config_name} check {i+1}/15...")
            
            logging.info(f"[OK] SUCCESS! VLC {config_name} started (PID: {self.current_process.pid})")
            logging.info("[VIDEO] VLC should now be playing video with audio!")
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
        
        for i, stream in enumerate(streams):
            logging.info(f"[ATTEMPT] Attempt {i+1}/{len(streams)}: {stream['name']}")
            
            if self.launch_video_player(stream, env):
                return True
            else:
                logging.warning(f"[FAIL] Failed: {stream['name']}")
                time.sleep(2)
        
        logging.warning(f"All {category_name} streams failed")
        return False

    def start_smart_player(self):
        """Start the smart IPTV player"""
        logging.info("🚀 === SMART IPTV PLAYER STARTING ===")
        
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
        
        logging.info("⏳ Waiting for system stability...")
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
                    logging.warning("⚠️ Player ended unexpectedly")
                    break
                
                time.sleep(60)  # Check every minute
                if self.current_process:
                    logging.info(f"[TV] Status: {self.current_stream} running (PID: {self.current_process.pid})")
                
        except KeyboardInterrupt:
            logging.info("Service interrupted by user")
        
        return True

    def shutdown(self):
        """Clean shutdown"""
        logging.info("🛑 Shutting down...")
        self.running = False
        
        if self.current_process:
            try:
                self.current_process.terminate()
                self.current_process.wait(timeout=5)
            except Exception:
                self.current_process.kill()
        
        subprocess.run(['pkill', '-9', '-f', 'mplayer'], check=False)
        logging.info("Shutdown complete")

def main():
    player = SmartIPTVPlayer()
    player.start_smart_player()

if __name__ == "__main__":
    main()

