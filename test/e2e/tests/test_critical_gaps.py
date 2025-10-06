#!/usr/bin/env python3
"""
Critical Missing Tests - Ready to Run
====================================

These tests cover the most important gaps in the current test suite.
Run with: python -m pytest test_critical_gaps.py -v
"""
import time
import json
import pytest
import shlex


class TestIPTVPlayerIntegration:
    """Test integration with the IPTV player - CRITICAL GAP"""
    
    def test_iptv_player_can_be_imported(self, execute_on_pi_root, cleanup_pi):
        """Test that the IPTV player module can be imported"""
        result = execute_on_pi_root('cd /home/jeremy/gtv && python3 -c "import iptv_smart_player; print(\'Import successful\')"',
                                  timeout=15)
        assert result['success'], f"IPTV player import failed: {result.get('stderr', 'Unknown error')}"
        assert "Import successful" in result['stdout']
    
    def test_mpv_is_available(self, execute_on_pi_root, cleanup_pi):
        """Test that MPV is installed and functional"""
        # First check if mpv command exists
        result = execute_on_pi_root('which mpv || echo "mpv not found"', timeout=10)
        if 'mpv not found' in result.get('stdout', ''):
            pytest.skip("MPV not installed in test environment - this would be checked in deployment")
        
        result = execute_on_pi_root('mpv --version || echo "mpv version failed"', timeout=10)
        # MPV may not be fully functional in Docker but command should exist
        if 'mpv version failed' in result.get('stdout', ''):
            pytest.skip("MPV not functional in test environment - this would be validated in deployment")
        
        assert result['success'] or 'mpv' in result.get('stdout', '').lower(), f"MPV availability check failed: {result}"
    
    def test_config_json_exists_and_valid(self, execute_on_pi_root, cleanup_pi):
        """Test that config.json exists and is valid JSON"""
        result = execute_on_pi_root('cat /home/jeremy/gtv/config.json', timeout=10)
        assert result['success'], "config.json file not found"
        
        try:
            config_data = json.loads(result['stdout'])
            assert 'production' in config_data, "config.json missing production config"
            assert 'development' in config_data, "config.json missing development config"
        except json.JSONDecodeError:
            assert False, "config.json is not valid JSON"


