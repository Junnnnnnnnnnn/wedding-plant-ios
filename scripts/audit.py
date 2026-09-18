"""푸시 전 감사 둘.

윈도우에서는 App 타깃을 타입체크할 수 없다(`swiftc -frontend -parse` 는 파일 하나의
구문만 본다). 그래서 **교차 파일 문제는 CI 에서야 알게 되고**, 실제로 그 왕복을
세 번 썼다. 여기서 미리 잡는다.

    python scripts/audit.py

1. **모듈 범위 이름 충돌** — 같은 이름을 두 파일에서 선언한 경우. 둘 다
   `private`/`fileprivate` 면 괜찮지만, **한쪽이라도 internal 이면 재선언**이다.
   `SectionHeader`(UserView) 와 `ActivityShareSheet`(SettingView) 가 그렇게 깨졌다.

2. **Core 모듈 심볼 사용처 ↔ import 대조** — `BrandSheet` 의 `WPUtils`,
   `FeedDetailView` 의 `WPNetworking`, `AppEnvironment` 의 `WPUtils` 가 그랬다.
   **목록에 심볼을 빠뜨리면 감사가 통과해도 CI 가 깨진다**(`JWTDecoder` 로 겪었다).
   그래서 목록을 손으로 적지 않고 `Core/Sources/<모듈>` 의 `public` 선언에서 뽑는다.
"""

import os
import re
import sys
from collections import defaultdict

APP = os.path.join("App", "Sources")
CORE = os.path.join("Core", "Sources")

# **들여쓰기가 없는 줄만 본다.** 중첩 타입은 바깥 타입 안에 갇혀 있어 부딪히지
# 않는다 — `MainViewModel.Tab` 과 `BudgetDetailViewModel.Tab` 이 그렇다.
DECL = re.compile(
    r"^(?P<mods>(?:public |internal |private |fileprivate |final |@MainActor\s+)*)"
    r"(?:struct|class|enum|protocol|actor)\s+(?P<name>[A-Za-z_]\w*)"
)
# **들여쓰기가 없는 줄만 본다.** 타입 *안*의 `public func clear()` 까지 세면
# `clear`·`save`·`Group` 처럼 SwiftUI·Foundation 과 겹치는 이름이 전부 걸려
# 감사가 거짓 경고로 뒤덮인다 — 그러면 아무도 안 본다.
PUBLIC_DECL = re.compile(
    r"^public\s+(?:final\s+)?(?:struct|class|enum|protocol|actor|func|typealias)\s+"
    r"(?P<name>[A-Za-z_]\w*)"
)


def swift_files(root):
    for base, _, names in os.walk(root):
        for name in names:
            if name.endswith(".swift"):
                yield os.path.join(base, name)


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)


def code_only(source):
    """주석과 import 줄을 지운 본문.

    **주석 속 이름을 세면 안 된다.** `GuestStore` 의 "Core 의 `GuestMigration` 에
    있다" 같은 설명 한 줄 때문에 import 가 빠졌다고 보고하게 된다 — 거짓 경고가
    쌓이면 감사를 아무도 안 본다.
    """
    source = BLOCK_COMMENT.sub("", source)
    lines = []
    for line in source.splitlines():
        if line.startswith("import "):
            continue
        lines.append(line.split("//", 1)[0])
    return "\n".join(lines)


def audit_name_collisions():
    """같은 이름이 두 파일에 있고, 그 가운데 internal 선언이 섞여 있으면 재선언이다."""
    seen = defaultdict(list)  # name -> [(path, is_private)]
    for path in swift_files(APP):
        for line in read(path).splitlines():
            match = DECL.match(line)
            if not match:
                continue
            mods = match.group("mods")
            is_private = "private" in mods or "fileprivate" in mods
            seen[match.group("name")].append((path, is_private))

    problems = []
    for name, entries in sorted(seen.items()):
        paths = {path for path, _ in entries}
        if len(paths) < 2:
            continue
        # 전부 private 이면 파일 안에 갇혀 있어 충돌하지 않는다.
        if all(is_private for _, is_private in entries):
            continue
        where = ", ".join(sorted(paths))
        problems.append(f"{name} — {where}")
    return problems


def core_module_symbols():
    """Core 각 모듈이 실제로 내보내는 이름. 손으로 적지 않는다."""
    modules = {}
    if not os.path.isdir(CORE):
        return modules
    for module in sorted(os.listdir(CORE)):
        directory = os.path.join(CORE, module)
        if not os.path.isdir(directory):
            continue
        names = set()
        for path in swift_files(directory):
            for line in read(path).splitlines():
                match = PUBLIC_DECL.match(line)
                if match:
                    names.add(match.group("name"))
        # App 모듈이 같은 이름을 스스로 선언하면 import 없이도 풀린다
        # (`WPFont` 가 그렇다 — Core 가 아니라 DesignSystem 에 있다).
        if names:
            modules[module] = names
    return modules


def audit_missing_imports():
    modules = core_module_symbols()
    app_declared = set()
    for path in swift_files(APP):
        for line in read(path).splitlines():
            match = DECL.match(line)
            if match:
                app_declared.add(match.group("name"))

    problems = []
    for path in swift_files(APP):
        source = read(path)
        imports = set(re.findall(r"^import (\w+)", source, re.M))
        body = code_only(source)
        for module, names in modules.items():
            if module in imports:
                continue
            for name in sorted(names):
                if name in app_declared:
                    continue
                if re.search(rf"\b{re.escape(name)}\b", body):
                    problems.append(f"{path}: {name} → import {module}")
                    break
    return problems


def main():
    collisions = audit_name_collisions()
    imports = audit_missing_imports()

    print("== 1) 모듈 범위 이름 충돌 ==")
    print("없음" if not collisions else "\n".join(collisions))
    print()
    print("== 2) Core 모듈 import 누락 ==")
    print("없음" if not imports else "\n".join(imports))

    return 1 if (collisions or imports) else 0


if __name__ == "__main__":
    sys.exit(main())
