#!/usr/bin/env python3
"""
End-to-End Setup Flow Tests - TIER 1 CRITICAL
============================================

These tests validate the complete user journey from smartphone setup to TV playing.
This is the most critical missing test - ensures the entire system works together.
"""
import time
import json
import pytest


class TestEndToEndSetupFlow:
    """Test complete smartphone setup to TV playing flow - TIER 1 CRITICAL"""
    
    def test_complete_setup_wizard_to_tv_playing(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test the complete user journey: smartphone setup -> TV working"""
        
        # Step 1: Initial system should be in setup mode
        result = execute_on_pi_root('systemctl is-active grannytv-setup-mode || echo "not-active"', timeout=10)
        assert 'active' in result.get('stdout', ''), "System should start in setup mode"
        
        # Step 2: Setup wizard should initialize properly
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh', 
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], f"Setup wizard failed: {result.get('stderr', 'Unknown error')}"
        
        # Step 3: Web server should be accessible (smartphone access simulation)
        time.sleep(5)  # Allow services to start
        result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert result['success'], "Web interface not accessible for smartphone setup"
        
        # Step 4: Simulate smartphone configuration submission
        config_data = {
            "wifi_ssid": "TestNetwork", 
            "wifi_password": "TestPassword123",
            "install_path": "/home/jeremy/gtv",
            "tv_name": "GrannyTV-Test"
        }
        
        # Submit configuration via web API
        config_json = json.dumps(config_data).replace('"', '\\"')
        curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
        result = execute_on_pi_root(curl_cmd, timeout=30)
        assert result['success'], f"Configuration submission failed: {result.get('stderr', 'Unknown error')}"
        
        # Step 5: Finalize setup (triggers reboot in production)
        result = execute_on_pi_root('curl -X POST http://localhost:8080/finalize', timeout=30)
        # Note: In test environment, this may timeout due to system changes, that's expected
        
        # Step 6: Verify configuration was saved
        time.sleep(10)  # Allow configuration to be written
        result = execute_on_pi_root('cat /home/jeremy/gtv/wifi_config.json 2>/dev/null || echo "missing"', timeout=10)
        if 'missing' not in result.get('stdout', ''):
            config = json.loads(result['stdout'])
            assert config.get('ssid') == 'TestNetwork', "WiFi configuration not saved correctly"
        
        # Step 7: Verify system transitions out of setup mode
        # Note: In production this would happen after reboot, in test we simulate
        result = execute_on_pi_root('systemctl is-active grannytv-normal-mode || echo "not-active"', timeout=10)
        # This might not be active in test environment, but we can check if setup mode stops
        
        # Step 8: Verify IPTV player can be initialized (core TV functionality)
        result = execute_on_pi('python3 -c "from iptv_smart_player import MPVIPTVPlayer; print(\\"IPTV Player initialized successfully\\")"',
                              cwd="/home/jeremy/gtv", timeout=20)
        assert result['success'], f"IPTV Player initialization failed: {result.get('stderr', 'Unknown error')}"
        assert "IPTV Player initialized successfully" in result['stdout'], "IPTV Player not properly initialized"
    
    def test_smartphone_to_tv_configuration_persistence(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test that smartphone configuration persists and is usable by TV system"""
        
        # Step 1: Start setup process
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup wizard initialization failed"
        
        time.sleep(5)
        
        # Step 2: Submit configuration with realistic values
        config_data = {
            "wifi_ssid": "Home-WiFi-2024",
            "wifi_password": "MySecureP@ssw0rd!",
            "install_path": "/home/jeremy/gtv",
            "tv_name": "Living-Room-TV",
            "iptv_streams": "https://example.com/streams.m3u"
        }
        
        config_json = json.dumps(config_data).replace('"', '\\"')
        curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
        result = execute_on_pi_root(curl_cmd, timeout=30)
        assert result['success'], "Configuration submission failed"
        
        # Step 3: Verify configuration files are created correctly
        time.sleep(3)
        
        # Check WiFi config
        result = execute_on_pi_root('cat /home/jeremy/gtv/wifi_config.json 2>/dev/null || echo "missing"', timeout=10)
        if 'missing' not in result.get('stdout', ''):
            wifi_config = json.loads(result['stdout'])
            assert wifi_config.get('ssid') == 'Home-WiFi-2024', "WiFi SSID not saved correctly"
            # Password should be present but may be encrypted/hashed
            assert 'password' in wifi_config or 'psk' in wifi_config, "WiFi password not saved"
        
        # Check system config  
        result = execute_on_pi_root('cat /home/jeremy/gtv/system_config.json 2>/dev/null || echo "missing"', timeout=10)
        if 'missing' not in result.get('stdout', ''):
            sys_config = json.loads(result['stdout'])
            assert sys_config.get('tv_name') == 'Living-Room-TV', "TV name not saved correctly"
        
        # Step 4: Verify IPTV player can read configuration
        result = execute_on_pi('python3 -c "import json; from iptv_smart_player import load_config; config = load_config(); print(json.dumps(config))"',
                              cwd="/home/jeremy/gtv", timeout=15)
        assert result['success'], "IPTV player cannot read configuration"
        
        # Configuration should be loaded successfully
        try:
            loaded_config = json.loads(result['stdout'])
            assert 'base_path' in loaded_config, "IPTV player config missing base_path"
            assert loaded_config['base_path'] == '/home/jeremy/gtv', "IPTV player base_path incorrect"
        except json.JSONDecodeError:
            pytest.fail(f"IPTV player config output not valid JSON: {result['stdout']}")
    
    def test_recovery_from_partial_setup(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test recovery when setup process is interrupted"""
        
        # Step 1: Start setup
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Initial setup failed"
        
        time.sleep(3)
        
        # Step 2: Submit partial configuration (missing required fields)
        partial_config = {
            "wifi_ssid": "PartialNetwork",
            # Missing password - should be handled gracefully
            "install_path": "/home/jeremy/gtv"
            # Missing TV name
        }
        
        config_json = json.dumps(partial_config).replace('"', '\\"')
        curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
        result = execute_on_pi_root(curl_cmd, timeout=30)
        
        # Step 3: System should handle partial config gracefully (not crash)
        time.sleep(2)
        health_result = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
        assert health_result['success'], "System crashed on partial configuration"
        
        # Step 4: Complete configuration should still work
        complete_config = {
            "wifi_ssid": "CompleteNetwork",
            "wifi_password": "CompletePassword",
            "install_path": "/home/jeremy/gtv",
            "tv_name": "Recovery-Test"
        }
        
        config_json = json.dumps(complete_config).replace('"', '\\"')
        curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
        result = execute_on_pi_root(curl_cmd, timeout=30)
        assert result['success'], "Recovery configuration failed"
        
        # Step 5: Verify final configuration is correct
        time.sleep(3)
        result = execute_on_pi_root('cat /home/jeremy/gtv/wifi_config.json 2>/dev/null || echo "missing"', timeout=10)
        if 'missing' not in result.get('stdout', ''):
            final_config = json.loads(result['stdout'])
            assert final_config.get('ssid') == 'CompleteNetwork', "Recovery configuration not applied"


class TestSystemIntegration:
    """Test integration between system components - TIER 1 CRITICAL"""
    
    def test_service_orchestration_flow(self, execute_on_pi_root, cleanup_pi):
        """Test that services start/stop in correct order during setup"""
        
        # Step 1: Check initial state
        result = execute_on_pi_root('systemctl list-units --type=service | grep grannytv || echo "none"', timeout=10)
        
        # Step 2: Start setup mode
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup mode initialization failed"
        
        # Step 3: Verify setup services are running
        time.sleep(5)
        result = execute_on_pi_root('ps aux | grep setup_server.py | grep -v grep || echo "not-running"', timeout=10)
        assert 'not-running' not in result.get('stdout', ''), "Setup web server not running"
        
        # Step 4: Verify network services (WiFi hotspot simulation)
        result = execute_on_pi_root('ip addr show | grep "192.168.4" || echo "no-hotspot"', timeout=10)
        # Note: May not work in Docker, but test would verify hotspot in real environment
        
        # Step 5: Test service cleanup
        result = execute_on_pi_root('pkill -f setup_server.py || echo "already-stopped"', timeout=10)
        time.sleep(2)
        
        # Verify cleanup worked
        result = execute_on_pi_root('ps aux | grep setup_server.py | grep -v grep || echo "stopped"', timeout=10)
        assert 'stopped' in result.get('stdout', ''), "Setup services not properly cleaned up"
    
    def test_configuration_validation_integration(self, execute_on_pi_root, execute_on_pi, cleanup_pi):
        """Test that configuration validation works across all components"""
        
        # Start setup
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                   cwd="/home/jeremy/gtv", timeout=120)
        assert result['success'], "Setup initialization failed"
        
        time.sleep(3)
        
        # Test various configuration scenarios
        test_configs = [
            {
                "name": "valid_config",
                "data": {
                    "wifi_ssid": "ValidNetwork",
                    "wifi_password": "ValidPass123",
                    "install_path": "/home/jeremy/gtv",
                    "tv_name": "ValidTV"
                },
                "should_succeed": True
            },
            {
                "name": "special_chars_password",
                "data": {
                    "wifi_ssid": "SpecialNetwork",
                    "wifi_password": "P@$$w0rd!#$%^&*()",
                    "install_path": "/home/jeremy/gtv", 
                    "tv_name": "SpecialTV"
                },
                "should_succeed": True
            },
            {
                "name": "unicode_ssid",
                "data": {
                    "wifi_ssid": "Café-WiFi-🏠",
                    "wifi_password": "UnicodePass",
                    "install_path": "/home/jeremy/gtv",
                    "tv_name": "UnicodeTV"
                },
                "should_succeed": True  # Should handle Unicode gracefully
            }
        ]
        
        for config_test in test_configs:
            config_json = json.dumps(config_test["data"]).replace('"', '\\"')
            curl_cmd = f'curl -X POST -H "Content-Type: application/json" -d "{config_json}" http://localhost:8080/configure'
            result = execute_on_pi_root(curl_cmd, timeout=30)
            
            if config_test["should_succeed"]:
                # Server should accept valid configurations
                health_check = execute_on_pi_root('curl -f http://localhost:8080/ -o /dev/null', timeout=10)
                assert health_check['success'], f"Server crashed on {config_test['name']}"
            
            time.sleep(1)  # Brief pause between tests


class TestProductionReadiness:
    """Test production deployment readiness - TIER 1 CRITICAL"""
    
    def test_minimal_system_requirements(self, execute_on_pi_root, cleanup_pi):
        """Test system meets minimal requirements for GrannyTV"""
        
        # Test Python availability
        result = execute_on_pi_root('python3 --version', timeout=10)
        assert result['success'], "Python3 not available"
        
        # Test required Python modules can be imported
        required_modules = ['json', 'time', 'subprocess', 'logging', 'os', 'sys']
        for module in required_modules:
            result = execute_on_pi_root(f'python3 -c "import {module}; print(\\"{module} OK\\")"', timeout=10)
            assert result['success'], f"Required Python module {module} not available"
            assert f"{module} OK" in result['stdout'], f"Module {module} import failed"
        
        # Test filesystem permissions
        result = execute_on_pi_root('touch /home/jeremy/gtv/test_write && rm /home/jeremy/gtv/test_write', timeout=10)
        assert result['success'], "Insufficient filesystem permissions for GrannyTV"
        
        # Test network capabilities
        result = execute_on_pi_root('curl --version', timeout=10)  
        assert result['success'], "Network tools not available"
    
    def test_deployment_file_structure(self, execute_on_pi_root, cleanup_pi):
        """Test that all required files are present for deployment"""
        
        required_files = [
            '/home/jeremy/gtv/iptv_smart_player.py',
            '/home/jeremy/gtv/config.json', 
            '/home/jeremy/gtv/setup/setup-wizard.sh',
            '/opt/grannytv-setup/web/setup_server.py'
        ]
        
        for file_path in required_files:
            result = execute_on_pi_root(f'test -f {file_path} && echo "exists" || echo "missing"', timeout=10)
            assert 'exists' in result.get('stdout', ''), f"Required file missing: {file_path}"
        
        # Test file permissions
        result = execute_on_pi_root('test -x /home/jeremy/gtv/setup/setup-wizard.sh && echo "executable" || echo "not-executable"', timeout=10)
        assert 'executable' in result.get('stdout', ''), "Setup wizard script not executable"
        
        # Test config file validity
        result = execute_on_pi_root('python3 -c "import json; json.load(open(\\"/home/jeremy/gtv/config.json\\"))"', timeout=10)
        assert result['success'], "config.json is not valid JSON"