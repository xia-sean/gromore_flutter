#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

read -r -p "请输入要发布的版本号(例如 2.1.3): " VERSION
if [[ -z "$VERSION" ]]; then
  echo "版本号不能为空"
  exit 1
fi
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "版本号格式不合法，应为 semver（例如 2.1.3 或 2.1.3+1）"
  exit 1
fi

read -r -p "请输入本次发版新增内容（多条用 ; 分隔）: " CHANGELOG_ITEMS
if [[ -z "$CHANGELOG_ITEMS" ]]; then
  echo "发版内容不能为空"
  exit 1
fi
export CHANGELOG_ITEMS

python3 - <<'PY' "$VERSION"
import os
import re
import sys
from pathlib import Path

version = sys.argv[1]
root = Path(".")
changelog_raw = os.environ.get("CHANGELOG_ITEMS", "").strip()
items = [s.strip().lstrip("- ").strip() for s in re.split(r"[;；\n]+", changelog_raw) if s.strip()]
if not items:
    sys.exit("发版内容不能为空")

def update_file(path: Path, pattern: str, repl: str, flags=0, required=False, count=0):
    if not path.exists():
        if required:
            sys.exit(f"未找到 {path}")
        return 0
    text = path.read_text(encoding="utf-8")
    new_text, changed = re.subn(pattern, repl, text, flags=flags, count=count)
    if changed > 0:
        path.write_text(new_text, encoding="utf-8")
    elif required:
        sys.exit(f"{path} 中未找到匹配字段")
    return changed

# pubspec.yaml version（必需）
update_file(
    root / "pubspec.yaml",
    r"^version:\s*.+$",
    f"version: {version}",
    flags=re.M,
    required=True,
)

# iOS podspec version（必需）
update_file(
    root / "ios" / "gromore_flutter.podspec",
    r"^(\s*s\.version\s*=\s*)['\"][^'\"]+['\"]",
    rf"\\1'{version}'",
    flags=re.M,
    required=True,
)

# README 安装示例版本（可选）
update_file(
    root / "README.md",
    r"gromore_flutter:\s*\^[0-9]+\.[0-9]+\.[0-9]+(?:[+-][0-9A-Za-z.-]+)?",
    f"gromore_flutter: ^{version}",
)

# CHANGELOG 顶部版本（必需：替换首个版本标题）
changelog_path = root / "CHANGELOG.md"
if not changelog_path.exists():
    sys.exit("未找到 CHANGELOG.md")

lines = changelog_path.read_text(encoding="utf-8").splitlines()
start_idx = None
for i, line in enumerate(lines):
    if re.match(r"^##\s+[0-9]+\.[0-9]+\.[0-9]+", line):
        start_idx = i
        break
if start_idx is None:
    sys.exit("CHANGELOG.md 中未找到版本标题")

end_idx = len(lines)
for j in range(start_idx + 1, len(lines)):
    if re.match(r"^##\s+[0-9]+\.[0-9]+\.[0-9]+", lines[j]):
        end_idx = j
        break

new_block = [f"## {version}", ""]
new_block.extend([f"- {item}" for item in items])
new_block.append("")

new_lines = lines[:start_idx] + new_block + lines[end_idx:]
changelog_path.write_text("\n".join(new_lines).rstrip() + "\n", encoding="utf-8")
PY

export PUB_HOSTED_URL="https://pub.dev"
export FLUTTER_STORAGE_BASE_URL="https://storage.googleapis.com"

flutter pub publish --server https://pub.dev

# 发布成功后自动提交并推送到 GitHub
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    COMMIT_TITLE="release: v${VERSION}"
    COMMIT_BODY="$(printf '%s\n' "${CHANGELOG_ITEMS}" | tr ';' '\n' | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//' -e '/^$/d' | sed 's/^/- /')"
    if [[ -n "$COMMIT_BODY" ]]; then
      git commit -m "$COMMIT_TITLE" -m "$COMMIT_BODY"
    else
      git commit -m "$COMMIT_TITLE"
    fi
    git tag "v${VERSION}"
    git push
    git push --tags
  else
    echo "工作区无变更，跳过提交与推送"
  fi
else
  echo "未检测到 git 仓库或 git 不可用，跳过提交与推送"
fi
