#!/bin/bash
# Simple X11 startup script for IPTV
export DISPLAY=:0
cd /home/jeremy/gtv
source venv/bin/activate
exec python iptv_smart_player.py