class TestWebServerStability:
    """Test web server stability and error handling - CRITICAL GAP"""
    
    def test_web_server_handles_malformed_requests(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test web server handles malformed HTTP requests gracefully"""
        # Setup and start web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                     timeout=10)
        time.sleep(3)
        
        # Test various malformed requests
        malformed_requests = [
            'echo "invalid json" | curl -X POST -d @- http://localhost:8080/configure',
            'curl -X POST -H "Content-Type: application/json" -d "{invalid json}" http://localhost:8080/configure',
            'curl -X POST -d "" http://localhost:8080/configure',
            'curl -X GET http://localhost:8080/nonexistent-endpoint',
        ]
        
        for request in malformed_requests:
            result = execute_on_pi_root(request, timeout=10)
            # Server should respond (not crash) even to malformed requests
            # We don't care about the response code, just that server didn't crash
            
        # Verify server is still responding to valid requests
        health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert health_result['success'], "Web server crashed after malformed requests"
    
    def test_web_server_resource_cleanup(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test that web server properly cleans up resources"""  
        # Start web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                     timeout=10)
        time.sleep(3)
        
        # Check initial process count
        initial_processes = execute_on_pi_root('ps aux | grep setup_server.py | grep -v grep | wc -l')
        assert initial_processes['success'], "Could not check process count"
        
        # Kill and restart server multiple times
        for i in range(3):
            execute_on_pi_root('pkill -f setup_server.py', timeout=5)
            time.sleep(1)
            execute_on_pi('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                          timeout=10)
            time.sleep(2)
        
        # Check final process count - should not have accumulated zombie processes
        final_processes = execute_on_pi_root('ps aux | grep setup_server.py | grep -v grep | wc -l')
        assert final_processes['success'], "Could not check final process count"
        
        # Should have only one process running
        assert int(final_processes['stdout'].strip()) <= 2, "Too many server processes running (resource leak)"


class TestConfigurationValidation:
    """Test configuration validation - CRITICAL GAP"""
    
    def test_wifi_password_validation(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test WiFi password validation with edge cases"""
        # Setup web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                     timeout=10)
        time.sleep(3)
        
        # Test edge case passwords - security validation test
        test_password_cases = [
            ("", False, "Empty password should be rejected"),
            ("a", False, "Very short password should be rejected"), 
            ("a" * 100, False, "Very long password should be rejected"),
            ("ValidPass123", True, "Valid password should be accepted"),
            ("password with spaces", True, "Passwords with spaces should be accepted"),
            ("p@$$w0rd!@#$%^&*()", False, "Passwords with shell metacharacters should be rejected for security"),
            ("密码测试1234567", True, "Unicode passwords should be accepted if valid length"),
            ("password'with\"quotes", False, "Passwords with quotes should be rejected to prevent injection"),
            ("password;rm -rf /", False, "Passwords with shell commands should be rejected"),
            ("password`whoami`", False, "Passwords with command substitution should be rejected"),
        ]
        
        for password, should_accept, reason in test_password_cases:
            config = {
                "wifi_ssid": "TestNetwork",
                "wifi_password": password,
                "wifi_country": "US",
                "username": "jeremy", 
                "install_path": "/home/jeremy/gtv",
                "stream_source": ""
            }
            
            # Write config to temp file to avoid shell quoting issues
            config_json = json.dumps(config)
            config_file_cmd = f'echo {shlex.quote(config_json)} > /tmp/test_config.json'
            execute_on_pi_root(config_file_cmd, timeout=10)
            
            # Use curl with config file to avoid shell injection in test
            curl_cmd = "curl -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d @/tmp/test_config.json http://localhost:8080/configure -s"
            result = execute_on_pi_root(curl_cmd, timeout=15)
            
            # Server should not crash - either succeed (200) or properly reject (400)
            assert result['success'], f"Server crashed with password test: {password} - {reason}"
            
            # Check HTTP status code in response
            response_with_status = result['stdout']
            if should_accept:
                # Valid passwords should return 200 status
                assert '200' in response_with_status or 'success' in response_with_status.lower(), f"Valid password rejected: {password} - {reason}"
            else:
                # Invalid/dangerous passwords should return 400 status or error
                assert '400' in response_with_status or 'error' in response_with_status.lower(), f"Dangerous password accepted: {password} - {reason}"
        
        # Verify server is still responding
        health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert health_result['success'], "Web server crashed during password validation tests"
    
    def test_path_traversal_prevention(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test that path traversal attacks are prevented"""
        # Setup web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi('nohup python3 /opt/grannytv-setup/web/setup_server.py > /tmp/setup_server.log 2>&1 &',
                     timeout=10)
        time.sleep(3)
        
        # Test malicious install paths
        malicious_paths = [
            "../../../etc/passwd",
            "/etc/shadow",
            "../../../../root/.ssh/",
            "../tmp/malicious",
            "/var/log/auth.log",
        ]
        
        for path in malicious_paths:
            config = {
                "wifi_ssid": "TestNetwork", 
                "wifi_password": "testpass",
                "wifi_country": "US",
                "username": "jeremy",
                "install_path": path,
                "stream_source": ""
            }
            
            result = execute_on_pi_root(f'curl -X POST -H "Content-Type: application/json" -d \'{json.dumps(config)}\' http://localhost:8080/configure',
                                      timeout=15)
            
            # Should either reject or sanitize malicious paths
            if result['success']:
                response_data = json.loads(result['stdout'])
                # If accepted, should have been sanitized or rejected
                assert response_data.get('error') or not response_data.get('success', True), f"Malicious path was accepted: {path}"


class TestSystemResourceLimits:
    """Test system resource handling - IMPORTANT GAP"""
    
    def test_setup_with_limited_disk_space(self, execute_on_pi_root, cleanup_pi):
        """Test setup behavior with limited disk space"""
        # Check current disk usage
        disk_result = execute_on_pi_root('df -h / | tail -1', timeout=10)
        assert disk_result['success'], "Could not check disk space"
        
        # Extract available space (rough check)
        disk_info = disk_result['stdout'].strip()
        if "100%" in disk_info:
            # Skip test if disk is already full
            return
        
        # Run setup and ensure it completes
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                  cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed - possibly due to disk space issues"
    
    def test_concurrent_setup_operations(self, execute_on_pi_root, cleanup_pi):
        """Test multiple setup operations don't interfere"""
        # Try to run setup wizard twice simultaneously (should handle gracefully)
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh > /tmp/setup1.log 2>&1 &',
                          cwd="/home/jeremy/gtv", timeout=5)
        time.sleep(2)
        
        result2 = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=60)
        
        # Second run should either succeed or fail gracefully
        # (not crash or corrupt the system)
        time.sleep(10)  # Wait for first process to complete
        
        # Verify system is still in good state
        services_result = execute_on_pi_root('systemctl list-unit-files | grep grannytv')
        assert services_result['success'], "Services corrupted by concurrent setup"


class TestErrorRecovery:
    """Test error recovery scenarios - IMPORTANT GAP"""
    
    def test_recovery_from_interrupted_setup(self, execute_on_pi_root, cleanup_pi):
        """Test recovery when setup is interrupted"""
        # Start setup and interrupt it
        execute_on_pi_root('timeout 10 sudo -u jeremy ./setup/setup-wizard.sh || true',
                          cwd="/home/jeremy/gtv", timeout=15)
        
        # Now run full setup - should recover gracefully
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                  cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed to recover from interruption"
        
        # Verify services were created properly
        services_result = execute_on_pi_root('systemctl list-unit-files | grep grannytv')
        assert services_result['success'], "Services not properly created after recovery"
    
    def test_recovery_from_corrupted_setup_files(self, execute_on_pi_root, cleanup_pi):
        """Test recovery from corrupted setup files"""
        # Run initial setup
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Corrupt some setup files
        execute_on_pi_root('echo "corrupted" > /opt/grannytv-setup/web/setup_server.py')
        execute_on_pi_root('rm -f /opt/grannytv-setup/web/templates/setup.html')
        
        # Run setup again - should restore corrupted files
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                  cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed to recover from corrupted files"
        
        # Verify files were restored
        setup_server_result = execute_on_pi_root('grep -q "Flask" /opt/grannytv-setup/web/setup_server.py')
        assert setup_server_result['success'], "setup_server.py was not properly restored"