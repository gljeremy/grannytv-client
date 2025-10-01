#!/usr/bin/env python3
"""
GrannyTV Smartphone Setup Server
Web interface for configuring Raspberry Pi via smartphone
"""

from flask import Flask, render_template, request, jsonify
import json
import subprocess
import os
import re
import time
import threading

app = Flask(__name__)

# Configuration
SETUP_CONFIG_FILE = '/tmp/grannytv_setup_config.json'
WIFI_SCAN_CACHE = '/tmp/wifi_networks.json'
WIFI_SCAN_TIMEOUT = 30  # seconds

class SetupConfig:
    def __init__(self):
        self.config = {}
        self.load_config()
    
    def load_config(self):
        """Load existing configuration if available"""
        try:
            if os.path.exists(SETUP_CONFIG_FILE):
                with open(SETUP_CONFIG_FILE, 'r') as f:
                    self.config = json.load(f)
        except Exception as e:
            print(f"Error loading config: {e}")
            self.config = {}
    
    def save_config(self, new_config):
        """Save configuration to file"""
        self.config.update(new_config)
        try:
            with open(SETUP_CONFIG_FILE, 'w') as f:
                json.dump(self.config, f, indent=2)
            return True
        except Exception as e:
            print(f"Error saving config: {e}")
            return False

setup_config = SetupConfig()

@app.route('/')
def index():
    """Main setup page - mobile optimized"""
    return render_template('setup.html')

@app.route('/status')
def status():
    """Show current setup status"""
    return render_template('status.html', config=setup_config.config)

@app.route('/scan_wifi')
def scan_wifi():
    """Scan for available WiFi networks"""
    try:
        # Check if we have a recent scan cached
        if os.path.exists(WIFI_SCAN_CACHE):
            cache_age = time.time() - os.path.getmtime(WIFI_SCAN_CACHE)
            if cache_age < WIFI_SCAN_TIMEOUT:
                with open(WIFI_SCAN_CACHE, 'r') as f:
                    return json.load(f)
        
        # Perform new scan
        print("Scanning for WiFi networks...")
        result = subprocess.run(['sudo', 'iwlist', 'wlan0', 'scan'], 
                              capture_output=True, text=True, timeout=15)
        
        networks = []
        current_network = {}
        
        for line in result.stdout.split('\n'):
            line = line.strip()
            
            if 'Cell ' in line and 'Address:' in line:
                if current_network.get('ssid'):
                    networks.append(current_network)
                current_network = {}
            elif 'ESSID:' in line:
                ssid = line.split('ESSID:')[1].strip('"')
                if ssid and ssid != '<hidden>':
                    current_network['ssid'] = ssid
            elif 'Quality=' in line:
                # Extract signal quality
                quality_match = re.search(r'Quality=(\d+)/(\d+)', line)
                if quality_match:
                    quality = int(quality_match.group(1))
                    max_quality = int(quality_match.group(2))
                    current_network['quality'] = int((quality / max_quality) * 100)
            elif 'Encryption key:' in line:
                current_network['encrypted'] = 'on' in line.lower()
        
        # Add the last network
        if current_network.get('ssid'):
            networks.append(current_network)
        
        # Sort by quality (best first)
        networks.sort(key=lambda x: x.get('quality', 0), reverse=True)
        
        # Remove duplicates while preserving order
        seen = set()
        unique_networks = []
        for network in networks:
            if network['ssid'] not in seen:
                seen.add(network['ssid'])
                unique_networks.append(network)
        
        response = {'networks': unique_networks[:20]}  # Limit to top 20
        
        # Cache the results
        with open(WIFI_SCAN_CACHE, 'w') as f:
            json.dump(response, f)
        
        return jsonify(response)
        
    except subprocess.TimeoutExpired:
        return jsonify({'networks': [], 'error': 'WiFi scan timeout'})
    except Exception as e:
        print(f"WiFi scan error: {e}")
        return jsonify({'networks': [], 'error': str(e)})

