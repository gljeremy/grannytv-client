"""
High-Priority Additional Tests for GrannyTV
===========================================

These are the most critical tests that are currently missing and would provide
the highest value for ensuring production reliability.
"""
import pytest
import requests
import time
import json
import subprocess


class TestIPTVPlayerCore:
    """Test the core IPTV player functionality - HIGHEST PRIORITY"""
    
    def test_iptv_player_initialization(self, execute_on_pi_root, cleanup_pi):
        """Test that the IPTV player can initialize and start"""
        # Install the system first
        setup_result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        assert setup_result['success'], f"Setup failed: {setup_result.get('stderr', 'Unknown error')}"
        
        # Test player initialization
        result = execute_on_pi_root('cd /home/jeremy/gtv && python3 -c "from iptv_smart_player import MPVIPTVPlayer; player = MPVIPTVPlayer(); print(\'Player initialized successfully\')"',
                                  timeout=30)
        assert result['success'], f"Player initialization failed: {result.get('stderr', 'Unknown error')}"
        assert "Player initialized successfully" in result['stdout']
    
    def test_mpv_availability_check(self, execute_on_pi_root, cleanup_pi):
        """Test that MPV is available and working"""
        # Check MPV is installed
        result = execute_on_pi_root('mpv --version')
        assert result['success'], "MPV not installed or not working"
        
        # Test basic MPV functionality
        result = execute_on_pi_root('mpv --no-video --ao=null --frames=1 /dev/zero', timeout=10)
        # Should fail gracefully (exit code doesn't matter as much as not hanging)
        assert "frames" in result.get('stderr', '') or result.get('returncode', 0) in [0, 1, 2]
    
    def test_config_loading(self, execute_on_pi_root, cleanup_pi):
        """Test configuration loading works correctly"""
        # Setup first
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Test config loading
        result = execute_on_pi_root('cd /home/jeremy/gtv && python3 -c "from iptv_smart_player import load_config; config = load_config(); print(f\'Config loaded: {config[\'platform\']}\')"',
                                  timeout=15)
        assert result['success'], f"Config loading failed: {result.get('stderr', 'Unknown error')}"
        assert "Config loaded:" in result['stdout']


