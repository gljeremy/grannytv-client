# GrannyTV End-to-End Testing

This directory contains Docker-based end-to-end tests for the GrannyTV smartphone setup system.

## Overview

The E2E tests simulate a Raspberry Pi environment using Docker containers to test:
- Setup wizard execution
- WiFi hotspot creation
- Web server startup
- Smartphone setup workflow
- Service management
- Error recovery scenarios

## Quick Start

### **Windows (WSL2 Recommended)**
```powershell
# Install WSL2 Ubuntu (one-time setup)
wsl --install -d Ubuntu-22.04

# Install dependencies in WSL2
wsl -d Ubuntu-22.04 -- sudo apt update
wsl -d Ubuntu-22.04 -- sudo apt install -y python3-pip python3-venv docker.io python3-pytest

# Run tests in WSL2
wsl -d Ubuntu-22.04 -- bash -c "cd /mnt/c/Users/$(whoami)/source/repos/grannytv-client/test/e2e && ./run-tests.sh"

# Or run specific tests
wsl -d Ubuntu-22.04 -- bash -c "cd /mnt/c/path/to/grannytv-client/test/e2e && python3 -m pytest tests/test_critical_gaps.py -v"
```

### **Linux/WSL2**
```bash
# Run all tests
cd test/e2e
./run-tests.sh

# Run specific test
docker-compose run --rm test-runner pytest tests/test_setup_wizard.py -v

# Interactive debugging
docker-compose run --rm --entrypoint bash pi-simulator
```

### **Native Windows (Limited Support)**
```powershell
# Note: Many tests will fail due to Linux-specific dependencies
cd test/e2e
python -m pytest tests/test_critical_gaps.py -v
```

## Test Structure

```
test/e2e/
├── docker/
│   ├── Dockerfile.pi-simulator    # Raspberry Pi OS simulation
│   ├── Dockerfile.test-runner     # Test execution environment
│   └── entrypoint.sh             # Container startup script
├── tests/
│   ├── test_setup_wizard.py      # Setup wizard tests
│   ├── test_web_server.py        # Web interface tests
│   ├── test_services.py          # Service management tests
│   └── test_recovery.py          # Error recovery tests
├── fixtures/
│   ├── test_streams.json         # Test IPTV streams
│   └── mock_wifi_networks.json   # Mock WiFi scan results
├── docker-compose.yml            # Container orchestration
├── run-tests.sh                  # Test runner script
└── README.md                     # This file
```

## Test Scenarios

### 1. Setup Wizard Tests
- File copying and permissions
- Service configuration
- WiFi interface setup
- Error handling

### 2. Web Server Tests
- Flask server startup
- API endpoints
- Form submission
- Configuration validation

### 3. Service Management Tests
- systemd service creation
- hostapd/dnsmasq configuration
- Service dependencies
- Auto-restart behavior

### 4. Recovery Tests
- Missing file recovery
- Service failure recovery
- Network interface reset
- Cleanup scenarios

## Test Environment

The Docker containers simulate:
- **Raspberry Pi OS** (Debian-based)
- **systemd** service management
- **Network interfaces** (simulated wlan0)
- **Package management** (apt)
- **File system** structure

## Running Tests

### All Tests
```bash
./run-tests.sh
```

### Specific Test Categories
```bash
./run-tests.sh --category setup
./run-tests.sh --category web
./run-tests.sh --category services
./run-tests.sh --category recovery
```

### Debug Mode
```bash
./run-tests.sh --debug
```

## Test Configuration

Environment variables in `.env`:
- `TEST_TIMEOUT=300` - Test timeout in seconds
- `DEBUG_MODE=false` - Enable debug logging
- `KEEP_CONTAINERS=false` - Keep containers after tests
- `PARALLEL_TESTS=true` - Run tests in parallel

## CI/CD Integration

GitHub Actions workflow included for automated testing on:
- Pull requests
- Main branch pushes
- Daily scheduled runs

## Troubleshooting

### Common Issues
1. **Container startup fails**: Check Docker daemon and permissions
2. **Network tests fail**: Ensure Docker network isolation
3. **Service tests fail**: Check systemd simulation setup
4. **File permission issues**: Verify volume mounts

### Debug Commands
```bash
# Check container logs
docker-compose logs pi-simulator

# Interactive shell
docker-compose exec pi-simulator bash

# Network inspection
docker network ls
docker network inspect e2e_default
```

## Contributing

When adding new tests:
1. Follow the existing test structure
2. Add appropriate fixtures
3. Update this README
4. Ensure tests are deterministic
5. Add cleanup procedures