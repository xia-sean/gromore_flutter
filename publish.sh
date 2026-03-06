#!/usr/bin/env bash
set -euo pipefail
trap 'echo "检测到中断，已停止发布流程，不会继续提交/打标签。"; exit 130' INT TERM

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

TAG_NAME="v${VERSION}"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git rev-parse -q --verify "refs/tags/${TAG_NAME}" >/dev/null; then
    TAG_COMMIT="$(git rev-list -n 1 "${TAG_NAME}")"
    HEAD_COMMIT="$(git rev-parse HEAD)"
    echo "检测到本地已存在标签 ${TAG_NAME} -> ${TAG_COMMIT}"
    if [[ "$TAG_COMMIT" != "$HEAD_COMMIT" ]]; then
      echo "标签 ${TAG_NAME} 不指向当前提交，建议改用新版本号发布，或先手动处理该标签后重试。"
      exit 1
    fi
  fi
fi

read -r -p "请输入本次发版新增内容（多条用 ;/； 分隔）: " CHANGELOG_ITEMS
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
items = [s.strip().lstrip("- ").strip() for s in re.split(r"\s*[;；]\s*", changelog_raw) if s.strip()]
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
    rf"\1'{version}'",
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

if command -v curl >/dev/null 2>&1; then
  echo "预检查 Google OAuth 连通性..."
  if ! curl -sS -o /dev/null --max-time 12 "https://accounts.google.com/o/oauth2/token"; then
    echo "无法访问 https://accounts.google.com/o/oauth2/token（发布鉴权必需）。"
    echo "请切换可访问 Google OAuth 的网络或代理后重试。"
    exit 1
  fi
  if ! curl -sS -o /dev/null --max-time 12 "https://oauth2.googleapis.com/token"; then
    echo "无法访问 https://oauth2.googleapis.com/token（发布鉴权必需）。"
    echo "请切换可访问 Google OAuth 的网络或代理后重试。"
    exit 1
  fi
fi

flutter pub publish --server https://pub.dev --force

PACKAGE_NAME="$(python3 - <<'PY'
from pathlib import Path
import re

text = Path("pubspec.yaml").read_text(encoding="utf-8")
m = re.search(r"^name:\s*([^\s#]+)\s*$", text, re.M)
if not m:
    raise SystemExit("未在 pubspec.yaml 中找到 name")
print(m.group(1))
PY
)"

check_pub_version() {
  local package="$1"
  local version="$2"
  local max_retry="${3:-8}"
  local sleep_sec="${4:-5}"
  local i

  for ((i=1; i<=max_retry; i++)); do
    if curl -fsSL "https://pub.dev/api/packages/${package}" | python3 -c '
import json
import sys

target = sys.argv[1]
data = json.load(sys.stdin)
versions = {item.get("version") for item in data.get("versions", [])}
sys.exit(0 if target in versions else 1)
' "$version"
    then
      return 0
    fi
    sleep "$sleep_sec"
  done
  return 1
}

echo "校验 pub.dev 是否已出现 ${PACKAGE_NAME} ${VERSION} ..."
if ! check_pub_version "$PACKAGE_NAME" "$VERSION" 12 5; then
  echo "未在 pub.dev 检测到 ${PACKAGE_NAME} ${VERSION}，停止后续 git 提交/打标签。"
  exit 1
fi

# 发布成功后自动提交并推送到 GitHub
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "即将提交以下文件："
    git status --short
    echo "如需终止提交，请现在按 Ctrl+C"
    git add -A
    COMMIT_TITLE="release: v${VERSION}"
    COMMIT_BODY="$(python3 - <<'PY'
import os
import re

raw = os.environ.get("CHANGELOG_ITEMS", "")
items = [s.strip().lstrip("- ").strip() for s in re.split(r"\s*[;；]\s*", raw) if s.strip()]
print("\n".join(f"- {item}" for item in items))
PY
    )"
    if [[ -n "$COMMIT_BODY" ]]; then
      git commit -m "$COMMIT_TITLE" -m "$COMMIT_BODY"
    else
      git commit -m "$COMMIT_TITLE"
    fi
    if git rev-parse -q --verify "refs/tags/v${VERSION}" >/dev/null; then
      EXISTING_TAG_COMMIT="$(git rev-list -n 1 "v${VERSION}")"
      CURRENT_HEAD_COMMIT="$(git rev-parse HEAD)"
      if [[ "$EXISTING_TAG_COMMIT" != "$CURRENT_HEAD_COMMIT" ]]; then
        echo "标签 v${VERSION} 已存在且不指向当前提交，请手动处理后再推送。"
        exit 1
      fi
      echo "标签 v${VERSION} 已存在且指向当前提交，跳过创建标签"
    else
      git tag "v${VERSION}"
    fi
    git push
    git push --tags
  else
    echo "工作区无变更，跳过提交与推送"
  fi
else
  echo "未检测到 git 仓库或 git 不可用，跳过提交与推送"
fi
