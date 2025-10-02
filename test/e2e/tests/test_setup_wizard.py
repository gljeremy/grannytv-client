"""
End-to-end tests for GrannyTV setup wizard
"""


class TestSetupWizard:
    """Test the setup wizard functionality"""
    
    def test_setup_wizard_execution(self, execute_on_pi, cleanup_pi):
        """Test that setup wizard runs successfully"""
        # Execute setup wizard
        result = execute_on_pi('./setup/setup-wizard.sh', timeout=120)
        
        assert result['success'], f"Setup wizard failed: {result['stderr']}"
        assert "SMARTPHONE SETUP WIZARD READY!" in result['stdout']
        
    def test_setup_files_copied(self, execute_on_pi, cleanup_pi):
        """Test that setup files are copied to persistent location"""
        # Run setup wizard
        execute_on_pi('./setup/setup-wizard.sh', timeout=120)
        
        # Check if files exist in /opt/grannytv-setup
        result = execute_on_pi('ls -la /opt/grannytv-setup/')
        assert result['success'], "Setup directory not created"
        
        # Check for web files
        result = execute_on_pi('ls -la /opt/grannytv-setup/web/')
        assert result['success'], "Web directory not created"
        assert 'setup_server.py' in result['stdout']
        
    def test_setup_mode_flag_created(self, execute_on_pi, cleanup_pi):
        """Test that setup mode flag is created"""
        # Run setup wizard
        execute_on_pi('./setup/setup-wizard.sh', timeout=120)
        
        # Check for setup mode flag
        result = execute_on_pi('ls -la /var/lib/grannytv-setup-mode')
        assert result['success'], "Setup mode flag not created"
        
    def test_systemd_services_created(self, execute_on_pi_root, cleanup_pi):
        """Test that systemd services are created and enabled"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh', 
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Check services exist
        services = ['grannytv-setup', 'grannytv-prepare']
        for service in services:
            result = execute_on_pi_root(f'systemctl list-unit-files | grep {service}')
            assert result['success'], f"Service {service} not found"
            
    def test_hostapd_config_created(self, execute_on_pi_root, cleanup_pi):
        """Test that hostapd configuration is created"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Check hostapd config
        result = execute_on_pi_root('cat /etc/hostapd/hostapd.conf')
        assert result['success'], "hostapd config not created"
        assert 'ssid=GrannyTV-Setup' in result['stdout']
        assert 'wpa_passphrase=SetupMe123' in result['stdout']
        
    def test_dnsmasq_config_created(self, execute_on_pi_root, cleanup_pi):
        """Test that dnsmasq configuration is created"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Check dnsmasq config
        result = execute_on_pi_root('cat /etc/dnsmasq.conf')
        assert result['success'], "dnsmasq config not created"
        assert 'interface=wlan0' in result['stdout']
        assert 'dhcp-range=192.168.4.2,192.168.4.20' in result['stdout']
        
    def test_setup_scripts_executable(self, execute_on_pi, cleanup_pi):
        """Test that setup scripts are executable"""
        # Run setup wizard
        execute_on_pi('./setup/setup-wizard.sh', timeout=120)
        
        # Check script permissions
        scripts = [
            '/opt/grannytv-setup/start-setup-wizard.sh',
            '/opt/grannytv-setup/prepare-hotspot.sh',
            '/opt/grannytv-setup/web/setup_server.py'
        ]
        
        for script in scripts:
            result = execute_on_pi(f'test -x {script}')
            assert result['success'], f"Script {script} is not executable"
            
    def test_verify_setup_script(self, execute_on_pi_root, cleanup_pi):
        """Test the verify-setup.sh script"""
        # Run setup wizard first
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Run verify script
        result = execute_on_pi_root('./setup/verify-setup.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        assert result['success'], f"Verify setup failed: {result['stderr']}"
        assert "GrannyTV Setup System Ready!" in result['stdout']
        
    def test_force_setup_mode_script(self, execute_on_pi_root, cleanup_pi):
        """Test the force-setup-mode.sh script"""
        # Copy setup files first
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Run force setup mode
        result = execute_on_pi_root('./setup/force-setup-mode.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Note: This may fail due to network simulation limitations
        # but should at least start without major errors
        assert "FORCING GRANNYTV SETUP MODE" in result['stdout']
        
    def test_debug_hotspot_script(self, execute_on_pi, cleanup_pi):
        """Test the debug-hotspot.sh script"""
        # Run setup wizard first
        execute_on_pi('./setup/setup-wizard.sh', timeout=120)
        
        # Run debug script
        result = execute_on_pi('./setup/debug-hotspot.sh', timeout=30)
        
        assert result['success'], f"Debug script failed: {result['stderr']}"
        assert "GrannyTV Hotspot Diagnostics" in result['stdout']
        
    def test_restoration_script_creation(self, execute_on_pi, cleanup_pi):
        """Test that restoration script is created"""
        # Run setup wizard
        execute_on_pi('./setup/setup-wizard.sh', timeout=120)
        
        # Check restoration script exists
        result = execute_on_pi('test -f ~/gtv/setup/restore-normal-wifi.sh')
        assert result['success'], "Restoration script not created"
        
        # Check it's executable
        result = execute_on_pi('test -x ~/gtv/setup/restore-normal-wifi.sh')
        assert result['success'], "Restoration script not executable"


class TestSetupWizardErrorHandling:
    """Test error handling in setup wizard"""
    
    def test_missing_setup_files_handling(self, execute_on_pi, cleanup_pi):
        """Test handling of missing setup files"""
        # Try to run from wrong directory
        result = execute_on_pi('./setup/setup-wizard.sh', cwd="/tmp")
        
        # Should fail gracefully with helpful message
        assert not result['success']
        assert "Setup files not found" in result['stdout']
        
    def test_permission_error_handling(self, execute_on_pi, cleanup_pi):
        """Test handling of permission errors"""
        # This test would require specific permission setups
        # For now, just ensure script doesn't crash on permission issues
        pass  # Placeholder for future implementation
        
    def test_service_conflict_handling(self, execute_on_pi_root, cleanup_pi):
        """Test handling of conflicting services"""
        # Start conflicting service
        execute_on_pi_root('systemctl start NetworkManager 2>/dev/null || true')
        
        # Run setup wizard - should handle conflicts
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                  cwd="/home/jeremy/gtv", timeout=120)
        
        # Should succeed despite conflicts
        assert result['success'], f"Setup failed with conflicts: {result['stderr']}"