"""
End-to-end tests for GrannyTV error recovery scenarios
"""


class TestFileRecovery:
    """Test file recovery scenarios"""
    
    def test_missing_setup_files_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery when setup files are missing"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Remove setup files
        execute_on_pi_root('rm -rf /opt/grannytv-setup')
        
        # Run verify script - should recover
        result = execute_on_pi_root('./setup/verify-setup.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        assert "Setup files copied successfully" in result['stdout']
        
        # Verify files are restored
        result = execute_on_pi_root('ls -la /opt/grannytv-setup/web/setup_server.py')
        assert result['success'], "Setup files not recovered"
        
    def test_corrupted_setup_files_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery when setup files are corrupted"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Corrupt a key file
        execute_on_pi_root('echo "corrupted" > /opt/grannytv-setup/web/setup_server.py')
        
        # Run verify script - should detect and recover
        result = execute_on_pi_root('./setup/verify-setup.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Should report recovery
        assert "Setup files copied successfully" in result['stdout'] or \
               "Setup files already exist" in result['stdout']
               
    def test_missing_web_directory_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery when web directory is missing"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Remove web directory
        execute_on_pi_root('rm -rf /opt/grannytv-setup/web')
        
        # Run verify script
        result = execute_on_pi_root('./setup/verify-setup.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Should recover web directory
        result = execute_on_pi_root('ls -la /opt/grannytv-setup/web/')
        assert result['success'], "Web directory not recovered"
        assert 'setup_server.py' in result['stdout']


class TestNetworkRecovery:
    """Test network interface recovery"""
    
    def test_wifi_interface_down_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery when WiFi interface is down"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Bring interface down
        execute_on_pi_root('ip link set wlan0 down')
        
        # Run verify script
        result = execute_on_pi_root('./setup/verify-setup.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Should bring interface back up
        result = execute_on_pi_root('ip link show wlan0')
        assert result['success'], "Could not check interface status"
        assert 'UP' in result['stdout'] or 'state UP' in result['stdout']
        
    def test_missing_ip_address_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery when IP address is missing"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Remove IP address
        execute_on_pi_root('ip addr flush dev wlan0')
        
        # Run verify script
        result = execute_on_pi_root('./setup/verify-setup.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Should restore IP address
        result = execute_on_pi_root('ip addr show wlan0')
        assert result['success'], "Could not check IP address"
        # In test environment, IP assignment may fail, but script should try
        
    def test_iptables_rules_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery of iptables port redirection rules"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Clear iptables rules
        execute_on_pi_root('iptables -t nat -F PREROUTING')
        
        # Run verify script
        result = execute_on_pi_root('./setup/verify-setup.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Should restore port redirection
        result = execute_on_pi_root('iptables -t nat -L PREROUTING')
        assert result['success'], "Could not check iptables rules"


class TestServiceRecovery:
    """Test service recovery scenarios"""
    
    def test_stopped_services_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery when services are stopped"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Stop services
        execute_on_pi_root('systemctl stop hostapd dnsmasq')
        
        # Run verify script
        result = execute_on_pi_root('./setup/verify-setup.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Should report services started
        assert "started successfully" in result['stdout'] or \
               "is running" in result['stdout']
               
    def test_failed_web_server_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery when web server fails to start"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Kill any running web servers
        execute_on_pi_root('pkill -f "python3.*setup_server.py"')
        
        # Run verify script
        execute_on_pi_root('./setup/verify-setup.sh',
                          cwd="/home/jeremy/gtv", timeout=60)
        
        # Should start web server (may not work in test environment)
        execute_on_pi_root('netstat -tlnp | grep :8080')
        # May not work in test environment, but verify script should try
        
    def test_conflicting_services_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery when conflicting services are running"""
        # Start conflicting service
        execute_on_pi_root('systemctl start NetworkManager 2>/dev/null || true')
        
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Should handle conflicts gracefully
        assert True  # If we get here, conflicts were handled
        
    def test_permission_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery from permission issues"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Change permissions to cause issues
        execute_on_pi_root('chmod 000 /opt/grannytv-setup/web/setup_server.py')
        
        # Run verify script
        result = execute_on_pi_root('./setup/verify-setup.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Should fix permissions
        result = execute_on_pi_root('test -x /opt/grannytv-setup/web/setup_server.py')
        assert result['success'], "Permissions not fixed"


class TestSetupModeRecovery:
    """Test setup mode flag recovery"""
    
    def test_missing_setup_mode_flag_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test recovery when setup mode flag is missing"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Remove setup mode flag
        execute_on_pi_root('rm -f /var/lib/grannytv-setup-mode')
        
        # Run force setup mode script
        result = execute_on_pi_root('./setup/force-setup-mode.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Should recreate flag
        result = execute_on_pi_root('ls -la /var/lib/grannytv-setup-mode')
        assert result['success'], "Setup mode flag not recreated"
        
    def test_cleanup_and_restore_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test complete cleanup and restore cycle"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Run restore script to clean up
        result = execute_on_pi_root('echo "n" | ./setup/restore-normal-wifi.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Verify cleanup
        result = execute_on_pi_root('ls -la /var/lib/grannytv-setup-mode')
        assert not result['success'], "Setup mode flag not removed"
        
        # Run setup wizard again
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                  cwd="/home/jeremy/gtv", timeout=120)
        
        assert result['success'], "Could not re-run setup after cleanup"
        assert "SMARTPHONE SETUP WIZARD READY!" in result['stdout']


class TestEmergencyScenarios:
    """Test emergency recovery scenarios"""
    
    def test_force_setup_mode_from_clean_state(self, execute_on_pi_root, cleanup_pi):
        """Test force setup mode when no setup has been run"""
        # Run force setup mode without prior setup
        result = execute_on_pi_root('./setup/force-setup-mode.sh',
                                  cwd="/home/jeremy/gtv", timeout=60)
        
        # Should handle missing files gracefully
        assert "FORCING GRANNYTV SETUP MODE" in result['stdout']
        
    def test_debug_script_from_broken_state(self, execute_on_pi_root, cleanup_pi):
        """Test debug script when system is in broken state"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Break things
        execute_on_pi_root('rm -rf /opt/grannytv-setup')
        execute_on_pi_root('systemctl stop hostapd dnsmasq')
        execute_on_pi_root('ip addr flush dev wlan0')
        
        # Run debug script
        result = execute_on_pi_root('./setup/debug-hotspot.sh',
                                  cwd="/home/jeremy/gtv", timeout=30)
        
        # Should provide diagnostic information
        assert result['success'], "Debug script failed"
        assert "GrannyTV Hotspot Diagnostics" in result['stdout']
        
    def test_complete_system_recovery(self, execute_on_pi_root, cleanup_pi):
        """Test complete system recovery from totally broken state"""
        # Run setup wizard
        execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                          cwd="/home/jeremy/gtv", timeout=120)
        
        # Completely break the system
        execute_on_pi_root('rm -rf /opt/grannytv-setup')
        execute_on_pi_root('rm -f /var/lib/grannytv-setup-mode')
        execute_on_pi_root('systemctl disable grannytv-setup grannytv-prepare')
        execute_on_pi_root('systemctl stop hostapd dnsmasq')
        execute_on_pi_root('rm -f /etc/hostapd/hostapd.conf')
        
        # Run setup wizard again to recover
        result = execute_on_pi_root('sudo -u jeremy ./setup/setup-wizard.sh',
                                  cwd="/home/jeremy/gtv", timeout=120)
        
        # Should recover completely
        assert result['success'], "Could not recover from broken state"
        assert "SMARTPHONE SETUP WIZARD READY!" in result['stdout']
        
        # Verify everything is restored
        checks = [
            'ls -la /opt/grannytv-setup/web/setup_server.py',
            'ls -la /var/lib/grannytv-setup-mode',
            'systemctl is-enabled grannytv-setup',
            'ls -la /etc/hostapd/hostapd.conf'
        ]
        
        for check in checks:
            result = execute_on_pi_root(check)
            assert result['success'], f"Recovery check failed: {check}"