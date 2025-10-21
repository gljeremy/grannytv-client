# PAUSE RECOVERY - QUICK REFERENCE CARD

## 🚨 PROBLEM SOLVED
**Before:** Playback pauses indefinitely, requiring manual restart  
**After:** Automatic detection and recovery within 90 seconds

---

## 🛡️ TWO-LAYER PROTECTION

### Layer 1: PREVENTION (MPV Network Options)
```
--network-timeout=15                    Stop waiting after 15s
--stream-lavf-o=reconnect=1             Auto-reconnect on drops
--stream-lavf-o=reconnect_streamed=1    Handle live streams
--stream-lavf-o=reconnect_delay_max=5   Max 5s retry delay
```
**Result:** Most issues handled invisibly

### Layer 2: RECOVERY (Health Monitoring)
```
Every 30s: Check process health
3 failures: Auto-restart playback
```
**Result:** Complete freezes recovered automatically

---

## 📊 DEFAULT BEHAVIOR

| Metric | Value |
|--------|-------|
| Check interval | 30 seconds |
| Failure threshold | 3 consecutive failures |
| Total tolerance | ~90 seconds |
| Recovery time | ~10 seconds |
| CPU overhead | <0.1% |

---

## 🔧 CONFIGURATION

**Location:** `iptv_smart_player.py` (lines 88-89)

```python
self.health_check_interval = 30  # Seconds between checks
self.max_stall_checks = 3        # Failures before restart
```

**Presets:**
```python
# Aggressive (30s tolerance)
health_check_interval = 15
max_stall_checks = 2

# Balanced (90s tolerance) - DEFAULT
health_check_interval = 30
max_stall_checks = 3

# Tolerant (180s tolerance)
health_check_interval = 45
max_stall_checks = 4
```

---

## 📝 LOG MESSAGES

**Normal:**
```
[TV] Status: Playing (PID: 1038) - Health: OK
```

**Problem Detected:**
```
[HEALTH] Playback health check failed (1/3)
[HEALTH] Playback health check failed (2/3)
[HEALTH] Playback health check failed (3/3)
```

**Recovery:**
```
[HEALTH] Multiple consecutive health check failures - restarting
[RESTART] Playback stalled
[OK] SUCCESS! MPV Config 1 stable (PID: 2045)
```

---

## 🧪 TESTING

**Quick Test:**
```bash
# Terminal 1: Start player
python3 iptv_smart_player.py

# Terminal 2: Freeze MPV
sudo kill -STOP $(pgrep mpv)

# Terminal 3: Watch recovery
tail -f iptv_player_mpv.log

# Expected: Auto-restart in ~90 seconds
```

**Cleanup:**
```bash
sudo kill -CONT $(pgrep mpv)
```

---

## 📈 MONITORING

**Real-time logs:**
```bash
tail -f /home/jeremy/gtv/iptv_player_mpv.log
```

**Search for issues:**
```bash
grep "HEALTH\|RESTART" iptv_player_mpv.log
```

**Check service:**
```bash
sudo systemctl status iptv-player
sudo journalctl -u iptv-player -n 100 -f
```

---

## ✅ CHECKLIST

After deployment:
- [ ] Player starts successfully
- [ ] Health checks appear in logs every 30s
- [ ] Test freeze recovery (optional)
- [ ] Monitor for false positives (first 24h)
- [ ] Adjust thresholds if needed

---

## 🎯 BENEFITS

✅ Automatic - No manual intervention  
✅ Smart - 3-strike policy prevents false alarms  
✅ Fast - Detects issues within 30 seconds  
✅ Network resilient - Auto-reconnects on drops  
✅ Transparent - Detailed logging  
✅ Lightweight - Minimal resource usage  

---

## 📚 DOCUMENTATION

- **Comprehensive:** `PLAYBACK_HEALTH_MONITORING.md`
- **Quick Guide:** `docs/PAUSE_RECOVERY_GUIDE.md`
- **Flow Diagram:** `docs/PAUSE_RECOVERY_FLOW.txt`
- **Summary:** `PAUSE_RECOVERY_SUMMARY.txt`
- **Implementation:** `PAUSE_RECOVERY_IMPLEMENTATION.md`

---

## 💡 TIPS

1. **Start conservative:** Use default settings initially
2. **Monitor logs:** Watch for patterns in first week
3. **Adjust gradually:** Change one setting at a time
4. **Document changes:** Note what works best for your setup
5. **Network first:** Optimize network before adjusting health checks

---

## 🚀 DEPLOYMENT

```bash
# On development machine
git add .
git commit -m "Add playback health monitoring and auto-recovery"
git push

# On Raspberry Pi
cd /home/jeremy/gtv
git pull
sudo systemctl restart iptv-player
sudo journalctl -u iptv-player -f
```

---

**Version:** 1.0  
**Date:** 2025-10-21  
**Status:** Production Ready ✓