@app.route('/detect_pi')
def detect_pi():
    """Detect Raspberry Pi model and hardware info"""
    try:
        pi_info = {}
        
        # Pi model
        try:
            with open('/proc/device-tree/model', 'r') as f:
                pi_info['model'] = f.read().strip()
        except Exception:
            pi_info['model'] = 'Unknown Pi Model'
        
        # Memory info
        try:
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if 'MemTotal:' in line:
                        mem_kb = int(line.split()[1])
                        pi_info['memory'] = f"{mem_kb // 1024}MB"
                        break
        except Exception:
            pi_info['memory'] = 'Unknown'
        
        # GPU memory
        try:
            result = subprocess.run(['vcgencmd', 'get_mem', 'gpu'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                pi_info['gpu_memory'] = result.stdout.strip().split('=')[1]
        except Exception:
            pi_info['gpu_memory'] = 'Unknown'
        
        # Current user
        pi_info['current_user'] = os.getenv('USER', 'unknown')
        pi_info['home_dir'] = os.path.expanduser('~')
        
        return jsonify(pi_info)
        
    except Exception as e:
        return jsonify({'error': str(e)})

@app.route('/test_stream')
def test_stream():
    """Test if MPV and a sample stream work"""
    try:
        # Test MPV installation
        result = subprocess.run(['mpv', '--version'], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode != 0:
            return jsonify({'success': False, 'error': 'MPV not installed'})
        
        # Test with a sample stream (short timeout)
        test_url = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        result = subprocess.run([
            'timeout', '10',
            'mpv', '--no-video', '--ao=null', '--frames=1', test_url
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            return jsonify({'success': True, 'message': 'Stream test successful'})
        else:
            return jsonify({'success': False, 'error': 'Stream test failed'})
            
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/configure', methods=['POST'])
def configure():
    """Apply configuration and prepare for normal operation"""
    try:
        config = request.json
        print(f"Received configuration: {config}")
        
        # Validate required fields
        required = ['wifi_ssid', 'wifi_password', 'username', 'install_path']
        missing = [field for field in required if not config.get(field)]
        if missing:
            return jsonify({'error': f'Missing required fields: {", ".join(missing)}'}), 400
        
        # Save configuration
        if not setup_config.save_config(config):
            return jsonify({'error': 'Failed to save configuration'}), 500
        
        # Create user if needed
        current_user = os.getenv('USER', 'pi')
        if config['username'] != current_user and config['username'] != 'pi':
            try:
                subprocess.run(['sudo', 'useradd', '-m', '-s', '/bin/bash', 
                               config['username']], check=True)
                subprocess.run(['sudo', 'usermod', '-a', '-G', 
                               'sudo,video,audio,dialout', config['username']], check=True)
                print(f"Created user: {config['username']}")
            except subprocess.CalledProcessError as e:
                if 'already exists' not in str(e):
                    return jsonify({'error': f'Failed to create user: {e}'}), 500
        
        # Create WiFi configuration
        wifi_config = f"""country={config.get('wifi_country', 'US')}
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={{
    ssid="{config['wifi_ssid']}"
    psk="{config['wifi_password']}"
    key_mgmt=WPA-PSK
}}
"""
        
        # Write WiFi config to temporary file
        with open('/tmp/wpa_supplicant.conf', 'w') as f:
            f.write(wifi_config)
        
        print("Configuration saved successfully")
        return jsonify({'success': True, 'message': 'Configuration saved!'})
        
    except Exception as e:
        print(f"Configuration error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/finalize', methods=['POST'])
def finalize():
    """Complete setup and switch to normal operation"""
    try:
        print("Starting finalization process...")
        
        # Load saved configuration
        if not os.path.exists(SETUP_CONFIG_FILE):
            return jsonify({'error': 'No configuration found'}), 400
        
        with open(SETUP_CONFIG_FILE, 'r') as f:
            config = json.load(f)
        
        # Apply WiFi configuration
        subprocess.run(['sudo', 'cp', '/tmp/wpa_supplicant.conf', 
                       '/etc/wpa_supplicant/wpa_supplicant.conf'], check=True)
        
        # Create installation script that will run after reboot
        install_script = f"""#!/bin/bash
# Auto-generated installation script
set -e

echo "🚀 Starting GrannyTV installation..."

USER_NAME="{config['username']}"
INSTALL_PATH="{config['install_path']}"
STREAM_SOURCE="{config.get('stream_source', '')}"

# Switch to target user
sudo -u "$USER_NAME" bash << 'EOF'
cd ~

# Create installation directory
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"

# Clone repository
if [ ! -d ".git" ]; then
    git clone https://github.com/gljeremy/grannytv-client.git .
else
    git pull origin main
fi

# Run the main setup script
chmod +x platforms/linux/pi-setup.sh
./platforms/linux/pi-setup.sh

echo "✅ GrannyTV installation complete!"
EOF

# Clean up setup mode
/home/{os.getenv('USER')}/gtv-setup/restore-normal-wifi.sh
"""
        
        # Write and schedule installation script
        with open('/tmp/grannytv-install.sh', 'w') as f:
            f.write(install_script)
        
        os.chmod('/tmp/grannytv-install.sh', 0o755)
        
        # Create service to run installation after reboot
        install_service = """[Unit]
Description=GrannyTV Installation
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/tmp/grannytv-install.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
"""
        
        with open('/tmp/grannytv-install.service', 'w') as f:
            f.write(install_service)
        
        subprocess.run(['sudo', 'cp', '/tmp/grannytv-install.service', 
                       '/etc/systemd/system/'], check=True)
        subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
        subprocess.run(['sudo', 'systemctl', 'enable', 'grannytv-install'], check=True)
        
        print("Finalization complete - scheduling reboot")
        return jsonify({'success': True, 'message': 'Setup complete! Rebooting in 5 seconds...'})
        
    except Exception as e:
        print(f"Finalization error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/reboot', methods=['POST'])
def reboot():
    """Reboot the system"""
    try:
        # Schedule reboot in 3 seconds
        threading.Timer(3.0, lambda: subprocess.run(['sudo', 'reboot'])).start()
        return jsonify({'success': True, 'message': 'Rebooting now...'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Static file serving for mobile assets
@app.route('/favicon.ico')
def favicon():
    return '', 204

if __name__ == '__main__':
    print("🌐 Starting GrannyTV Setup Server")
    print("📱 Connect to WiFi: GrannyTV-Setup (password: SetupMe123)")
    print("🔗 Setup URL: http://192.168.4.1")
    
    # Ensure log directory exists
    os.makedirs('/tmp/grannytv-logs', exist_ok=True)
    
    app.run(host='0.0.0.0', port=80, debug=False)