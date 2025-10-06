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
            else:
                # Try alternative location
                alt_config_file = os.path.expanduser('~/grannytv_setup_config.json')
                if os.path.exists(alt_config_file):
                    print(f"Loading config from alternative location: {alt_config_file}")
                    with open(alt_config_file, 'r') as f:
                        self.config = json.load(f)
                else:
                    self.config = {}
        except Exception as e:
            print(f"Error loading config: {e}")
            self.config = {}
    
    def save_config(self, new_config):
        """Save configuration to file"""
        self.config.update(new_config)
        try:
            # Ensure the directory exists
            os.makedirs(os.path.dirname(SETUP_CONFIG_FILE), exist_ok=True)
            with open(SETUP_CONFIG_FILE, 'w') as f:
                json.dump(self.config, f, indent=2)
            print(f"Configuration saved successfully to {SETUP_CONFIG_FILE}")
            return True
        except Exception as e:
            print(f"Error saving config to {SETUP_CONFIG_FILE}: {e}")
            # Try alternative location if /tmp fails
            try:
                alt_config_file = os.path.expanduser('~/grannytv_setup_config.json')
                print(f"Attempting to save to alternative location: {alt_config_file}")
                with open(alt_config_file, 'w') as f:
                    json.dump(self.config, f, indent=2)
                print(f"Configuration saved successfully to alternative location: {alt_config_file}")
                return True
            except Exception as e2:
                print(f"Error saving config to alternative location: {e2}")
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
        
        # Input validation and sanitization
        def validate_and_sanitize_config(config):
            """Validate and sanitize configuration inputs"""
            if not isinstance(config, dict):
                raise ValueError("Configuration must be a JSON object")
            
            # Validate required fields
            required = ['wifi_ssid', 'wifi_password', 'username', 'install_path']
            missing = [field for field in required if not config.get(field) or not isinstance(config.get(field), str)]
            if missing:
                raise ValueError(f'Missing or invalid required fields: {", ".join(missing)}')
            
            # Sanitize WiFi SSID (alphanumeric, spaces, dashes, underscores only)
            wifi_ssid = str(config['wifi_ssid']).strip()
            if not re.match(r'^[a-zA-Z0-9\s\-_]{1,32}$', wifi_ssid):
                raise ValueError("WiFi SSID contains invalid characters or is too long (max 32 chars)")
            
            # Sanitize WiFi password (no shell metacharacters)
            wifi_password = str(config['wifi_password'])
            if len(wifi_password) < 8 or len(wifi_password) > 63:
                raise ValueError("WiFi password must be 8-63 characters long")
            # Check for dangerous characters that could cause command injection
            dangerous_chars = ['$', '`', '\\', '"', "'", ';', '|', '&', '\n', '\r']
            if any(char in wifi_password for char in dangerous_chars):
                raise ValueError("WiFi password contains invalid characters")
            
            # Validate install path (must be within allowed directories)
            install_path = str(config['install_path']).strip()
            allowed_paths = ['/home/', '/opt/grannytv']
            if not any(install_path.startswith(allowed) for allowed in allowed_paths):
                raise ValueError("Install path must be within /home/ or /opt/grannytv")
            # Prevent path traversal
            if '..' in install_path or install_path.startswith('/'):
                if not install_path.startswith('/home/') and not install_path.startswith('/opt/grannytv'):
                    raise ValueError("Invalid install path - path traversal detected")
            
            # Sanitize username (alphanumeric and underscore only)
            username = str(config['username']).strip()
            if not re.match(r'^[a-zA-Z0-9_]{3,32}$', username):
                raise ValueError("Username must be 3-32 characters, alphanumeric and underscore only")
            
            return {
                'wifi_ssid': wifi_ssid,
                'wifi_password': wifi_password,
                'install_path': os.path.abspath(install_path),  # Normalize path
                'username': username,
                'wifi_country': config.get('wifi_country', 'US'),
                'tv_name': str(config.get('tv_name', 'GrannyTV')).strip()[:32]  # Limit length
            }
        
        # Validate and sanitize input
        try:
            sanitized_config = validate_and_sanitize_config(config)
        except ValueError as e:
            return jsonify({'error': str(e)}), 400
        
        # Save sanitized configuration
        if not setup_config.save_config(sanitized_config):
            return jsonify({'error': 'Failed to save configuration'}), 500
        
        # Create user if needed (using sanitized username)
        current_user = os.getenv('USER', 'pi')
        if sanitized_config['username'] != current_user and sanitized_config['username'] != 'pi':
            try:
                # Check if user already exists first
                check_user = subprocess.run(['id', sanitized_config['username']], 
                                          capture_output=True, text=True)
                if check_user.returncode == 0:
                    print(f"User {sanitized_config['username']} already exists, skipping creation")
                else:
                    # User doesn't exist, create it
                    subprocess.run(['sudo', 'useradd', '-m', '-s', '/bin/bash', 
                                   sanitized_config['username']], check=True)
                    print(f"Created user: {sanitized_config['username']}")
                
                # Always try to ensure user has correct groups (safe to run multiple times)
                subprocess.run(['sudo', 'usermod', '-a', '-G', 
                               'sudo,video,audio,dialout', sanitized_config['username']], check=True)
                print(f"Updated groups for user: {sanitized_config['username']}")
                
                # Grant passwordless sudo access for reboot (needed for setup completion)
                sudoers_entry = f"{sanitized_config['username']} ALL=(ALL) NOPASSWD: /sbin/reboot"
                with open(f'/tmp/grannytv-sudoers-{sanitized_config["username"]}', 'w') as f:
                    f.write(sudoers_entry + '\n')
                subprocess.run(['sudo', 'cp', f'/tmp/grannytv-sudoers-{sanitized_config["username"]}', 
                               f'/etc/sudoers.d/grannytv-{sanitized_config["username"]}'], check=True)
                subprocess.run(['sudo', 'chmod', '0440', f'/etc/sudoers.d/grannytv-{sanitized_config["username"]}'], check=True)
                print(f"Granted sudo reboot permissions to user: {sanitized_config['username']}")
                
            except subprocess.CalledProcessError as e:
                # Check if it's a "user already exists" error (exit code 9)
                if e.returncode == 9:
                    print(f"User {sanitized_config['username']} already exists (exit code 9), continuing")
                else:
                    return jsonify({'error': f'Failed to create user: {e}'}), 500
        
        # Create WiFi configuration with proper escaping
        # Use shlex.quote to prevent injection attacks
        import shlex
        wifi_config = f"""country={sanitized_config['wifi_country']}
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={{
    ssid={shlex.quote(sanitized_config['wifi_ssid'])}
    psk={shlex.quote(sanitized_config['wifi_password'])}
    key_mgmt=WPA-PSK
}}
"""
        
        # Write WiFi config to temporary file
        try:
            with open('/tmp/wpa_supplicant.conf', 'w') as f:
                f.write(wifi_config)
            print("WiFi configuration written to /tmp/wpa_supplicant.conf")
        except PermissionError as e:
            print(f"Permission denied writing to /tmp/wpa_supplicant.conf: {e}")
            # Try alternative location in user's home directory
            try:
                alt_wifi_config = os.path.expanduser('~/wpa_supplicant.conf')
                with open(alt_wifi_config, 'w') as f:
                    f.write(wifi_config)
                print(f"WiFi configuration written to alternative location: {alt_wifi_config}")
            except Exception as e2:
                print(f"Error writing WiFi config to alternative location: {e2}")
                return jsonify({'error': f'Permission denied: {e}'}), 500
        except Exception as e:
            print(f"Error writing WiFi config: {e}")
            return jsonify({'error': f'Failed to write network configuration: {e}'}), 500
        
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
        config = None
        if os.path.exists(SETUP_CONFIG_FILE):
            with open(SETUP_CONFIG_FILE, 'r') as f:
                config = json.load(f)
        else:
            # Try alternative location
            alt_config_file = os.path.expanduser('~/grannytv_setup_config.json')
            if os.path.exists(alt_config_file):
                print(f"Loading config from alternative location: {alt_config_file}")
                with open(alt_config_file, 'r') as f:
                    config = json.load(f)
        
        if config is None:
            return jsonify({'error': 'No configuration found'}), 400
        
        # Apply WiFi configuration
        try:
            # Try primary location first
            if os.path.exists('/tmp/wpa_supplicant.conf'):
                subprocess.run(['sudo', 'cp', '/tmp/wpa_supplicant.conf', 
                               '/etc/wpa_supplicant/wpa_supplicant.conf'], check=True)
                print("WiFi configuration applied successfully from /tmp")
            else:
                # Try alternative location
                alt_wifi_config = os.path.expanduser('~/wpa_supplicant.conf')
                if os.path.exists(alt_wifi_config):
                    subprocess.run(['sudo', 'cp', alt_wifi_config, 
                                   '/etc/wpa_supplicant/wpa_supplicant.conf'], check=True)
                    print(f"WiFi configuration applied successfully from {alt_wifi_config}")
                else:
                    print("Warning: No WiFi configuration file found")
        except subprocess.CalledProcessError as e:
            print(f"Warning: Could not apply WiFi configuration: {e}")
            # Continue with cleanup anyway - this might be a test environment
        
        # IMMEDIATELY disable hotspot and switch to client mode
        print("Disabling hotspot and switching to client mode...")
        try:
            # Stop hotspot services
            subprocess.run(['sudo', 'systemctl', 'stop', 'hostapd'], check=False)
            subprocess.run(['sudo', 'systemctl', 'stop', 'dnsmasq'], check=False)
            subprocess.run(['sudo', 'systemctl', 'disable', 'hostapd'], check=False)
            subprocess.run(['sudo', 'systemctl', 'disable', 'dnsmasq'], check=False)
            
            # Clear wlan0 interface
            subprocess.run(['sudo', 'ip', 'addr', 'flush', 'dev', 'wlan0'], check=False)
            
            # Remove iptables NAT rules
            subprocess.run(['sudo', 'iptables', '-t', 'nat', '-F', 'PREROUTING'], check=False)
            
            # CRITICAL: Remove hotspot configuration from dhcpcd.conf
            # This prevents the static IP 192.168.4.1 from being set on reboot
            try:
                # Use sed to remove the hotspot configuration section
                # This is more reliable than reading/writing as it handles permissions correctly
                subprocess.run([
                    'sudo', 'sed', '-i',
                    '/# GrannyTV Setup Hotspot Configuration/,+3d',
                    '/etc/dhcpcd.conf'
                ], check=True)
                print("✅ Removed hotspot configuration from dhcpcd.conf")
            except Exception as e:
                print(f"Warning: Could not clean dhcpcd.conf: {e}")
                # Try backup restore as fallback
                try:
                    if os.path.exists('/etc/dhcpcd.conf.backup'):
                        subprocess.run(['sudo', 'cp', '/etc/dhcpcd.conf.backup', '/etc/dhcpcd.conf'], check=True)
                        print("✅ Restored dhcpcd.conf from backup")
                except Exception as e2:
                    print(f"Warning: Backup restore also failed: {e2}")
            
            # Check if system uses NetworkManager or dhcpcd
            nm_active = subprocess.run(['systemctl', 'is-active', 'NetworkManager'], 
                                      capture_output=True, text=True).returncode == 0
            
            if nm_active:
                # Use NetworkManager
                print("Using NetworkManager for network management")
                subprocess.run(['sudo', 'systemctl', 'enable', 'NetworkManager'], check=False)
                subprocess.run(['sudo', 'systemctl', 'restart', 'NetworkManager'], check=False)
                # Stop dhcpcd to avoid conflicts
                subprocess.run(['sudo', 'systemctl', 'stop', 'dhcpcd'], check=False)
                subprocess.run(['sudo', 'systemctl', 'disable', 'dhcpcd'], check=False)
            else:
                # Use dhcpcd (traditional Raspberry Pi)
                print("Using dhcpcd for network management")
                subprocess.run(['sudo', 'systemctl', 'enable', 'wpa_supplicant'], check=False)
                subprocess.run(['sudo', 'systemctl', 'restart', 'wpa_supplicant'], check=False)
                subprocess.run(['sudo', 'systemctl', 'enable', 'dhcpcd'], check=False)
                subprocess.run(['sudo', 'systemctl', 'restart', 'dhcpcd'], check=False)
            
            print("Hotspot disabled, switching to client mode")
        except Exception as e:
            print(f"Warning: Error during hotspot cleanup: {e}")
            # Continue anyway - the installation script will also try to clean up
        
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

