#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
set -euo pipefail
trap 'echo "检测到中断，已停止发布流程，不会继续提交/打标签。"; exit 130' INT TERM

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

RELEASE_META_FILE="$(mktemp)"
cleanup() {
  rm -f "$RELEASE_META_FILE"
}
trap cleanup EXIT

python3 - <<'PY' "$RELEASE_META_FILE"
import json
import re
import sys
from pathlib import Path

output_path = Path(sys.argv[1])
changelog_path = Path("CHANGELOG.md")
if not changelog_path.exists():
    sys.exit("未找到 CHANGELOG.md")

lines = changelog_path.read_text(encoding="utf-8").splitlines()
start_idx = None
version = None
for i, line in enumerate(lines):
    match = re.match(r"^##\s+([0-9]+\.[0-9]+\.[0-9]+(?:[+-][0-9A-Za-z.-]+)?)\s*$", line.strip())
    if match:
        start_idx = i
        version = match.group(1)
        break

if version is None or start_idx is None:
    sys.exit("CHANGELOG.md 顶部未找到合法版本标题（例如 ## 2.1.8）")

items = []
for line in lines[start_idx + 1:]:
    if re.match(r"^##\s+", line):
        break
    match = re.match(r"^-\s+(.+?)\s*$", line)
    if match:
        items.append(match.group(1).strip())

if not items:
    sys.exit(f"CHANGELOG.md 顶部版本 {version} 未找到更新条目，请至少保留一条 - 开头的记录")

output_path.write_text(
    json.dumps({"version": version, "items": items}, ensure_ascii=False),
    encoding="utf-8",
)

print(f"检测到待发布版本：{version}")
print("检测到待发布内容：")
for item in items:
    print(f"- {item}")
PY

VERSION="$(python3 - <<'PY' "$RELEASE_META_FILE"
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(data["version"])
PY
)"

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

python3 - <<'PY' "$RELEASE_META_FILE"
import json
import re
import sys
from pathlib import Path

meta = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
version = meta["version"]
items = meta["items"]
root = Path(".")

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

# CHANGELOG（必需：校验顶部版本块与脚本读取结果一致）
changelog_path = root / "CHANGELOG.md"
if not changelog_path.exists():
    sys.exit("未找到 CHANGELOG.md")

lines = changelog_path.read_text(encoding="utf-8").splitlines()
top_heading = next((line.strip() for line in lines if line.strip()), "")
if top_heading != f"## {version}":
    sys.exit("CHANGELOG.md 中未找到版本标题")
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
if check_pub_version "$PACKAGE_NAME" "$VERSION" 12 5; then
  echo "校验通过：pub.dev 已检测到 ${PACKAGE_NAME} ${VERSION}。"
else
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
    COMMIT_BODY="$(python3 - <<'PY' "$RELEASE_META_FILE"
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
items = data["items"]
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
