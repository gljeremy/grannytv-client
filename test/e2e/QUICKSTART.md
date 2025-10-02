# GrannyTV E2E Testing Quick Start

## Prerequisites

- Docker and Docker Compose installed
- 4GB+ available RAM
- 10GB+ available disk space

## Quick Run

```bash
# Navigate to test directory
cd test/e2e

# Make run script executable (Linux/Mac)
chmod +x run-tests.sh

# Run all tests
./run-tests.sh

# Run specific category
./run-tests.sh --category setup

# Debug mode with container inspection
./run-tests.sh --debug --keep-containers
```

## Windows Users

```powershell
# Navigate to test directory
cd test\e2e

# Run all tests
bash run-tests.sh

# Or use Docker Compose directly
docker-compose up --build -d pi-simulator
docker-compose run --rm test-runner pytest tests/ -v
```

## Test Categories

- **setup**: Setup wizard execution and file management
- **web**: Flask web server and API endpoints  
- **services**: systemd service management
- **recovery**: Error recovery and fault tolerance

## Expected Results

✅ **Passing tests** indicate the system works correctly
❌ **Failing tests** may indicate:
- Docker environment limitations (network simulation)
- Missing dependencies in containers
- Timing issues in test environment

## Debugging

```bash
# Interactive Pi simulator shell
docker-compose run --rm --entrypoint bash pi-simulator

# View real-time logs
docker-compose logs -f pi-simulator

# Access running container
docker-compose exec pi-simulator bash

# Clean up everything
docker-compose down --volumes --remove-orphans
docker system prune -f
```

## CI/CD Integration

The tests run automatically on:
- Pull requests to main/develop
- Pushes to main/develop  
- Daily at 2 AM UTC
- Manual workflow dispatch

Results are available in GitHub Actions artifacts.