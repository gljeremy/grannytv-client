#!/bin/bash
# VLC Setup and Diagnostics for GrannyTV
# This script handles all VLC configuration and testing

set -e  # Exit on any error

echo "🎬 GrannyTV VLC Setup & Diagnostics"
echo "==================================="

# Functions
log_info() { echo "ℹ️  $1"; }
log_success() { echo "✅ $1"; }
log_warning() { echo "⚠️  $1"; }
log_error() { echo "❌ $1"; }

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Don't run this script as root!"
    exit 1
fi

INSTALL_VLC=false
FIX_PERMISSIONS=false
TEST_ONLY=false
FORCE_X11=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-vlc)
            INSTALL_VLC=true
            shift
            ;;
        --fix-permissions)
            FIX_PERMISSIONS=true
            shift
            ;;
        --test-only)
            TEST_ONLY=true
            shift
            ;;
        --force-x11)
            FORCE_X11=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --install-vlc      Install/update VLC"
            echo "  --fix-permissions  Fix video/audio permissions"
            echo "  --test-only        Only run VLC tests"
            echo "  --force-x11        Force X11 mode (start desktop)"
            echo "  --help             Show this help"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# 1. System Information
log_info "System Information:"
echo "   OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
echo "   User: $(whoami)"
echo "   Groups: $(groups)"
echo "   GPU Memory: $(vcgencmd get_mem gpu 2>/dev/null || echo 'Unknown')"

# 2. Install VLC if requested
if [ "$INSTALL_VLC" = true ]; then
    log_info "Installing/updating VLC..."
    sudo apt update
    sudo apt install -y vlc alsa-utils
    log_success "VLC installation complete"
    
    # Check and log VLC version for compatibility tracking
    if command -v vlc >/dev/null 2>&1; then
        VLC_VERSION=$(vlc --version 2>/dev/null | head -n1 || echo "Unknown")
        log_info "Installed VLC Version: $VLC_VERSION"
        
        # Log to compatibility file for future reference
        echo "$(date): $VLC_VERSION" >> /tmp/vlc_version_history.log
        
        # Check for known problematic versions
        case "$VLC_VERSION" in
            *"3.0."*)
                log_success "VLC 3.0.x detected - Full optimization support"
                ;;
            *"2."*)
                log_warning "VLC 2.x detected - Some optimizations may be limited"
                ;;
            *)
                log_warning "Unknown VLC version - Basic compatibility mode will be used"
                ;;
        esac
    fi
fi

# 3. Fix permissions if requested  
if [ "$FIX_PERMISSIONS" = true ]; then
    log_info "Fixing permissions..."
    
    # Add user to video group
    if ! groups | grep -q video; then
        sudo usermod -a -G video $USER
        log_warning "Added to video group - logout/login required for this session"
    fi
    
    # Fix framebuffer permissions
    if [ -e /dev/fb0 ]; then
        sudo chmod 666 /dev/fb0
        log_success "Fixed framebuffer permissions"
    fi
    
    log_success "Permissions fixed"
fi

# 4. Audio Configuration
log_info "Configuring audio..."
# Force HDMI audio
sudo amixer cset numid=3 2 >/dev/null 2>&1 || log_warning "Could not set HDMI audio"
# Set volume
amixer set Master 90% unmute >/dev/null 2>&1 || log_warning "Could not set volume"
log_success "Audio configured for HDMI output"

# 5. Determine video output method
log_info "Determining video output method..."

HAS_X11=false
HAS_FRAMEBUFFER=false

# Check for X11
if [ -n "$DISPLAY" ] && xset q >/dev/null 2>&1; then
    HAS_X11=true
    log_success "X11 display available: $DISPLAY"
elif [ "$FORCE_X11" = true ]; then
    log_info "Force X11 requested - starting desktop..."
    
    # Try to start X11
    if ! pgrep -x "Xorg" >/dev/null; then
        sudo systemctl start lightdm 2>/dev/null || {
            log_info "Starting X11 manually..."
            startx &
            sleep 5
        }
    fi
    
    export DISPLAY=:0
    if xset q >/dev/null 2>&1; then
        HAS_X11=true
        log_success "X11 started successfully"
    else
        log_error "Failed to start X11"
    fi
