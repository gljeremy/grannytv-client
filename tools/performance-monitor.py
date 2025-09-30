#!/usr/bin/env python3
"""
System Performance Monitor for IPTV Streaming
Monitors system resources and provides optimization suggestions
"""

import psutil
import subprocess
import time
from datetime import datetime

class IPTVPerformanceMonitor:
    def __init__(self):
        self.monitoring = True
        self.log_file = "performance_monitor.log"
        
    def log(self, message):
        """Log message with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        print(log_entry)
        
        with open(self.log_file, 'a') as f:
            f.write(log_entry + "\n")
    
    def get_system_metrics(self):
        """Get current system performance metrics"""
        try:
            # CPU usage
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_freq = psutil.cpu_freq()
            
            # Memory usage
            memory = psutil.virtual_memory()
            
            # Network usage
            network = psutil.net_io_counters()
            
            # GPU temperature (Pi specific)
            gpu_temp = None
            try:
                result = subprocess.run(['vcgencmd', 'measure_temp'], 
                                      capture_output=True, text=True, timeout=2)
                if result.returncode == 0:
                    gpu_temp = float(result.stdout.split('=')[1].split("'")[0])
            except Exception:
                pass
            
            # GPU memory (Pi specific)
            gpu_mem = None
            try:
                result = subprocess.run(['vcgencmd', 'get_mem', 'gpu'], 
                                      capture_output=True, text=True, timeout=2)
                if result.returncode == 0:
                    gpu_mem = int(result.stdout.split('=')[1].split('M')[0])
            except Exception:
                pass
            
            return {
                'timestamp': datetime.now().isoformat(),
                'cpu_percent': cpu_percent,
                'cpu_freq_current': cpu_freq.current if cpu_freq else None,
                'memory_percent': memory.percent,
                'memory_available_mb': memory.available / 1024 / 1024,
                'network_bytes_sent': network.bytes_sent,
                'network_bytes_recv': network.bytes_recv,
                'gpu_temp': gpu_temp,
                'gpu_mem_mb': gpu_mem
            }
        except Exception as e:
            self.log(f"Error getting metrics: {e}")
            return None
    
    def find_vlc_process(self):
        """Find running VLC process"""
        for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'cpu_percent', 'memory_percent']):
            try:
                if proc.info['name'] == 'vlc':
                    return proc.info
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        return None
    
    def analyze_performance(self, metrics, vlc_process):
        """Analyze performance and provide suggestions"""
        suggestions = []
        
        if metrics['cpu_percent'] > 80:
            suggestions.append("HIGH CPU: Consider reducing video quality or resolution")
        
        if metrics['memory_percent'] > 85:
            suggestions.append("HIGH MEMORY: Consider restarting system or closing other apps")
        
        if metrics['gpu_temp'] and metrics['gpu_temp'] > 75:
            suggestions.append(f"HIGH GPU TEMP ({metrics['gpu_temp']}°C): Improve cooling")
        
        if vlc_process and vlc_process['cpu_percent'] > 50:
            suggestions.append("VLC HIGH CPU: Stream may be CPU-intensive")
        
        return suggestions
    
    def monitor_performance(self, duration_minutes=60):
        """Monitor performance for specified duration"""
        self.log("🔍 Starting IPTV Performance Monitor")
        self.log(f"   Monitoring for {duration_minutes} minutes")
        
        start_time = time.time()
        end_time = start_time + (duration_minutes * 60)
        
        last_network_recv = 0
        
        while time.time() < end_time and self.monitoring:
            try:
                # Get system metrics
                metrics = self.get_system_metrics()
                if not metrics:
                    time.sleep(30)
                    continue
                
                # Find VLC process
                vlc_process = self.find_vlc_process()
                
                # Calculate network speed
                network_speed_mbps = 0
                if last_network_recv > 0:
                    bytes_diff = metrics['network_bytes_recv'] - last_network_recv
                    network_speed_mbps = (bytes_diff * 8) / (30 * 1024 * 1024)  # 30 second interval
                
                last_network_recv = metrics['network_bytes_recv']
                
                # Log current status
                status = f"CPU: {metrics['cpu_percent']:.1f}% | "
                status += f"RAM: {metrics['memory_percent']:.1f}% | "
                status += f"Network: {network_speed_mbps:.2f} Mbps"
                
                if metrics['gpu_temp']:
                    status += f" | GPU: {metrics['gpu_temp']:.1f}°C"
                
                if vlc_process:
                    status += f" | VLC: {vlc_process['cpu_percent']:.1f}% CPU"
                
                self.log(f"📊 {status}")
                
                # Analyze and provide suggestions
                suggestions = self.analyze_performance(metrics, vlc_process)
                for suggestion in suggestions:
                    self.log(f"💡 {suggestion}")
                
                # Check for critical issues
                if metrics['cpu_percent'] > 95:
                    self.log("🚨 CRITICAL: CPU usage extremely high!")
                
                if metrics['memory_percent'] > 95:
                    self.log("🚨 CRITICAL: Memory usage extremely high!")
                
                if not vlc_process:
                    self.log("⚠️ WARNING: VLC process not found")
                
                time.sleep(30)  # Check every 30 seconds
                
            except KeyboardInterrupt:
                self.log("📊 Monitoring stopped by user")
                break
            except Exception as e:
                self.log(f"❌ Error during monitoring: {e}")
                time.sleep(30)
        
        self.log("✅ Performance monitoring completed")
    
    def system_optimization_check(self):
        """Perform system optimization check"""
        self.log("🔧 System Optimization Check")
        
        # Check GPU memory
        try:
            result = subprocess.run(['vcgencmd', 'get_mem', 'gpu'], 
                                  capture_output=True, text=True, timeout=2)
            if result.returncode == 0:
                gpu_mem = int(result.stdout.split('=')[1].split('M')[0])
                if gpu_mem < 128:
                    self.log(f"💡 GPU memory is {gpu_mem}MB - consider increasing to 128MB+")
                else:
                    self.log(f"✅ GPU memory: {gpu_mem}MB (good)")
        except Exception:
            pass
        
        # Check network settings
        try:
            with open('/proc/sys/net/core/rmem_max', 'r') as f:
                rmem_max = int(f.read().strip())
                if rmem_max < 134217728:  # 128MB
                    self.log("💡 Consider running network optimization script")
                else:
                    self.log("✅ Network buffers optimized")
        except Exception:
            pass
        
        # Check for background processes
        high_cpu_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent']):
            try:
                if proc.info['cpu_percent'] > 10 and proc.info['name'] != 'vlc':
                    high_cpu_processes.append(f"{proc.info['name']} ({proc.info['cpu_percent']:.1f}%)")
            except Exception:
                continue
        
        if high_cpu_processes:
            self.log(f"💡 High CPU processes detected: {', '.join(high_cpu_processes)}")
        else:
            self.log("✅ No high CPU background processes")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='IPTV Performance Monitor')
    parser.add_argument('--duration', '-d', type=int, default=60,
                       help='Monitoring duration in minutes (default: 60)')
    parser.add_argument('--check-only', '-c', action='store_true',
                       help='Only perform optimization check')
    
    args = parser.parse_args()
    
    monitor = IPTVPerformanceMonitor()
    
    if args.check_only:
        monitor.system_optimization_check()
    else:
        monitor.system_optimization_check()
        monitor.monitor_performance(args.duration)

if __name__ == "__main__":
    main()