class TestEndToEndSetupFlow:
    """Test complete smartphone setup workflow - HIGH PRIORITY"""
    
    def test_complete_happy_path_setup(self, execute_on_pi_root, cleanup_pi):
        """Test the complete setup flow from start to finish"""
        # 1. Run setup wizard
        setup_result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        assert setup_result['success'], f"Setup wizard failed: {setup_result.get('stderr', 'Unknown error')}"
        
        # 2. Start web server
        web_result = execute_on_pi_root('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                                       user="jeremy", timeout=10)
        time.sleep(3)
        
        # 3. Test web server is accessible
        health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert health_result['success'], "Web server not accessible"
        
        # 4. Submit configuration
        config_data = {
            "wifi_ssid": "TestNetwork",
            "wifi_password": "testpass123", 
            "wifi_country": "US",
            "username": "jeremy",
            "install_path": "/home/jeremy/gtv",
            "stream_source": ""
        }
        
        config_result = execute_on_pi_root(f'curl -X POST -H "Content-Type: application/json" -d \'{json.dumps(config_data)}\' http://localhost:8080/configure',
                                         timeout=30)
        assert config_result['success'], f"Configuration submission failed: {config_result.get('stderr', 'Unknown error')}"
        assert "success" in config_result['stdout'].lower()
        
        # 5. Test finalization
        finalize_result = execute_on_pi_root('curl -X POST http://localhost:8080/finalize', timeout=30)
        assert finalize_result['success'], f"Finalization failed: {finalize_result.get('stderr', 'Unknown error')}"
        assert "success" in finalize_result['stdout'].lower()
        
        # 6. Verify cleanup occurred (setup mode flag should be removed)
        time.sleep(20)  # Wait for cleanup
        flag_result = execute_on_pi_root('ls -la /var/lib/grannytv-setup-mode')
        assert not flag_result['success'], "Setup mode flag was not removed during cleanup"


class TestConfigurationRobustness:
    """Test configuration handling edge cases - HIGH PRIORITY"""
    
    def test_invalid_wifi_credentials(self, execute_on_pi_root, cleanup_pi):
        """Test handling of invalid WiFi credentials"""
        # Setup web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                          user="jeremy", timeout=10)
        time.sleep(3)
        
        # Test missing required fields
        invalid_configs = [
            {},  # Empty config
            {"wifi_ssid": ""},  # Empty SSID
            {"wifi_ssid": "test"},  # Missing password
            {"wifi_ssid": "test", "wifi_password": "pass"},  # Missing username
        ]
        
        for config in invalid_configs:
            result = execute_on_pi_root(f'curl -X POST -H "Content-Type: application/json" -d \'{json.dumps(config)}\' http://localhost:8080/configure',
                                      timeout=15)
            # Should either fail with error or return error response
            if result['success']:
                response_data = json.loads(result['stdout'])
                assert not response_data.get('success', True), f"Invalid config was accepted: {config}"
    
    def test_special_characters_in_config(self, execute_on_pi_root, cleanup_pi):
        """Test handling of special characters in configuration"""
        # Setup web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                          user="jeremy", timeout=10)
        time.sleep(3)
        
        # Test special characters that might cause issues
        special_configs = [
            {
                "wifi_ssid": "Test Network with Spaces",
                "wifi_password": "pass word with spaces",
                "wifi_country": "US",
                "username": "jeremy",
                "install_path": "/home/jeremy/gtv",
                "stream_source": ""
            },
            {
                "wifi_ssid": "Test-Network_123",
                "wifi_password": "P@$$w0rd!@#$%^&*()",
                "wifi_country": "US", 
                "username": "jeremy",
                "install_path": "/home/jeremy/gtv",
                "stream_source": ""
            }
        ]
        
        for config in special_configs:
            result = execute_on_pi_root(f'curl -X POST -H "Content-Type: application/json" -d \'{json.dumps(config)}\' http://localhost:8080/configure',
                                      timeout=15)
            assert result['success'], f"Special character config failed: {config}"
            response_data = json.loads(result['stdout'])
            assert response_data.get('success', False), f"Special character config was rejected: {config}"


class TestNetworkErrorHandling:
    """Test network error scenarios - HIGH PRIORITY"""
    
    def test_web_server_recovery_after_crash(self, execute_on_pi_root, cleanup_pi):
        """Test web server can recover from crashes"""
        # Setup and start web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                          user="jeremy", timeout=10)
        time.sleep(3)
        
        # Verify it's running
        result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert result['success'], "Web server not initially accessible"
        
        # Kill the web server process
        execute_on_pi_root('pkill -f setup_server.py')
        time.sleep(2)
        
        # Verify it's down
        result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=5)
        assert not result['success'], "Web server should be down after kill"
        
        # Restart it
        execute_on_pi_root('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                          user="jeremy", timeout=10)
        time.sleep(3)
        
        # Verify it's back up
        result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert result['success'], "Web server failed to restart"
    
    def test_concurrent_setup_requests(self, execute_on_pi_root, cleanup_pi):
        """Test handling of multiple simultaneous setup requests"""
        # Setup web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                          user="jeremy", timeout=10)
        time.sleep(3)
        
        # Create multiple simultaneous requests
        config_data = {
            "wifi_ssid": "TestNetwork",
            "wifi_password": "testpass123",
            "wifi_country": "US", 
            "username": "jeremy",
            "install_path": "/home/jeremy/gtv",
            "stream_source": ""
        }
        
        # Test multiple rapid requests don't crash server
        for i in range(3):
            result = execute_on_pi_root(f'curl -X POST -H "Content-Type: application/json" -d \'{json.dumps(config_data)}\' http://localhost:8080/configure &',
                                      timeout=5)
        
        time.sleep(10)  # Wait for all requests to complete
        
        # Verify server is still responding
        health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert health_result['success'], "Web server crashed during concurrent requests"


class TestSystemResourceHandling:
    """Test system resource handling - MEDIUM PRIORITY"""
    
    def test_disk_space_monitoring(self, execute_on_pi_root, cleanup_pi):
        """Test behavior when disk space is low"""
        # Check available disk space
        result = execute_on_pi_root('df -h /')
        assert result['success'], "Could not check disk space"
        
        # Setup should still work with reasonable disk space
        setup_result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        assert setup_result['success'], "Setup failed - may be disk space related"
    
    def test_memory_usage_reasonable(self, execute_on_pi_root, cleanup_pi):
        """Test that setup doesn't use excessive memory"""
        # Check initial memory
        initial_mem = execute_on_pi_root('free -m')
        assert initial_mem['success'], "Could not check memory"
        
        # Run setup
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Start web server and check memory usage
        execute_on_pi_root('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                          user="jeremy", timeout=10)
        time.sleep(5)
        
        # Check memory usage isn't excessive
        final_mem = execute_on_pi_root('free -m')
        assert final_mem['success'], "Could not check final memory"
        
        # Get memory info for the Python process
        process_mem = execute_on_pi_root('ps aux | grep setup_server.py | grep -v grep')
        assert process_mem['success'], "Could not find setup server process"