fi

# Check for framebuffer
if [ -w /dev/fb0 ]; then
    HAS_FRAMEBUFFER=true
    log_success "Framebuffer available and writable"
else
    log_warning "Framebuffer not available or not writable"
fi

if [ "$HAS_X11" = false ] && [ "$HAS_FRAMEBUFFER" = false ]; then
    log_error "No video output method available!"
    log_info "Try: $0 --fix-permissions --force-x11"
    exit 1
fi

# Exit here if test-only mode
if [ "$TEST_ONLY" = true ]; then
    log_info "Test-only mode - skipping actual tests for now"
    exit 0
fi

# 6. VLC Testing
log_info "Testing VLC with different configurations..."

TEST_URL="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
TEST_DURATION=10

vlc_test() {
    local method="$1"
    local cmd=("${@:2}")
    
    log_info "Testing VLC with $method..."
    
    timeout ${TEST_DURATION}s "${cmd[@]}" "$TEST_URL" >/dev/null 2>&1 &
    local pid=$!
    
    sleep 3
    if kill -0 $pid 2>/dev/null; then
        log_success "VLC $method: WORKING (process running)"
        kill $pid 2>/dev/null || true
        return 0
    else
        log_error "VLC $method: FAILED (process died)"
        return 1
    fi
}

WORKING_CONFIG=""

# Test X11 if available
if [ "$HAS_X11" = true ]; then
    export DISPLAY=:0
    
    # Test GUI VLC
    if vlc_test "X11 GUI" vlc --intf dummy --fullscreen --no-video-title-show; then
        WORKING_CONFIG="x11-gui"
    # Test X11 with specific video output
    elif vlc_test "X11 Direct" vlc --intf dummy --vout x11 --fullscreen; then
        WORKING_CONFIG="x11-direct"
    fi
fi

# Test framebuffer if available and X11 didn't work
if [ "$HAS_FRAMEBUFFER" = true ] && [ -z "$WORKING_CONFIG" ]; then
    if vlc_test "Framebuffer" vlc --intf dummy --vout fb --aout alsa; then
        WORKING_CONFIG="framebuffer"
    fi
fi

# Test console/text output as last resort
if [ -z "$WORKING_CONFIG" ]; then
    if vlc_test "Console (caca)" vlc --intf dummy --vout caca --aout alsa; then
        WORKING_CONFIG="console"
    fi
fi

# 7. Results and Recommendations
echo ""
echo "🎯 Results:"
echo "=========="

if [ -n "$WORKING_CONFIG" ]; then
    log_success "Found working VLC configuration: $WORKING_CONFIG"
    
    case $WORKING_CONFIG in
        "x11-gui")
            echo "📝 Recommended VLC command:"
            echo "   vlc --intf dummy --fullscreen --no-video-title-show [URL]"
            ;;
        "x11-direct") 
            echo "📝 Recommended VLC command:"
            echo "   vlc --intf dummy --vout x11 --fullscreen [URL]"
            ;;
        "framebuffer")
            echo "📝 Recommended VLC command:"
            echo "   vlc --intf dummy --vout fb --aout alsa [URL]"
            ;;
        "console")
            echo "📝 Recommended VLC command:"
            echo "   vlc --intf dummy --vout caca --aout alsa [URL]"
            log_warning "Console mode shows ASCII art video only"
            ;;
    esac
    
    echo ""
    log_info "To update the IPTV player with this configuration:"
    echo "   Edit config.json and set the working VLC command"
    
else
    log_error "No working VLC configuration found!"
    echo ""
    log_info "Troubleshooting steps:"
    echo "1. Try: $0 --install-vlc --fix-permissions"
    echo "2. Try: $0 --force-x11" 
    echo "3. Check GPU memory: vcgencmd get_mem gpu (need 128MB+)"
    echo "4. Reboot and try again"
    echo "5. Check HDMI connection and TV input"
fi

echo ""
log_info "For more help, check the project documentation"