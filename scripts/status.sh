#!/usr/bin/env bash
#
# CS 공부 현황 대시보드 생성기
# 과목 폴더의 YYYY-MM-DD-*.md 노트를 스캔해서 README.md의
# <!-- STATUS:START --> ~ <!-- STATUS:END --> 구간을 갱신합니다.
#
#   사용법: bash scripts/status.sh
#
set -euo pipefail

# 레포 루트로 이동 (스크립트 위치 기준)
cd "$(dirname "$0")/.."

README="README.md"

# date 구현체 감지 (macOS=BSD, Windows Git Bash/Linux=GNU)
# BSD date는 -j -f, GNU date는 -d 로 날짜를 파싱합니다.
if date -j -f "%Y-%m-%d" "2000-01-01" +%u >/dev/null 2>&1; then
  DATE_KIND="bsd"
else
  DATE_KIND="gnu"
fi

# YYYY-MM-DD -> 요일 번호 (1=월 .. 7=일)
dow_of() {
  if [ "$DATE_KIND" = "bsd" ]; then
    date -j -f "%Y-%m-%d" "$1" +%u
  else
    date -d "$1" +%u
  fi
}

# YYYY-MM-DD -> 하루 전 날짜 (YYYY-MM-DD)
prev_day() {
  if [ "$DATE_KIND" = "bsd" ]; then
    date -j -v-1d -f "%Y-%m-%d" "$1" +%Y-%m-%d
  else
    date -d "$1 - 1 day" +%Y-%m-%d
  fi
}

# 과목 폴더명 -> 보기 좋은 라벨 (01_network -> Network)
label() {
  local name="${1#*_}"          # 01_ 접두어 제거
  # 특수 표기 예외 (자동 대문자화로는 안 예쁜 것들)
  case "$name" in
    javascript) echo "JavaScript"; return ;;
  esac
  name="${name//-/ }"           # 하이픈 -> 공백
  # 각 단어 첫 글자 대문자
  echo "$name" | awk '{ for (i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2) } 1'
}

# 노트에서 제목(첫 H1) 추출, 없으면 파일명에서 유추
title_of() {
  local f="$1"
  local t
  t="$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# *//')"
  echo "${t:-$(basename "$f" .md)}"
}

# 모든 과목 노트 수집: "날짜|과목폴더|제목|경로"
records=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  base="$(basename "$f")"
  date="${base:0:10}"                       # YYYY-MM-DD
  dir="$(basename "$(dirname "$f")")"        # 01_network
  title="$(title_of "$f")"
  path="${f#./}"
  records+="${date}|${dir}|${title}|${path}"$'\n'
done < <(find . -type f -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md" ! -path "*/00-daily-report/*" | sort)

# 고유 학습 날짜 (내림차순)
dates_desc="$(echo "$records" | awk -F'|' 'NF{print $1}' | sort -ru)"
total_notes="$(echo "$records" | grep -c '|' || true)"
total_days="$(echo "$dates_desc" | grep -c . || true)"

is_studied() { echo "$dates_desc" | grep -qx "$1"; }

# 연속 학습(streak) 계산: 최근 학습일부터 하루씩 거슬러 올라가며
# 주말은 건너뛰고, 평일에 노트가 없으면 종료.
streak=0
latest="$(echo "$dates_desc" | head -1)"
if [ -n "$latest" ]; then
  cur="$latest"
  while true; do
    dow="$(dow_of "$cur")"                                   # 1=월 .. 7=일
    if [ "$dow" -ge 6 ]; then
      cur="$(prev_day "$cur")"
      continue
    fi
    if is_studied "$cur"; then
      streak=$((streak + 1))
      cur="$(prev_day "$cur")"
    else
      break
    fi
  done
fi

# 과목별 노트 수
subject_lines=""
while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  cnt="$(echo "$records" | awk -F'|' -v d="$dir" 'NF && $2==d {c++} END{print c+0}')"
  subject_lines+="| $(label "$dir") | ${cnt} |"$'\n'
done < <(echo "$records" | awk -F'|' 'NF{print $2}' | sort -u)

# 최근 노트 5개
recent_lines=""
while IFS='|' read -r date dir title path; do
  [ -z "$date" ] && continue
  recent_lines+="| ${date} | $(label "$dir") | ${title} | [노트](./${path}) |"$'\n'
done < <(echo "$records" | awk -F'|' 'NF' | sort -r | head -5)

now="$(date "+%Y-%m-%d %H:%M")"

# streak 응원 문구
if   [ "$streak" -ge 20 ]; then flame="🔥🔥🔥 미쳤다"
elif [ "$streak" -ge 10 ]; then flame="🔥🔥 불붙었다"
elif [ "$streak" -ge 5  ]; then flame="🔥 순항 중"
elif [ "$streak" -ge 1  ]; then flame="🌱 시작이 반"
else                            flame="💤 오늘 하나 어때요?"
fi

# 갱신할 대시보드 블록 생성 (START/END 마커 포함)
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
{
  echo "<!-- STATUS:START -->"
  echo "<!-- 이 구간은 scripts/status.sh가 자동 생성합니다. 직접 수정하지 마세요. -->"
  echo
  echo "## 📊 공부 현황 — 연속 ${streak}일째 ${flame}"
  echo
  echo "| 연속 학습(평일) | 총 학습일 | 총 노트 | 최근 학습일 |"
  echo "| :---: | :---: | :---: | :---: |"
  echo "| **${streak}일** | ${total_days}일 | ${total_notes}개 | ${latest:-없음} |"
  echo
  echo "<details>"
  echo "<summary>과목별 · 최근 노트 펼쳐보기</summary>"
  echo
  echo "**과목별**"
  echo
  echo "| 과목 | 노트 수 |"
  echo "| --- | --- |"
  printf '%s' "$subject_lines"
  echo
  echo "**최근 노트**"
  echo
  echo "| 날짜 | 과목 | 주제 | 링크 |"
  echo "| --- | --- | --- | --- |"
  printf '%s' "$recent_lines"
  echo
  echo "</details>"
  echo
  echo "<sub>🔄 마지막 갱신: ${now} · \`bash scripts/status.sh\`로 갱신</sub>"
  echo "<!-- STATUS:END -->"
} > "$TMP"

# README의 마커 구간을 새 블록으로 교체
if ! grep -q "<!-- STATUS:START -->" "$README" || ! grep -q "<!-- STATUS:END -->" "$README"; then
  echo "❌ ${README}에 <!-- STATUS:START --> / <!-- STATUS:END --> 마커가 없습니다." >&2
  exit 1
fi

NEW="$(mktemp)"
trap 'rm -f "$TMP" "$NEW"' EXIT
awk -v blockfile="$TMP" '
  BEGIN { while ((getline line < blockfile) > 0) block = block line "\n" }
  /<!-- STATUS:START -->/ { printf "%s", block; skip=1; next }
  /<!-- STATUS:END -->/   { skip=0; next }
  !skip { print }
' "$README" > "$NEW"
mv "$NEW" "$README"

echo "✅ ${README} 현황 구간 갱신 완료 — 연속 ${streak}일째, 총 ${total_notes}개 노트"