# Clean up any remaining setup mode artifacts
if [ -f /opt/grannytv-setup/restore-normal-wifi.sh ]; then
    echo "Running final cleanup..."
    /opt/grannytv-setup/restore-normal-wifi.sh
fi
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
        
        # Create immediate cleanup script and run it in background
        immediate_cleanup = """#!/bin/bash
# Immediate cleanup to switch from hotspot to client mode
echo "Starting immediate WiFi switch..."

# Remove setup mode flag FIRST - this prevents services from restarting
sudo rm -f /var/lib/grannytv-setup-mode

# Stop hotspot services immediately
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl disable hostapd 2>/dev/null || true
sudo systemctl disable dnsmasq 2>/dev/null || true

# Clear the static IP from wlan0
sudo ip addr flush dev wlan0 2>/dev/null || true
sudo ip link set wlan0 down 2>/dev/null || true

# Remove iptables rules
sudo iptables -t nat -F PREROUTING 2>/dev/null || true

# CRITICAL: Clean up dhcpcd.conf to remove static IP configuration
# This prevents 192.168.4.1 from being set on reboot
if [ -f /etc/dhcpcd.conf ]; then
    echo "Cleaning dhcpcd.conf..."
    
    # Remove GrannyTV hotspot configuration section (comment line + 3 config lines)
    sudo sed -i '/# GrannyTV Setup Hotspot Configuration/,+3d' /etc/dhcpcd.conf
    echo "Removed hotspot configuration from dhcpcd.conf"
fi

# Decide which network manager to use
if systemctl is-active --quiet NetworkManager; then
    echo "Using NetworkManager..."
    # Remove hotspot NetworkManager connection profile
    sudo nmcli con delete GrannyTV-Hotspot 2>/dev/null || true
    
    # Stop and disable dhcpcd to avoid conflicts
    sudo systemctl stop dhcpcd 2>/dev/null || true
    sudo systemctl disable dhcpcd 2>/dev/null || true
    
    # Enable NetworkManager
    sudo systemctl enable NetworkManager 2>/dev/null || true
    sudo systemctl restart NetworkManager 2>/dev/null || true
    
    # Bring interface back up and let NetworkManager manage it
    sudo ip link set wlan0 up 2>/dev/null || true
    sudo nmcli device set wlan0 managed yes 2>/dev/null || true
else
    echo "Using dhcpcd and wpa_supplicant..."
    # Traditional Raspberry Pi network setup
    sudo systemctl enable wpa_supplicant 2>/dev/null || true
    sudo systemctl restart wpa_supplicant 2>/dev/null || true
    sudo systemctl enable dhcpcd 2>/dev/null || true
    sudo systemctl restart dhcpcd 2>/dev/null || true
fi

# Give it a moment to connect
sleep 5

# Stop and disable setup services  
sudo systemctl disable grannytv-setup 2>/dev/null || true
sudo systemctl stop grannytv-setup 2>/dev/null || true
sudo systemctl disable grannytv-prepare 2>/dev/null || true
sudo systemctl stop grannytv-prepare 2>/dev/null || true

# Wait before rebooting to allow web response and WiFi switch
sleep 15

# Reboot the system
echo "Rebooting system to complete setup..."
sudo reboot

echo "Immediate cleanup complete - Pi should now be on home WiFi"
"""
        
        with open('/tmp/immediate-cleanup.sh', 'w') as f:
            f.write(immediate_cleanup)
        
        os.chmod('/tmp/immediate-cleanup.sh', 0o755)
        
        # Create systemd service for reboot (more reliable than sudo from web server)
        reboot_service = """[Unit]
Description=GrannyTV Setup Reboot
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/reboot
User=root

[Install]
WantedBy=multi-user.target
"""
        
        with open('/tmp/grannytv-reboot.service', 'w') as f:
            f.write(reboot_service)
        
        subprocess.run(['sudo', 'cp', '/tmp/grannytv-reboot.service', 
                       '/etc/systemd/system/'], check=True)
        subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
        subprocess.run(['sudo', 'systemctl', 'start', 'grannytv-reboot'], check=True)
        
        print("Immediate cleanup and reboot scheduled in background")
        
        return jsonify({'success': True, 'message': 'Setup complete! System will reboot in 15 seconds.', 'rebooting': True})
        
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
    print(f"📁 Working directory: {os.getcwd()}")
    print("📱 Connect to WiFi: GrannyTV-Setup (password: SetupMe123)")
    print("🔗 Setup URL: http://192.168.4.1")
    print("🔗 Direct URL: http://192.168.4.1:8080")
    
    # Ensure log directory exists
    os.makedirs('/tmp/grannytv-logs', exist_ok=True)
    
    app.run(host='0.0.0.0', port=8080, debug=False)