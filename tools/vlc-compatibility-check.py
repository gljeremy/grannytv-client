#!/usr/bin/env python3
"""
VLC Version Compatibility Checker
Checks VLC version and provides compatibility recommendations
"""

import subprocess
import json
import re
from datetime import datetime

class VLCCompatibilityChecker:
    def __init__(self):
        self.compatibility_file = "vlc_compatibility.json"
        self.version_info = None
        self.compatibility_data = self.load_compatibility_data()
    
    def load_compatibility_data(self):
        """Load VLC compatibility database"""
        try:
            with open(self.compatibility_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Warning: {self.compatibility_file} not found")
            return {"vlc_compatibility": {"known_versions": {}, "option_compatibility": {}}}
    
    def detect_vlc_version(self):
        """Detect installed VLC version"""
        try:
            result = subprocess.run(['vlc', '--version'], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version_output = result.stdout.strip()
                version_line = version_output.split('\n')[0] if version_output else ""
                
                # Extract version number
                version_match = re.search(r'VLC.*?(\d+\.\d+\.\d+)', version_line)
                if version_match:
                    version_str = version_match.group(1)
                    version_parts = [int(x) for x in version_str.split('.')]
                    
                    self.version_info = {
                        'version_string': version_line,
                        'version_number': version_str,
                        'major': version_parts[0],
                        'minor': version_parts[1],
                        'patch': version_parts[2],
                        'detected_at': datetime.now().isoformat()
                    }
                    return True
                else:
                    print("❌ Could not parse VLC version number")
            else:
                print("❌ VLC version check failed")
        except Exception as e:
            print(f"❌ Error detecting VLC: {e}")
        
        return False
    
    def get_compatibility_info(self):
        """Get compatibility information for detected VLC version"""
        if not self.version_info:
            return None
        
        version = self.version_info['version_number']
        major_minor = f"{self.version_info['major']}.{self.version_info['minor']}.x"
        
        # Check for exact version match first
        known_versions = self.compatibility_data['vlc_compatibility']['known_versions']
        
        if version in known_versions:
            return known_versions[version]
        elif major_minor in known_versions:
            return known_versions[major_minor]
        
        # Generate compatibility info based on version
        return self.generate_compatibility_info()
    
    def generate_compatibility_info(self):
        """Generate compatibility info based on version analysis"""
        if not self.version_info:
            return None
        
        major, minor = self.version_info['major'], self.version_info['minor']
        
        return {
            'supports_modern_hw_decode': major >= 3,
            'supports_mmal': major >= 2 and minor >= 2,
            'supports_advanced_caching': major >= 3,
            'supports_frame_management': major >= 3,
            'confidence': 'generated' if major >= 3 else 'limited'
        }
    
    def get_problematic_options(self):
        """Get list of options to avoid for this VLC version"""
        compatibility = self.get_compatibility_info()
        if not compatibility:
            return []
        
        problematic = []
        
        # Add deprecated options for modern VLC
        if compatibility.get('supports_modern_hw_decode', False):
            problematic.extend(['--no-hw-decode', '--mmal-display'])
        
        # Add version-specific problematic options
        if 'problematic_options' in compatibility:
            problematic.extend(compatibility['problematic_options'])
        
        return problematic
    
    def get_recommended_options(self):
        """Get recommended options for this VLC version"""
        compatibility = self.get_compatibility_info()
        if not compatibility:
            return []
        
        recommended = ['--quiet', '--no-video-title-show', '--disable-screensaver']
        
        if compatibility.get('supports_modern_hw_decode', False):
            recommended.extend(['--avcodec-hw=any', '--avcodec-hw=none'])
        
        if compatibility.get('supports_advanced_caching', False):
            recommended.extend(['--network-caching', '--live-caching', '--file-caching'])
        
        if compatibility.get('supports_frame_management', False):
            recommended.extend(['--drop-late-frames', '--skip-frames'])
        
        return recommended
    
    def save_version_log(self, log_file="vlc_version_history.log"):
        """Save version detection to log file"""
        if not self.version_info:
            return
        
        log_entry = f"{self.version_info['detected_at']}: {self.version_info['version_string']}\n"
        
        try:
            with open(log_file, 'a') as f:
                f.write(log_entry)
        except Exception as e:
            print(f"Warning: Could not write to log file: {e}")
    
    def print_compatibility_report(self):
        """Print detailed compatibility report"""
        if not self.detect_vlc_version():
            print("❌ Could not detect VLC version")
            return False
        
        print("🎬 VLC Compatibility Report")
        print("=" * 30)
        print(f"Version: {self.version_info['version_string']}")
        print(f"Detected: {self.version_info['version_number']}")
        print()
        
        compatibility = self.get_compatibility_info()
        if compatibility:
            print("✅ Supported Features:")
            for feature, supported in compatibility.items():
                if isinstance(supported, bool):
                    status = "✅" if supported else "❌"
                    feature_name = feature.replace('_', ' ').title()
                    print(f"   {status} {feature_name}")
            print()
        
        # Show problematic options
        problematic = self.get_problematic_options()
        if problematic:
            print("⚠️  Options to Avoid:")
            for option in problematic:
                print(f"   ❌ {option}")
            print()
        
        # Show recommended options
        recommended = self.get_recommended_options()
        if recommended:
            print("💡 Recommended Options:")
            for option in recommended[:10]:  # Show first 10
                print(f"   ✅ {option}")
            if len(recommended) > 10:
                print(f"   ... and {len(recommended) - 10} more")
            print()
        
        # Save to log
        self.save_version_log()
        print("📝 Version logged to vlc_version_history.log")
        
        return True

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='VLC Version Compatibility Checker')
    parser.add_argument('--report', action='store_true', help='Show detailed compatibility report')
    parser.add_argument('--version-only', action='store_true', help='Just show version number')
    parser.add_argument('--problematic-options', action='store_true', help='List problematic options')
    
    args = parser.parse_args()
    
    checker = VLCCompatibilityChecker()
    
    if args.version_only:
        if checker.detect_vlc_version():
            print(checker.version_info['version_number'])
        else:
            print("unknown")
    elif args.problematic_options:
        if checker.detect_vlc_version():
            problematic = checker.get_problematic_options()
            for option in problematic:
                print(option)
    else:
        checker.print_compatibility_report()

if __name__ == "__main__":
    main()