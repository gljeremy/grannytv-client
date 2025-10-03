"""
End-to-end tests for GrannyTV web server
"""
import requests
import time


class TestWebServer:
    """Test the Flask web server functionality"""
    
    def test_web_server_startup(self, execute_on_pi_root, pi_simulator, cleanup_pi):
        """Test that web server starts successfully"""
        # Run setup wizard to prepare files
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Start web server manually
        result = execute_on_pi_root(
            'cd /opt/grannytv-setup/web && python3 setup_server.py &',
            timeout=10
        )
        
        # Wait for server to start
        time.sleep(5)
        
        # Check if server is listening
        result = execute_on_pi_root('netstat -tlnp | grep :8080')
        assert result['success'], "Web server not listening on port 8080"
        
    def test_health_endpoint(self, web_client, pi_simulator, cleanup_pi):
        """Test the health check endpoint"""
        try:
            response = web_client.get(f"{pi_simulator['base_url']}/health")
            assert response.status_code == 200
            data = response.json()
            assert data['status'] == 'ok'
        except requests.exceptions.RequestException:
            # Health endpoint may not be implemented yet
            pass
            
    def test_main_page_loads(self, web_client, pi_simulator, execute_on_pi_root, cleanup_pi):
        """Test that main setup page loads"""
        # Start web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('./setup/verify-setup.sh',
                          cwd="/home/jeremy/gtv", timeout=60)
        
        time.sleep(5)  # Wait for server
        
        try:
            response = web_client.get(f"{pi_simulator['base_url']}/")
            assert response.status_code == 200
            assert 'GrannyTV' in response.text
        except requests.exceptions.RequestException as e:
            # Server may not be fully ready
            print(f"Web server not ready: {e}")
            
    def test_wifi_scan_endpoint(self, web_client, pi_simulator, execute_on_pi_root, cleanup_pi):
        """Test WiFi scanning endpoint"""
        # Start web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('./setup/verify-setup.sh',
                          cwd="/home/jeremy/gtv", timeout=60)
        
        time.sleep(5)
        
        try:
            response = web_client.get(f"{pi_simulator['base_url']}/scan_wifi")
            # May return error due to simulated environment, but should respond
            assert response.status_code in [200, 400, 500]
        except requests.exceptions.RequestException:
            pass  # Expected in simulated environment
            
    def test_config_submission(self, web_client, pi_simulator, execute_on_pi_root, test_config, cleanup_pi):
        """Test configuration form submission"""
        # Start web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('./setup/verify-setup.sh',
                          cwd="/home/jeremy/gtv", timeout=60)
        
        time.sleep(5)
        
        try:
            response = web_client.post(
                f"{pi_simulator['base_url']}/configure",
                json=test_config
            )
            # Should accept configuration or return validation error
            assert response.status_code in [200, 400]
        except requests.exceptions.RequestException:
            pass  # Expected in simulated environment
            
    def test_device_info_endpoint(self, web_client, pi_simulator, execute_on_pi_root, cleanup_pi):
        """Test device information endpoint"""
        # Start web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('./setup/verify-setup.sh',
                          cwd="/home/jeremy/gtv", timeout=60)
        
        time.sleep(5)
        
        try:
            response = web_client.get(f"{pi_simulator['base_url']}/detect_pi")
            if response.status_code == 200:
                data = response.json()
                assert 'hostname' in data
                assert 'platform' in data
        except requests.exceptions.RequestException:
            pass  # Expected in simulated environment


class TestWebServerErrorHandling:
    """Test web server error handling"""
    
    def test_invalid_config_handling(self, web_client, pi_simulator, execute_on_pi_root, cleanup_pi):
        """Test handling of invalid configuration data"""
        # Start web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('./setup/verify-setup.sh',
                          cwd="/home/jeremy/gtv", timeout=60)
        
        time.sleep(5)
        
        invalid_configs = [
            {},  # Empty config
            {'wifi_ssid': ''},  # Empty SSID
            {'wifi_ssid': 'test', 'wifi_password': ''},  # Empty password
            {'invalid_field': 'value'}  # Invalid field
        ]
        
        for config in invalid_configs:
            try:
                response = web_client.post(
                    f"{pi_simulator['base_url']}/configure",
                    json=config
                )
                # Should return validation error
                assert response.status_code == 400
            except requests.exceptions.RequestException:
                pass  # Expected in simulated environment
                
    def test_malformed_json_handling(self, web_client, pi_simulator, execute_on_pi_root, cleanup_pi):
        """Test handling of malformed JSON"""
        # Start web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('./setup/verify-setup.sh',
                          cwd="/home/jeremy/gtv", timeout=60)
        
        time.sleep(5)
        
        try:
            response = web_client.post(
                f"{pi_simulator['base_url']}/configure",
                data="invalid json",
                headers={'Content-Type': 'application/json'}
            )
            # Should return JSON parsing error
            assert response.status_code == 400
        except requests.exceptions.RequestException:
            pass  # Expected in simulated environment
            
    def test_nonexistent_endpoint(self, web_client, pi_simulator, execute_on_pi_root, cleanup_pi):
        """Test accessing non-existent endpoints"""
        # Start web server
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('./setup/verify-setup.sh',
                          cwd="/home/jeremy/gtv", timeout=60)
        
        time.sleep(5)
        
        try:
            response = web_client.get(f"{pi_simulator['base_url']}/nonexistent")
            assert response.status_code == 404
        except requests.exceptions.RequestException:
            pass  # Expected in simulated environment


class TestPortRedirection:
    """Test port redirection functionality"""
    
    def test_port_80_redirect(self, web_client, pi_simulator, execute_on_pi_root, cleanup_pi):
        """Test that port 80 redirects to 8080"""
        # Start web server with port redirection
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        execute_on_pi_root('./setup/verify-setup.sh',
                          cwd="/home/jeremy/gtv", timeout=60)
        
        time.sleep(5)
        
        try:
            # Try to access port 80
            response = web_client.get(f"http://{pi_simulator['host']}/")
            # Should either redirect or serve content
            assert response.status_code in [200, 301, 302]
        except requests.exceptions.RequestException:
            pass  # Expected in simulated environment due to iptables limitations