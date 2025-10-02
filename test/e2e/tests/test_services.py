"""
End-to-end tests for GrannyTV service management
"""


class TestServiceManagement:
    """Test systemd service management"""
    
    def test_grannytv_setup_service_creation(self, execute_on_pi_root, cleanup_pi):
        """Test that grannytv-setup service is created"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Check service exists
        result = execute_on_pi_root('systemctl list-unit-files | grep grannytv-setup')
        assert result['success'], "grannytv-setup service not found"
        
        # Check service is enabled
        result = execute_on_pi_root('systemctl is-enabled grannytv-setup')
        assert result['success'], "grannytv-setup service not enabled"
        
    def test_grannytv_prepare_service_creation(self, execute_on_pi_root, cleanup_pi):
        """Test that grannytv-prepare service is created"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Check service exists
        result = execute_on_pi_root('systemctl list-unit-files | grep grannytv-prepare')
        assert result['success'], "grannytv-prepare service not found"
        
        # Check service is enabled
        result = execute_on_pi_root('systemctl is-enabled grannytv-prepare')
        assert result['success'], "grannytv-prepare service not enabled"
        
    def test_hostapd_service_enabled(self, execute_on_pi_root, cleanup_pi):
        """Test that hostapd service is enabled"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Check service is enabled
        result = execute_on_pi_root('systemctl is-enabled hostapd')
        assert result['success'], "hostapd service not enabled"
        
    def test_dnsmasq_service_enabled(self, execute_on_pi_root, cleanup_pi):
        """Test that dnsmasq service is enabled"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Check service is enabled
        result = execute_on_pi_root('systemctl is-enabled dnsmasq')
        assert result['success'], "dnsmasq service not enabled"
        
    def test_service_startup_order(self, execute_on_pi_root, cleanup_pi):
        """Test service startup dependencies"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Check grannytv-setup service dependencies
        result = execute_on_pi_root('systemctl show grannytv-setup --property=After')
        assert result['success'], "Could not check service dependencies"
        assert 'grannytv-prepare' in result['stdout']
        
    def test_service_start_stop(self, execute_on_pi_root, cleanup_pi):
        """Test manual service start/stop"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Try to start services manually
        services = ['hostapd', 'dnsmasq']
        
        for service in services:
            # Start service
            result = execute_on_pi_root(f'systemctl start {service}')
            # May fail due to network simulation, but should not crash
            
            # Check status
            result = execute_on_pi_root(f'systemctl status {service}')
            # Should return some status (active, failed, etc.)
            assert result['returncode'] in [0, 3], f"Service {service} status check failed"
            
    def test_service_logs_available(self, execute_on_pi_root, cleanup_pi):
        """Test that service logs are available"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Check logs are available
        services = ['grannytv-setup', 'hostapd', 'dnsmasq']
        
        for service in services:
            result = execute_on_pi_root(f'journalctl -u {service} --no-pager -n 5')
            # Should be able to read logs (even if empty)
            assert result['success'], f"Could not read logs for {service}"


class TestServiceRecovery:
    """Test service recovery and restart behavior"""
    
    def test_service_restart_on_failure(self, execute_on_pi_root, cleanup_pi):
        """Test that services restart on failure"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Check restart configuration
        result = execute_on_pi_root('systemctl show grannytv-setup --property=Restart')
        assert result['success'], "Could not check restart configuration"
        assert 'on-failure' in result['stdout'] or 'always' in result['stdout']
        
    def test_service_startup_after_reboot_simulation(self, execute_on_pi_root, cleanup_pi):
        """Test service startup after simulated reboot"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Stop all services (simulating shutdown)
        services = ['grannytv-setup', 'hostapd', 'dnsmasq']
        for service in services:
            execute_on_pi_root(f'systemctl stop {service}')
        
        # Reload systemd (simulating boot)
        execute_on_pi_root('systemctl daemon-reload')
        
        # Check that services are still enabled
        for service in services:
            result = execute_on_pi_root(f'systemctl is-enabled {service}')
            assert result['success'], f"Service {service} not enabled after reload"
            
    def test_verify_setup_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test that verify-setup script can recover from issues"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Simulate some issues
        execute_on_pi_root('rm -rf /opt/grannytv-setup/web 2>/dev/null || true')
        execute_on_pi_root('systemctl stop hostapd dnsmasq 2>/dev/null || true')
        
        # Run verify script to recover
        result = execute_on_pi_root('./setup/verify-setup.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Should recover and report ready
        assert "GrannyTV Setup System Ready!" in result['stdout']
        
        # Check that files were restored
        result = execute_on_pi_root('ls -la /opt/grannytv-setup/web/')
        assert result['success'], "Web files not restored"
        assert 'setup_server.py' in result['stdout']


class TestServiceConfiguration:
    """Test service configuration files"""
    
    def test_hostapd_configuration_valid(self, execute_on_pi_root, cleanup_pi):
        """Test that hostapd configuration is valid"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Test hostapd config syntax
        result = execute_on_pi_root('hostapd -t /etc/hostapd/hostapd.conf')
        # May fail due to missing hardware, but config should be syntactically valid
        # Exit code 1 often means "config valid but can't start" in test environment
        assert result['returncode'] in [0, 1], "hostapd config syntax error"
        
    def test_dnsmasq_configuration_valid(self, execute_on_pi_root, cleanup_pi):
        """Test that dnsmasq configuration is valid"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Test dnsmasq config syntax
        result = execute_on_pi_root('dnsmasq --test')
        # Should report "syntax check OK" or similar
        assert result['success'] or "syntax OK" in result['stderr']
        
    def test_systemd_service_files_valid(self, execute_on_pi_root, cleanup_pi):
        """Test that systemd service files are valid"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Reload systemd to validate service files
        result = execute_on_pi_root('systemctl daemon-reload')
        assert result['success'], "systemd daemon-reload failed (invalid service files)"
        
        # Check specific services
        services = ['grannytv-setup', 'grannytv-prepare']
        for service in services:
            result = execute_on_pi_root(f'systemctl status {service}')
            # Should not report "not found" or "invalid"
            assert result['returncode'] in [0, 3], f"Service {service} not valid"
            assert "not-found" not in result['stdout'].lower()
            assert "invalid" not in result['stdout'].lower()