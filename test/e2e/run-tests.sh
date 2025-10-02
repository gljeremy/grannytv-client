#!/bin/bash
# GrannyTV End-to-End Test Runner

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_TIMEOUT=300
DEBUG_MODE=false
KEEP_CONTAINERS=false
PARALLEL_TESTS=true
CATEGORY=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --keep-containers)
            KEEP_CONTAINERS=true
            shift
            ;;
        --sequential)
            PARALLEL_TESTS=false
            shift
            ;;
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --timeout SECONDS    Test timeout (default: $DEFAULT_TIMEOUT)"
            echo "  --debug             Enable debug mode"
            echo "  --keep-containers   Keep containers after tests"
            echo "  --sequential        Run tests sequentially"
            echo "  --category CATEGORY Run specific test category"
            echo "                      (setup, web, services, recovery)"
            echo "  --help              Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                           # Run all tests"
            echo "  $0 --category setup          # Run only setup tests"
            echo "  $0 --debug --keep-containers # Debug mode, keep containers"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set defaults
TEST_TIMEOUT=${TEST_TIMEOUT:-$DEFAULT_TIMEOUT}

echo -e "${BLUE}🧪 GrannyTV End-to-End Test Runner${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Check dependencies
check_dependencies() {
    echo -e "${YELLOW}🔍 Checking dependencies...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker not found. Please install Docker.${NC}"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose not found. Please install Docker Compose.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Dependencies check passed${NC}"
}

# Clean up any existing containers
cleanup_containers() {
    echo -e "${YELLOW}🧹 Cleaning up existing containers...${NC}"
    
    docker-compose down --remove-orphans --volumes 2>/dev/null || true
    docker container prune -f 2>/dev/null || true
    
    if [ "$KEEP_CONTAINERS" = false ]; then
        docker volume prune -f 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Build containers
build_containers() {
    echo -e "${YELLOW}🏗️  Building test containers...${NC}"
    
    docker-compose build --parallel
    
    echo -e "${GREEN}✅ Containers built successfully${NC}"
}

# Start containers
start_containers() {
    echo -e "${YELLOW}🚀 Starting test environment...${NC}"
    
    # Start Pi simulator
    docker-compose up -d pi-simulator
    
    # Wait for Pi simulator to be ready
    echo -e "${YELLOW}⏳ Waiting for Pi simulator to be ready...${NC}"
    
    max_attempts=30
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose exec -T pi-simulator curl -f http://localhost:8080/health 2>/dev/null; then
            echo -e "${GREEN}✅ Pi simulator is ready${NC}"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            echo -e "${RED}❌ Pi simulator failed to start after $max_attempts attempts${NC}"
            docker-compose logs pi-simulator
            exit 1
        fi
        
        echo -e "${YELLOW}   Attempt $attempt/$max_attempts...${NC}"
        sleep 5
        ((attempt++))
    done
}

# Run tests
run_tests() {
    echo -e "${YELLOW}🧪 Running tests...${NC}"
    echo ""
    
    # Prepare test environment variables
    export TEST_TIMEOUT=$TEST_TIMEOUT
    export DEBUG_MODE=$DEBUG_MODE
    
    # Build pytest arguments
    PYTEST_ARGS="--tb=short -v"
    
    if [ "$DEBUG_MODE" = true ]; then
        PYTEST_ARGS="$PYTEST_ARGS -s --log-cli-level=DEBUG"
    fi
    
    if [ "$PARALLEL_TESTS" = true ]; then
        PYTEST_ARGS="$PYTEST_ARGS -n auto"
    fi
    
    # Add category filter if specified
    if [ ! -z "$CATEGORY" ]; then
        case $CATEGORY in
            setup)
                PYTEST_ARGS="$PYTEST_ARGS tests/test_setup_wizard.py"
                ;;
            web)
                PYTEST_ARGS="$PYTEST_ARGS tests/test_web_server.py"
                ;;
            services)
                PYTEST_ARGS="$PYTEST_ARGS tests/test_services.py"
                ;;
            recovery)
                PYTEST_ARGS="$PYTEST_ARGS tests/test_recovery.py"
                ;;
            *)
                echo -e "${RED}❌ Unknown test category: $CATEGORY${NC}"
                echo -e "${YELLOW}Available categories: setup, web, services, recovery${NC}"
                exit 1
                ;;
        esac
    else
        PYTEST_ARGS="$PYTEST_ARGS tests/"
    fi
    
    # Run tests
    if docker-compose run --rm test-runner pytest $PYTEST_ARGS; then
        echo ""
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        TEST_RESULT=0
    else
        echo ""
        echo -e "${RED}❌ Some tests failed!${NC}"
        TEST_RESULT=1
    fi
}

# Show logs if debug mode or tests failed
show_logs() {
    if [ "$DEBUG_MODE" = true ] || [ $TEST_RESULT -ne 0 ]; then
        echo ""
        echo -e "${YELLOW}📋 Container logs:${NC}"
        echo -e "${YELLOW}=================${NC}"
        docker-compose logs pi-simulator
    fi
}

# Generate test report
generate_report() {
    echo ""
    echo -e "${BLUE}📊 Test Summary${NC}"
    echo -e "${BLUE}===============${NC}"
    
    # Get container stats
    PI_STATUS=$(docker-compose ps -q pi-simulator | xargs docker inspect --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
    
    echo -e "Pi Simulator Status: ${PI_STATUS}"
    echo -e "Test Timeout: ${TEST_TIMEOUT}s"
    echo -e "Debug Mode: ${DEBUG_MODE}"
    echo -e "Keep Containers: ${KEEP_CONTAINERS}"
    echo -e "Parallel Tests: ${PARALLEL_TESTS}"
    
    if [ ! -z "$CATEGORY" ]; then
        echo -e "Test Category: ${CATEGORY}"
    fi
    
    if [ $TEST_RESULT -eq 0 ]; then
        echo -e "Result: ${GREEN}PASSED${NC}"
    else
        echo -e "Result: ${RED}FAILED${NC}"
    fi
}

# Cleanup function
cleanup() {
    if [ "$KEEP_CONTAINERS" = false ]; then
        echo ""
        echo -e "${YELLOW}🧹 Cleaning up containers...${NC}"
        cleanup_containers
    else
        echo ""
        echo -e "${YELLOW}🔒 Keeping containers as requested${NC}"
        echo -e "${BLUE}To access Pi simulator: docker-compose exec pi-simulator bash${NC}"
        echo -e "${BLUE}To view logs: docker-compose logs pi-simulator${NC}"
        echo -e "${BLUE}To stop: docker-compose down${NC}"
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    check_dependencies
    cleanup_containers
    build_containers
    start_containers
    run_tests
    show_logs
    generate_report
    
    exit $TEST_RESULT
}

# Run main function
main "$@"