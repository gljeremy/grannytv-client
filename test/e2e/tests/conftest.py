"""
Test configuration and fixtures for GrannyTV E2E tests
"""
import pytest
import requests
import time
import os
import subprocess

# Test configuration
PI_HOST = os.getenv('PI_SIMULATOR_HOST', 'pi-simulator')
PI_PORT = int(os.getenv('PI_SIMULATOR_PORT', '8080'))
TEST_TIMEOUT = int(os.getenv('TEST_TIMEOUT', '300'))

@pytest.fixture(scope="session")
def pi_simulator():
    """Fixture for Pi simulator container"""
    return {
        'host': PI_HOST,
        'port': PI_PORT,
        'base_url': f'http://{PI_HOST}:{PI_PORT}'
    }

@pytest.fixture(scope="session")
def wait_for_pi_ready(pi_simulator):
    """Wait for Pi simulator to be ready"""
    max_retries = 30
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            response = requests.get(f"{pi_simulator['base_url']}/health", timeout=5)
            if response.status_code == 200:
                return True
        except requests.exceptions.RequestException:
            pass
        
        time.sleep(retry_delay)
    
    pytest.fail(f"Pi simulator not ready after {max_retries * retry_delay} seconds")

@pytest.fixture
def execute_on_pi():
    """Execute commands on Pi simulator"""
    def _execute(command, cwd="/home/jeremy/gtv", timeout=30):
        cmd = [
            'docker', 'exec', 'grannytv-pi-sim',
            'sudo', '-u', 'jeremy', 'bash', '-c',
            f'cd {cwd} && {command}'
        ]
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        return {
            'returncode': result.returncode,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'success': result.returncode == 0
        }
    
    return _execute

@pytest.fixture
def execute_on_pi_root():
    """Execute commands on Pi simulator as root"""
    def _execute(command, cwd="/home/jeremy/gtv", timeout=30):
        cmd = [
            'docker', 'exec', 'grannytv-pi-sim',
            'bash', '-c',
            f'cd {cwd} && {command}'
        ]
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        return {
            'returncode': result.returncode,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'success': result.returncode == 0
        }
    
    return _execute

@pytest.fixture
def web_client(pi_simulator):
    """HTTP client for web server testing"""
    session = requests.Session()
    session.timeout = 10
    return session

@pytest.fixture
def cleanup_pi():
    """Cleanup Pi simulator state after tests"""
    yield
    
    # Cleanup commands
    cleanup_commands = [
        'sudo systemctl stop grannytv-setup 2>/dev/null || true',
        'sudo systemctl stop hostapd 2>/dev/null || true',
        'sudo systemctl stop dnsmasq 2>/dev/null || true',
        'sudo pkill -f "python3.*setup_server.py" 2>/dev/null || true',
        'sudo rm -f /var/lib/grannytv-setup-mode',
        'sudo rm -rf /opt/grannytv-setup',
        'sudo ip addr flush dev wlan0 2>/dev/null || true'
    ]
    
    for cmd in cleanup_commands:
        subprocess.run([
            'docker', 'exec', 'grannytv-pi-sim',
            'bash', '-c', cmd
        ], capture_output=True)

@pytest.fixture
def mock_wifi_networks():
    """Mock WiFi network scan results"""
    return [
        {
            "ssid": "TestNetwork1",
            "signal": -45,
            "security": "WPA2",
            "frequency": "2.4GHz"
        },
        {
            "ssid": "TestNetwork2", 
            "signal": -67,
            "security": "WPA3",
            "frequency": "5GHz"
        },
        {
            "ssid": "OpenNetwork",
            "signal": -52,
            "security": "Open",
            "frequency": "2.4GHz"
        }
    ]

@pytest.fixture
def test_iptv_streams():
    """Test IPTV stream URLs"""
    return [
        {
            "name": "Test Stream 1",
            "url": "http://test.example.com/stream1.m3u8",
            "group": "Test"
        },
        {
            "name": "Test Stream 2", 
            "url": "http://test.example.com/stream2.m3u8",
            "group": "Test"
        }
    ]

@pytest.fixture
def test_config():
    """Test configuration data"""
    return {
        "wifi_ssid": "TestNetwork1",
        "wifi_password": "testpassword123",
        "user_name": "testuser",
        "install_path": "/home/testuser/grannytv",
        "iptv_url": "http://test.example.com/playlist.m3u8",
        "auto_start": True
    }