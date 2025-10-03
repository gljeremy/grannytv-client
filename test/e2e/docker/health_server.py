#!/usr/bin/env python3
"""
Health check and command execution server for Pi simulator
"""

from flask import Flask, jsonify, request
import socket
import subprocess
import os
import time

app = Flask(__name__)

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'service': 'grannytv-pi-simulator',
        'container': socket.gethostname()
    })

@app.route('/execute', methods=['POST'])
def execute_command():
    """Execute a command on the Pi simulator"""
    data = request.get_json()
    if not data or 'command' not in data:
        return jsonify({'error': 'Missing command'}), 400
    
    command = data['command']
    cwd = data.get('cwd', '/home/jeremy/gtv')
    timeout = data.get('timeout', 30)
    user = data.get('user', 'jeremy')
    
    try:
        # Change to specified directory and run command
        if user != 'root':
            # Run as specified user
            full_command = f'cd {cwd} && sudo -u {user} {command}'
        else:
            full_command = f'cd {cwd} && {command}'
        
        result = subprocess.run(
            ['bash', '-c', full_command],
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        return jsonify({
            'returncode': result.returncode,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'success': result.returncode == 0,
            'command': command
        })
        
    except subprocess.TimeoutExpired:
        return jsonify({
            'error': 'Command timed out',
            'command': command,
            'timeout': timeout
        }), 408
    except Exception as e:
        return jsonify({
            'error': str(e),
            'command': command
        }), 500

@app.route('/file', methods=['GET', 'POST', 'DELETE'])
def file_operations():
    """File operations endpoint"""
    if request.method == 'GET':
        # Read file
        filepath = request.args.get('path')
        if not filepath:
            return jsonify({'error': 'Missing path parameter'}), 400
        
        try:
            with open(filepath, 'r') as f:
                content = f.read()
            return jsonify({
                'content': content,
                'path': filepath,
                'exists': True
            })
        except FileNotFoundError:
            return jsonify({
                'content': None,
                'path': filepath,
                'exists': False
            }), 404
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    
    elif request.method == 'POST':
        # Write file
        data = request.get_json()
        if not data or 'path' not in data or 'content' not in data:
            return jsonify({'error': 'Missing path or content'}), 400
        
        try:
            # Create directory if it doesn't exist
            os.makedirs(os.path.dirname(data['path']), exist_ok=True)
            
            with open(data['path'], 'w') as f:
                f.write(data['content'])
            
            return jsonify({
                'success': True,
                'path': data['path']
            })
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    
    elif request.method == 'DELETE':
        # Delete file
        filepath = request.args.get('path')
        if not filepath:
            return jsonify({'error': 'Missing path parameter'}), 400
        
        try:
            os.remove(filepath)
            return jsonify({
                'success': True,
                'path': filepath
            })
        except FileNotFoundError:
            return jsonify({
                'success': True,
                'path': filepath,
                'message': 'File already deleted'
            })
        except Exception as e:
            return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9080, debug=False)