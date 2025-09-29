#!/bin/bash
# Simple X11 startup script for IPTV
export DISPLAY=:0
cd /home/jeremy/gtv
exec python3 iptv_smart_player.py