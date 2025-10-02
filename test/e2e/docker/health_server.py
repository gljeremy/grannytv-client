# Health check endpoint for Pi simulator
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/health')
def health_check():
    """Health check endpoint for Docker healthcheck"""
    return jsonify({
        'status': 'ok',
        'service': 'grannytv-pi-simulator',
        'container': os.getenv('HOSTNAME', 'unknown')
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)