#!/bin/bash
# team_setup 꾸러미를 **설치본(~/.claude/skills)에서** 다시 만든다.
#
# 왜 이 방향인가 (2026-09-21):
#   예전엔 team_setup 을 손으로 고치고 setup_team.sh 로 설치했다. 그런데 실제로는
#   내가 ~/.claude/skills 쪽을 고쳐 쓰다 보니 둘이 갈라졌고, 2026-09-21 시점에
#   4개 스킬에서 team_setup 이 **최대 119줄 뒤처져** 있었다.
#   그대로 setup_team.sh 를 돌렸으면 최신 문서를 옛 것으로 덮어쓸 뻔했다.
#   → 정본은 설치본. 이 스크립트가 배포 꾸러미를 갱신한다.
#
# 사용:  bash pack_team.sh
set -e
SRC="$HOME/.claude/skills"
DST="$(cd "$(dirname "$0")" && pwd)/team_setup"
DASH="$(cd "$(dirname "$0")" && pwd)"

echo "team_setup 꾸러미 갱신"
echo "  정본: $SRC"
echo "─────────────────────────────────"

n=0
for d in "$DST"/*/; do
  s=$(basename "$d")
  [ -f "$SRC/$s/SKILL.md" ] || { echo "  ⚠ 설치본에 없음 — 건너뜀: $s"; continue; }
  mkdir -p "$DST/$s"
  if cmp -s "$SRC/$s/SKILL.md" "$DST/$s/SKILL.md"; then
    echo "  = $s"
  else
    cp "$SRC/$s/SKILL.md" "$DST/$s/SKILL.md"
    echo "  ↻ $s  (갱신)"
    n=$((n+1))
  fi
  if [ -d "$SRC/$s/scripts" ]; then
    mkdir -p "$DST/$s/scripts"
    cp "$SRC/$s"/scripts/* "$DST/$s/scripts/" 2>/dev/null || true
  fi
done

# impact_api.py — 애플 스킬 2개가 쓴다. 대시보드 저장소가 정본이고,
# 팀원 맥엔 그 저장소가 없으므로 스킬 안에 사본을 같이 넣는다.
for s in apple-weekly-report apple-monthly-close; do
  [ -d "$DST/$s" ] || continue
  mkdir -p "$DST/$s/scripts"
  cp "$DASH/impact_api.py" "$DST/$s/scripts/impact_api.py"
  echo "  + $s/scripts/impact_api.py"
done

echo "─────────────────────────────────"
echo "끝. 갱신된 SKILL.md: ${n}개"
echo "팀원에게는 team_setup 폴더를 통째로 전달하고, 그 안에서 'bash setup_team.sh' 를 돌리게 합니다."
