#!/usr/bin/env python3
"""skill_prompts.py → index.plain.html 의 `const AFFPROMPT=` 한 줄.

왜 심어야 하나: 배포본(GitHub Pages)에는 서버가 없어서 팀원의 복사 버튼이 API로
프롬프트를 못 가져온다. 그래서 페이지 안에 넣어 둔다.

⚠️ 정본은 `skill_prompts.py` 다. 이 파일은 옮겨 적기만 한다 — HTML을 손으로 고치지 말 것.
   `{from}`·`{to}` 자리는 그대로 남기고, 화면에서 기간을 끼워 넣는다.

호출 지점 (이 둘이면 로컬·배포 양쪽이 항상 최신):
  - aff_server.py 기동 시      → 로컬에서 보는 화면
  - encrypt.py 암호화 직전     → 배포본 (모든 배포가 여기를 지난다)
"""
import io
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
PLAIN = os.path.join(HERE, 'index.plain.html')
MARK = 'const AFFPROMPT='


def payload():
    import skill_prompts as sp
    out = {}
    for sid in sp.SKILLS:
        p = sp.full_prompt(sid)
        if p:
            out[sid] = p
    return out


def inject(path=PLAIN):
    """평문에 AFFPROMPT 한 줄을 심는다(있으면 교체). 바뀐 게 없으면 파일을 건드리지 않는다."""
    if not os.path.exists(path):
        return False
    src = io.open(path, encoding='utf-8').read()
    line = MARK + json.dumps(payload(), ensure_ascii=False) + ';\n'

    hits = [m for m in re.finditer(r'^' + MARK + r'.*$\n?', src, re.M)]
    if len(hits) > 1:
        raise RuntimeError(f'`{MARK}` 줄이 {len(hits)}개 — 손으로 넣은 게 섞였는지 확인할 것')
    if hits:
        if hits[0].group(0) == line:
            return False                       # 동일 — 건드리지 않는다
        new = src[:hits[0].start()] + line + src[hits[0].end():]
    else:
        # AFFSKILL 정의 바로 앞에 넣는다 — 둘은 같이 읽히는 짝이다
        anchor = re.search(r'^const AFFSKILL=', src, re.M)
        if not anchor:
            raise RuntimeError('`const AFFSKILL=` 를 못 찾음 — 넣을 자리를 정할 수 없다')
        new = src[:anchor.start()] + line + src[anchor.start():]
    io.open(path, 'w', encoding='utf-8').write(new)
    return True


if __name__ == '__main__':
    changed = inject()
    n = len(payload())
    print(f"[build_prompts] 스킬 {n}개 · {'갱신함' if changed else '변경 없음'}")
