#!/usr/bin/env python3
"""
Stream Performance Analyzer for GrannyTV
Analyzes and optimizes stream database for maximum performance
"""

import json
import requests
import time
import concurrent.futures
import statistics
# from urllib.parse import urlparse  # Not used currently
from datetime import datetime

class StreamPerformanceAnalyzer:
    def __init__(self, streams_file='working_streams.json'):
        self.streams_file = streams_file
        self.performance_data = {}
        
    def load_streams(self):
        """Load stream database"""
        try:
            with open(self.streams_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"❌ Stream file {self.streams_file} not found")
            return {}
    
    def test_stream_latency(self, url, timeout=5):
        """Test HTTP response latency for a stream"""
        try:
            start_time = time.time()
            
            # Test initial HTTP response
            response = requests.head(url, timeout=timeout, allow_redirects=True)
            
            latency = (time.time() - start_time) * 1000  # Convert to milliseconds
            
            return {
                'latency_ms': round(latency, 2),
                'status_code': response.status_code,
                'success': response.status_code == 200,
                'content_type': response.headers.get('content-type', ''),
                'server': response.headers.get('server', ''),
                'cdn': self._detect_cdn(url, response.headers)
            }
        except requests.exceptions.Timeout:
            return {'latency_ms': 9999, 'success': False, 'error': 'timeout'}
        except Exception as e:
            return {'latency_ms': 9999, 'success': False, 'error': str(e)}
    
    def _detect_cdn(self, url, headers):
        """Detect CDN provider from URL and headers"""
        url_lower = url.lower()
        
        # Common CDN patterns
        cdn_patterns = {
            'cloudflare': ['cloudflare', 'cf-ray'],
            'fastly': ['fastly', 'fastly-'],
            'akamai': ['akamai', 'akamai-'],
            'amazon': ['amazonaws', 'cloudfront'],
            'google': ['googleapis', 'gvideo'],
            'microsoft': ['azure', 'msecnd'],
            'pluto': ['pluto.tv', 'plutotv']
        }
        
        # Check URL
        for cdn, patterns in cdn_patterns.items():
            for pattern in patterns:
                if pattern in url_lower:
                    return cdn
        
        # Check headers
        for header_name, header_value in headers.items():
            header_lower = f"{header_name}:{header_value}".lower()
            for cdn, patterns in cdn_patterns.items():
                for pattern in patterns:
                    if pattern in header_lower:
                        return cdn
        
        return 'unknown'
    
    def analyze_stream_batch(self, streams, batch_size=20):
        """Analyze streams in batches with concurrent requests"""
        results = {}
        stream_items = list(streams.items())
        
        print(f"🔍 Analyzing {len(stream_items)} streams in batches of {batch_size}...")
        
        for i in range(0, len(stream_items), batch_size):
            batch = stream_items[i:i+batch_size]
            batch_results = {}
            
            # Test batch concurrently
            with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
                future_to_url = {
                    executor.submit(self.test_stream_latency, url): (url, data)
                    for url, data in batch
                }
                
                for future in concurrent.futures.as_completed(future_to_url):
                    url, data = future_to_url[future]
                    try:
                        performance = future.result()
                        batch_results[url] = {
                            'stream_data': data,
                            'performance': performance
                        }
                        
                        # Progress indicator
                        if performance['success']:
                            print(f"   ✅ {data['name']}: {performance['latency_ms']}ms")
                        else:
                            print(f"   ❌ {data['name']}: Failed")
                            
                    except Exception as e:
                        print(f"   ❌ {data['name']}: Error - {e}")
            
            results.update(batch_results)
            
            # Brief pause between batches to avoid overwhelming servers
            if i + batch_size < len(stream_items):
                time.sleep(1)
        
        return results
    
    def generate_performance_report(self, results):
        """Generate comprehensive performance report"""
        successful_results = [r for r in results.values() if r['performance']['success']]
        
        if not successful_results:
            print("❌ No successful stream tests")
            return
        
        latencies = [r['performance']['latency_ms'] for r in successful_results]
        
        print(f"\n📊 Stream Performance Analysis Report")
        print(f"=" * 50)
        print(f"Total streams tested: {len(results)}")
        print(f"Successful tests: {len(successful_results)}")
        print(f"Success rate: {len(successful_results)/len(results)*100:.1f}%")
        print()
        
        print(f"🚀 Latency Statistics:")
        print(f"   Fastest: {min(latencies):.1f}ms")
        print(f"   Slowest: {max(latencies):.1f}ms") 
        print(f"   Average: {statistics.mean(latencies):.1f}ms")
        print(f"   Median: {statistics.median(latencies):.1f}ms")
        print()
        
        # CDN analysis
        cdn_counts = {}
        for result in successful_results:
            cdn = result['performance'].get('cdn', 'unknown')
            cdn_counts[cdn] = cdn_counts.get(cdn, 0) + 1
        
        print(f"🌐 CDN Distribution:")
        for cdn, count in sorted(cdn_counts.items(), key=lambda x: x[1], reverse=True):
            percentage = count / len(successful_results) * 100
            print(f"   {cdn.title()}: {count} streams ({percentage:.1f}%)")
        print()
        
        # Top 10 fastest streams
        fastest_streams = sorted(successful_results, key=lambda x: x['performance']['latency_ms'])[:10]
        print(f"🏆 Top 10 Fastest Streams:")
        for i, result in enumerate(fastest_streams, 1):
            name = result['stream_data']['name']
            latency = result['performance']['latency_ms']
            cdn = result['performance'].get('cdn', 'unknown')
            print(f"   {i:2d}. {name}: {latency}ms ({cdn})")
        print()
        
        return {
            'total_tested': len(results),
            'successful': len(successful_results),
            'success_rate': len(successful_results)/len(results)*100,
            'latency_stats': {
                'min': min(latencies),
                'max': max(latencies),
                'mean': statistics.mean(latencies),
                'median': statistics.median(latencies)
            },
            'cdn_distribution': cdn_counts,
            'fastest_streams': fastest_streams
        }
    
    def create_optimized_database(self, results, output_file='working_streams.json'):
        """Create performance-optimized stream database"""
        successful_results = [r for r in results.values() if r['performance']['success']]
        
        # Sort by latency (fastest first)
        sorted_results = sorted(successful_results, key=lambda x: x['performance']['latency_ms'])
        
        optimized_streams = {}
        
        for i, result in enumerate(sorted_results):
            url = None
            # Find the original URL
            for original_url, data in results.items():
                if data == result:
                    url = original_url
                    break
            
            if url:
                stream_data = result['stream_data'].copy()
                stream_data['performance_rank'] = i + 1
                stream_data['measured_latency_ms'] = result['performance']['latency_ms']
                stream_data['cdn_provider'] = result['performance'].get('cdn', 'unknown')
                stream_data['optimized_at'] = datetime.now().isoformat()
                
                optimized_streams[url] = stream_data
        
        # Save optimized database
        with open(output_file, 'w') as f:
            json.dump(optimized_streams, f, indent=2)
        
        print(f"✅ Optimized database saved: {output_file}")
        print(f"   {len(optimized_streams)} streams ranked by performance")
        
        return optimized_streams
    
    def run_analysis(self):
        """Run complete stream analysis"""
        print("🎬 Starting GrannyTV Stream Performance Analysis")
        print("=" * 50)
        
        # Load streams
        streams = self.load_streams()
        if not streams:
            return
        
        print(f"📥 Loaded {len(streams)} streams from {self.streams_file}")
        
        # Analyze performance
        results = self.analyze_stream_batch(streams)
        
        # Generate report
        report = self.generate_performance_report(results)
        
        # Create optimized database
        optimized_db = self.create_optimized_database(results)
        
        print("\n🎯 Recommendations:")
        if report and report['latency_stats']['mean'] < 1000:
            print("   ✅ Excellent average latency - streams are well optimized")
        elif report and report['latency_stats']['mean'] < 2000:
            print("   ⚠️  Moderate latency - consider using fastest streams for best UX")
        else:
            print("   ❌ High latency detected - network or CDN issues possible")
        
        print(f"\n🚀 Next steps:")
        print(f"   1. Use working_streams.json for best performance")
        print(f"   2. Update main player to prefer fastest streams")
        print(f"   3. Consider CDN-specific optimizations")
        
        return report, optimized_db

def main():
    analyzer = StreamPerformanceAnalyzer()
    analyzer.run_analysis()

if __name__ == "__main__":
    main()