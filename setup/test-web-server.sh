#!/bin/bash
# GrannyTV Test Helper - Reliable Web Server Startup
# This script is designed for test environments to reliably start the web server

echo "🧪 GrannyTV Test Web Server Startup"
echo "=================================="

# Configuration
WORK_DIR="/opt/grannytv-setup"
SETUP_IP="192.168.4.1"

# Function to check if web server is running
is_web_server_running() {
    local pid_file="/tmp/grannytv-web.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            rm -f "$pid_file"  # Clean up stale PID file
            return 1  # Not running
        fi
    fi
    return 1  # No PID file
}

# Function to stop existing web server
stop_web_server() {
    echo "🛑 Stopping existing web server processes..."
    
    # Kill by PID file first
    if [ -f "/tmp/grannytv-web.pid" ]; then
        local pid=$(cat "/tmp/grannytv-web.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo "   Stopping PID: $pid"
            kill "$pid" 2>/dev/null || true
            sleep 2
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                echo "   Force killing PID: $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "/tmp/grannytv-web.pid"
    fi
    
    # More aggressive process cleanup
    echo "🧹 Cleaning up all setup_server processes..."
    
    # Get all PIDs first
    local pids=$(pgrep -f "python3.*setup_server.py" 2>/dev/null || true)
    
    if [ ! -z "$pids" ]; then
        echo "   Found processes: $pids"
        
        # Try graceful kill first
        for pid in $pids; do
            echo "   Stopping PID: $pid"
            kill "$pid" 2>/dev/null || true
        done
        
        # Wait for graceful shutdown
        sleep 3
        
        # Force kill any remaining processes
        local remaining_pids=$(pgrep -f "python3.*setup_server.py" 2>/dev/null || true)
        if [ ! -z "$remaining_pids" ]; then
            echo "   Force killing remaining processes: $remaining_pids"
            for pid in $remaining_pids; do
                kill -9 "$pid" 2>/dev/null || true
            done
            sleep 2
        fi
    fi
    
    # Final verification
    local final_count=$(pgrep -f "python3.*setup_server.py" 2>/dev/null | wc -l)
    if [ "$final_count" -gt 0 ]; then
        echo "⚠️  Warning: $final_count web server processes still running after cleanup"
        # Last resort - kill by exact command
        pkill -9 -f "setup_server.py" 2>/dev/null || true
        sleep 1
    else
        echo "✅ Web server cleanup complete - no processes remaining"
    fi
}

# Function to start web server for tests
start_web_server_for_tests() {
    echo "🌐 Starting web server for test environment..."
    
    # Ensure working directory exists and has files
    if [ ! -d "$WORK_DIR/web" ]; then
        echo "📁 Creating working directory: $WORK_DIR"
        sudo mkdir -p "$WORK_DIR/web"
        
        # Copy setup files
        local source_dir="/home/jeremy/gtv/setup"
        if [ -d "$source_dir" ]; then
            echo "📋 Copying setup files from: $source_dir"
            sudo cp -r "$source_dir"/* "$WORK_DIR/"
            sudo chmod +x "$WORK_DIR/web/setup_server.py" 2>/dev/null || true
            sudo chmod +x "$WORK_DIR"/*.sh 2>/dev/null || true
        else
            echo "❌ Setup files not found at: $source_dir"
            return 1
        fi
    fi
    
    # Verify setup_server.py exists
    if [ ! -f "$WORK_DIR/web/setup_server.py" ]; then
        echo "❌ setup_server.py not found at: $WORK_DIR/web/"
        return 1
    fi
    
    # Create setup mode flag (required for web server to start)
    sudo touch /var/lib/grannytv-setup-mode
    
    # Start web server
    cd "$WORK_DIR/web"
    echo "🚀 Starting Flask web server..."
    
    # Ensure no conflicting processes before starting
    local existing_count=$(pgrep -f "python3.*setup_server.py" 2>/dev/null | wc -l)
    if [ "$existing_count" -gt 0 ]; then
        echo "⚠️  Warning: $existing_count existing processes found before start"
        return 1
    fi
    
    # Start server with better process isolation
    setsid nohup python3 setup_server.py > /tmp/setup_server.log 2>&1 &
    local web_pid=$!
    
    # Save PID
    echo "$web_pid" > /tmp/grannytv-web.pid
    echo "💾 Saved PID: $web_pid"
    
    # Wait and verify startup
    echo "⏳ Waiting for web server to start..."
    sleep 5
    
    if kill -0 "$web_pid" 2>/dev/null; then
        echo "✅ Web server process running (PID: $web_pid)"
        
        # Test connectivity
        for i in {1..15}; do
            if curl -s --connect-timeout 2 http://localhost:8080/ >/dev/null 2>&1; then
                echo "✅ Web server responding on port 8080"
                echo "📋 Setup mode ready for testing"
                return 0
            fi
            echo "⏳ Waiting for web server response... ($i/15)"
            sleep 2
        done
        
        echo "⚠️  Web server started but not responding on port 8080"
        echo "📋 Recent log entries:"
        tail -n 10 /tmp/setup_server.log 2>/dev/null || echo "   No log available"
        return 1
    else
        echo "❌ Web server process failed to start"
        echo "📋 Error log:"
        cat /tmp/setup_server.log 2>/dev/null || echo "   No log file found"
        return 1
    fi
}

# Function to get web server status
get_web_server_status() {
    echo "📊 Web Server Status"
    echo "==================="
    
    if is_web_server_running; then
        local pid=$(cat /tmp/grannytv-web.pid)
        echo "✅ Status: Running (PID: $pid)"
        
        # Check if responding
        if curl -s --connect-timeout 2 http://localhost:8080/ >/dev/null 2>&1; then
            echo "✅ Connectivity: Responding on port 8080"
        else
            echo "❌ Connectivity: Not responding on port 8080"
        fi
        
        # Process count
        local count=$(pgrep -f "python3.*setup_server.py" | wc -l)
        echo "📈 Process count: $count"
        if [ "$count" -gt 1 ]; then
            echo "⚠️  Warning: Multiple web server processes detected!"
        fi
    else
        echo "❌ Status: Not running"
    fi
    
    # Log file info
    if [ -f "/tmp/setup_server.log" ]; then
        local log_size=$(stat -f%z /tmp/setup_server.log 2>/dev/null || stat -c%s /tmp/setup_server.log 2>/dev/null || echo "unknown")
        echo "📋 Log file: /tmp/setup_server.log ($log_size bytes)"
    else
        echo "📋 Log file: Not found"
    fi
}

# Main execution
case "${1:-start}" in
    "start")
        stop_web_server
        start_web_server_for_tests
        ;;
    "stop")
        stop_web_server
        ;;
    "restart")
        stop_web_server
        start_web_server_for_tests
        ;;
    "status")
        get_web_server_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start web server for testing"
        echo "  stop    - Stop web server and clean up"
        echo "  restart - Stop and start web server"
        echo "  status  - Show web server status"
        exit 1
        ;;
esac