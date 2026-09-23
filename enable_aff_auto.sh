#!/bin/bash
# 제휴 자동 갱신 잡을 켠다. **전체 디스크 접근 권한을 준 뒤에** 실행할 것.
#
# 배경: launchd 가 띄운 프로세스는 ~/Library/CloudStorage(시놀로지)를 못 읽는다(macOS TCC).
#       2026-08-17 에 그걸 "파일 없음"으로 처리해 빈 데이터를 배포한 사고가 있어 잡을 꺼 뒀다.
#       이 스크립트는 **권한이 실제로 통하는지 먼저 확인**하고, 통과할 때만 잡을 켠다.
#
# 사용:  bash enable_aff_auto.sh
set -u
cd "$(dirname "$0")" || exit 1
PL="$HOME/Library/LaunchAgents/com.vinulabs.dashboard-aff.plist"
D="$HOME/Library/CloudStorage/SynologyDrive-AD_Monetization/5.제휴"

echo
echo "제휴 자동 갱신 — 권한 확인 후 켜기"
echo "─────────────────────────────────"

# 1) launchd 컨텍스트에서 시놀로지를 읽을 수 있는지 실측한다.
#    터미널에서 되는 것과 launchd 에서 되는 것은 별개다 — 반드시 launchd 로 재야 한다.
cat > /tmp/aff_tcc_probe.sh <<EOF
#!/bin/sh
if ls "$D" >/dev/null 2>&1; then echo OK; else echo "FAIL: \$(ls "$D" 2>&1 | head -1)"; fi
EOF
chmod +x /tmp/aff_tcc_probe.sh
cat > "$HOME/Library/LaunchAgents/com.vinulabs.afftcc.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.vinulabs.afftcc</string>
<key>ProgramArguments</key><array><string>/bin/sh</string><string>/tmp/aff_tcc_probe.sh</string></array>
<key>StandardOutPath</key><string>/tmp/aff_tcc_probe.out</string>
<key>StandardErrorPath</key><string>/tmp/aff_tcc_probe.out</string>
</dict></plist>
EOF
rm -f /tmp/aff_tcc_probe.out
launchctl unload "$HOME/Library/LaunchAgents/com.vinulabs.afftcc.plist" 2>/dev/null
launchctl load "$HOME/Library/LaunchAgents/com.vinulabs.afftcc.plist" 2>/dev/null
launchctl start com.vinulabs.afftcc 2>/dev/null
sleep 4
RES=$(cat /tmp/aff_tcc_probe.out 2>/dev/null | head -1)
launchctl unload "$HOME/Library/LaunchAgents/com.vinulabs.afftcc.plist" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.vinulabs.afftcc.plist" /tmp/aff_tcc_probe.sh /tmp/aff_tcc_probe.out

if [ "$RES" != "OK" ]; then
  echo "  ✗ launchd 가 아직 시놀로지를 못 읽습니다"
  echo "    $RES"
  echo
  echo "  시스템 설정 → 개인정보 보호 및 보안 → 전체 디스크 접근 권한 에서"
  echo "  '+' 를 누르고 ⌘⇧G 로 아래를 추가한 뒤 다시 실행하세요."
  echo "      /bin/sh"
  echo "      /usr/bin/python3"
  echo
  echo "  ⚠ 잡은 켜지 않았습니다 — 이 상태로 켜면 빈 데이터를 배포할 수 있습니다."
  exit 1
fi
echo "  ✓ launchd 에서 시놀로지 읽기 성공"

# 2) 감시 경로가 실재하는지
python3 - <<'PY' || exit 1
import plistlib, os, sys, unicodedata
p = os.path.expanduser('~/Library/LaunchAgents/com.vinulabs.dashboard-aff.plist')
if not os.path.exists(p):
    p += '.disabled'
d = plistlib.load(open(p, 'rb'))
bad = [x for x in d.get('WatchPaths', []) if not os.path.isdir(x)]
for x in d.get('WatchPaths', []):
    m = '✓' if os.path.isdir(x) else '✗'
    print(f"  {m} 감시: {unicodedata.normalize('NFC', x).replace(os.path.expanduser('~'), '~')}")
sys.exit(1 if bad else 0)
PY

# 3) 켠다
[ -f "$PL.disabled" ] && mv "$PL.disabled" "$PL"
launchctl unload "$PL" 2>/dev/null
launchctl load "$PL" || { echo "  ✗ 로드 실패"; exit 1; }
echo "  ✓ 잡 로드됨 (매일 09:00 + 리포트 폴더 변경 감시)"
echo
echo "─────────────────────────────────"
echo "끝. 로그: refresh.log"
echo "끄려면:  launchctl unload $PL && mv $PL $PL.disabled"
