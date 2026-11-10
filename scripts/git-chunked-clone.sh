#!/bin/bash
# git-chunked-clone.sh —— 分块克隆大仓库（支持子模块递归 / 服务端不支持 filter 时改用压缩包）
#
# 把一次几百 MB 的传输拆成几十次几 MB~几十 MB 的小请求，用于绕过
# 代理/网络对单次传输的限制（例如 Cloudflare Workers 免费版每次调用
# 只有 10ms CPU 预算，一次拉几百 MB 必定中途被杀）。
#
# 用法:
#   git-chunked-clone.sh <repo-url> [target-dir] [branch]
#   git-chunked-clone.sh --all [-n]
#   git-chunked-clone.sh --submodule <path> [-r] [-n]
#
# 原理:
#   1) --depth 1 --filter=blob:none --sparse  只拉提交和目录树
#   2) git sparse-checkout set <目录>         每次只为该目录发一个请求补 blob
#   3) git sparse-checkout disable            全部到齐后还原完整工作区
#
# 若服务端不支持 partial clone（filter），会自动改用压缩包（archive）下载。
#
# 中断后重新执行同一条命令即可，会从当前进度继续。

set -u

SELF=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")
: "${CHUNKED_TIMEOUT:=480}"
: "${CHUNKED_MAX_DEPTH:=10}"
DEPTH="${CHUNKED_DEPTH:-0}"

usage() {
  cat <<'EOF'
用法:
  git-chunked-clone.sh <repo-url> [target-dir] [branch]   普通克隆
  git-chunked-clone.sh --all [-n]                          拉取当前仓库的所有子模块（含嵌套）
  git-chunked-clone.sh --submodule <path> [-r] [-n]        拉取指定子模块

选项:
  --all, -a        处理当前仓库 .gitmodules 里的全部子模块，并自动递归
  --submodule,-s   指定单个子模块路径（自动读 URL / 锁定提交 / 所在分支）
  -r, --recursive  处理完当前仓库后，递归处理它自己的子模块
  --no-filter      跳过 git 克隆，直接用压缩包（archive）下载
  -n, --dry-run    只打印解析结果，不实际下载
  -h, --help       显示本帮助

环境变量:
  CHUNKED_TIMEOUT    单个目录拉取超时秒数，默认 480
  CHUNKED_MAX_DEPTH  递归深度上限，默认 10

说明:
  服务端不支持 partial clone 时（git 提示 "filtering not recognized by server"），
  脚本会自动改用压缩包下载；压缩包模式产出的目录不含 .git。
EOF
}

die() { echo "错误: $*" >&2; exit 1; }

# 把 .gitmodules 里的相对 URL（./ ../）解析成绝对 URL
resolve_url() {
  local url="$1" base rel
  case "$url" in
    ./*|../*)
      base=$(git remote get-url origin 2>/dev/null) || { echo "$url"; return; }
      base="${base%/}"
      base="${base%.git}"
      rel="$url"
      while [ "${rel#../}" != "$rel" ]; do
        base="${base%/*}"
        rel="${rel#../}"
      done
      rel="${rel#./}"
      echo "$base/$rel"
      ;;
    *) echo "$url" ;;
  esac
}

# 把 repo URL 归一化成 host/owner/repo
url_parts() {
  local u="$1"
  u="${u%/}"
  u="${u%.git}"
  u="${u#https://}"
  u="${u#http://}"
  u="${u#ssh://}"
  u="${u#git://}"
  u="${u#git@}"
  u="${u/:/\/}"
  echo "$u"
}

# 压缩包下载：依次尝试各平台的 archive 地址
tarball_fetch() {
  local ref="$1" parts host rest owner repo u tmp ok=0
  parts=$(url_parts "$REPO")
  host="${parts%%/*}"
  rest="${parts#*/}"
  owner="${rest%%/*}"
  repo="${rest##*/}"

  [ -n "$ref" ] || ref=$(git ls-remote --symref "$REPO" HEAD 2>/dev/null | awk '/^ref:/{print $2}' | sed 's#refs/heads/##')
  [ -n "$ref" ] || { echo "无法确定分支/提交，压缩包模式退出" >&2; return 1; }

  tmp=$(mktemp) || return 1
  local urls=()
  [ "$host" = "github.com" ] && urls+=("https://codeload.github.com/$owner/$repo/tar.gz/$ref")
  case "$host" in *gitlab*) urls+=("https://$host/$owner/$repo/-/archive/$ref/$repo-$ref.tar.gz") ;; esac
  urls+=("https://$host/$owner/$repo/archive/$ref.tar.gz")
  urls+=("https://$host/$owner/$repo/archive/refs/heads/$ref.tar.gz")

  for u in "${urls[@]}"; do
    echo "    尝试压缩包: $u"
    if curl -fL --retry 2 --retry-delay 2 --connect-timeout 20 -o "$tmp" "$u" 2>/dev/null; then
      if gzip -t "$tmp" 2>/dev/null; then ok=1; break; fi
      echo "    下载内容不是有效 gzip，换下一个地址"
    fi
  done

  if [ $ok -ne 1 ]; then rm -f "$tmp"; return 1; fi

  mkdir -p "$DIR" || { rm -f "$tmp"; return 1; }
  if ! tar xzf "$tmp" -C "$DIR" --strip-components=1; then rm -f "$tmp"; return 1; fi
  rm -f "$tmp"
  return 0
}

MODE=clone
DRY=0
RECURSE=0
NOFILTER=0
REPO=""
DIR=""
BRANCH=""
SUBPATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --all|-a)        MODE=all; RECURSE=1; shift ;;
    -r|--recursive)  RECURSE=1; shift ;;
    --submodule|-s)  MODE=submodule; SUBPATH="${2:-}"; shift 2 ;;
    --no-filter)     NOFILTER=1; shift ;;
    --dry-run|-n)    DRY=1; shift ;;
    -h|--help)       usage; exit 0 ;;
    -*)              echo "未知参数: $1" >&2; usage; exit 1 ;;
    *)               break ;;
  esac
done

# ---------- --all：遍历当前仓库的全部子模块 ----------
if [ "$MODE" = all ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "请在仓库目录里执行 --all"
  cd "$ROOT" || exit 1
  [ -f .gitmodules ] || die "当前仓库没有 .gitmodules"
  [ "$DEPTH" -lt "$CHUNKED_MAX_DEPTH" ] || die "递归深度超过上限 $CHUNKED_MAX_DEPTH"

  RC=0
  while read -r key val; do
    case "$key" in
      submodule.*.path)
        echo
        echo "======== 子模块: $val ========"
        if [ "$DRY" = 1 ]; then
          "$SELF" --submodule "$val" --dry-run || RC=2
        else
          CHUNKED_DEPTH=$((DEPTH + 1)) "$SELF" --submodule "$val" -r $( [ "$NOFILTER" = 1 ] && echo --no-filter ) || RC=2
        fi
        ;;
    esac
  done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null)
  exit $RC
fi

# ---------- 子模块模式：解析 URL / 锁定提交 / 分支 ----------
ROOT=""
SHA=""
if [ "$MODE" = submodule ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "当前目录不是 git 仓库，请在父仓库里执行"
  cd "$ROOT" || exit 1
  [ -n "$SUBPATH" ] || die "--submodule 需要一个子模块路径，例如: --submodule linux-fslc"
  [ -f .gitmodules ] || die "当前仓库没有 .gitmodules"

  NAME=""
  while read -r key val; do
    case "$key" in
      submodule.*.path)
        if [ "$val" = "$SUBPATH" ]; then
          NAME="${key#submodule.}"
          NAME="${NAME%.path}"
        fi
        ;;
    esac
  done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null)

  [ -n "$NAME" ] || die "在 .gitmodules 里找不到路径为 '$SUBPATH' 的子模块"

  RAWURL=$(git config -f .gitmodules --get "submodule.$NAME.url" 2>/dev/null) || true
  [ -n "$RAWURL" ] || die "读不到子模块 $NAME 的 url"
  REPO=$(resolve_url "$RAWURL")

  SHA=$(git rev-parse "HEAD:$SUBPATH" 2>/dev/null) || die "索引里没有 '$SUBPATH'，确认路径是否正确"
  DIR="$ROOT/$SUBPATH"

  echo "子模块  : $SUBPATH"
  echo "URL     : $REPO"
  [ "$REPO" != "$RAWURL" ] && echo "（.gitmodules 里写的是相对地址: $RAWURL）"
  echo "锁定提交: $SHA"

  BRANCH=""
  ref=$(git ls-remote --heads "$REPO" 2>/dev/null | awk -v s="$SHA" '$1==s {print $2; exit}')
  if [ -n "${ref:-}" ]; then
    BRANCH="${ref#refs/heads/}"
  else
    ref=$(git ls-remote --tags "$REPO" 2>/dev/null | awk -v s="$SHA" '$1==s {print $2; exit}')
    [ -n "${ref:-}" ] && BRANCH="${ref#refs/tags/}"
  fi
  if [ -n "$BRANCH" ]; then
    echo "所在分支: $BRANCH"
  else
    echo "所在分支: 未找到（将先拉默认分支，再按提交补拉）"
  fi

  if [ "$DRY" = 1 ]; then
    echo "目标目录: $DIR"
    [ -d "$DIR/.git" ] && echo "状态    : 已存在，将续跑" || echo "状态    : 尚未克隆"
    echo "（--dry-run，未执行下载）"
    exit 0
  fi
else
  REPO="${1:-}"
  if [ -z "$REPO" ]; then usage; exit 1; fi
  DIR="${2:-$(basename "$REPO" .git)}"
  BRANCH="${3:-}"
  if [ "$DRY" = 1 ]; then
    echo "URL     : $REPO"
    echo "目标目录: $DIR"
    echo "分支    : ${BRANCH:-（默认）}"
    echo "（--dry-run，未执行下载）"
    exit 0
  fi
fi

TARBALL=0

# ---------- 第一步：骨架（已存在则续跑） ----------
if [ -d "$DIR/.git" ]; then
  echo ">>> [1/4] 检测到已有仓库，从当前进度继续: $DIR"
  cd "$DIR" || exit 1
elif [ "$NOFILTER" = 1 ]; then
  echo ">>> [1/4] --no-filter：跳过 git 克隆，改用压缩包"
  if [ -d "$DIR" ]; then rm -rf "$DIR"; fi
  tarball_fetch "${SHA:-$BRANCH}" || die "压缩包下载失败"
  TARBALL=1
else
  # 已 checkout 的父仓库里，子模块路径会留下一个空目录，先清掉
  if [ -d "$DIR" ] && [ -z "$(ls -A "$DIR" 2>/dev/null)" ]; then
    rmdir "$DIR" 2>/dev/null || true
  fi
  if [ -e "$DIR" ]; then
    die "目标已存在且不是 git 仓库: $DIR（请换个目录名或手动删除）"
  fi
  CLONE_ARGS=(--depth 1 --filter=blob:none --sparse)
  [ -n "$BRANCH" ] && CLONE_ARGS+=(--branch "$BRANCH")

  echo ">>> [1/4] 拉取骨架（只有提交和目录树，通常几 MB）"
  LOG=$(mktemp)
  git clone "${CLONE_ARGS[@]}" "$REPO" "$DIR" >"$LOG" 2>&1
  rc=$?
  cat "$LOG"

  filter_warn=0
  grep -q "filtering not recognized" "$LOG" && filter_warn=1
  rm -f "$LOG"

  if [ "$filter_warn" = 1 ] && [ "$rc" -ne 0 ]; then
    echo
    echo "检测到服务端不支持 partial clone，自动改用压缩包下载"
    rm -rf "$DIR"
    tarball_fetch "${SHA:-$BRANCH}" || die "压缩包下载失败"
    TARBALL=1
  elif [ "$rc" -ne 0 ]; then
    die "骨架克隆失败"
  elif [ "$filter_warn" = 1 ]; then
    echo
    echo "注意: 服务端不支持 partial clone，filter 被忽略（本次仍克隆成功）"
  fi
  [ "$TARBALL" = 0 ] && { cd "$DIR" || exit 1; }
fi

# ---------- 压缩包模式：没有 .git，直接收尾 ----------
if [ "$TARBALL" = 1 ]; then
  case "$DIR" in
    /*) shown_dir="$DIR" ;;
    *)  shown_dir="$(pwd)/$DIR" ;;
  esac
  echo
  echo "完成（压缩包模式，目录不含 .git）:"
  echo "  目录  : $shown_dir"
  echo "  文件数: $(find "$DIR" -type f | wc -l)"
  echo "  体积  : $(du -sh "$DIR" | cut -f1)"
  if [ "$MODE" = submodule ]; then
    echo
    echo "注意: 该目录不是 git 仓库，父仓库 git submodule status 会显示未初始化；" >&2
    echo "      如需纳入子模块管理，请改用服务端支持 partial clone 的地址。" >&2
  fi
  exit 0
fi

git config gc.auto 0

# 子模块模式下，确保工作区停在父仓库锁定的那个提交
if [ "$MODE" = submodule ] && [ "$(git rev-parse HEAD)" != "$SHA" ]; then
  echo ">>> 补齐锁定提交 $SHA（当前 HEAD 不是它）"
  if git fetch --depth 1 origin "$SHA" && git checkout --detach "$SHA"; then
    echo "    已切换到锁定提交"
  else
    die "无法获取锁定提交 $SHA"
  fi
fi

echo "    骨架大小: $(du -sh .git | cut -f1)"

# ---------- 第二步：按目录逐个拉取 ----------
OK=()
while IFS= read -r p; do
  [ -n "$p" ] && OK+=("$p")
done < <(git sparse-checkout list 2>/dev/null || true)

QUEUE=()
# 只取真正的目录（type=tree）；子模块是 gitlink（type=commit），交给递归步骤处理
while IFS= read -r d; do
  skip=0
  for p in ${OK[@]+"${OK[@]}"}; do
    [ "$d" = "$p" ] && { skip=1; break; }
  done
  [ $skip -eq 0 ] && QUEUE+=("$d")
done < <(git ls-tree -d HEAD | awk -F'\t' 'split($1,a," ") && a[2]=="tree" {print $2}')

echo ">>> [2/4] 按目录逐个拉取（待处理 ${#QUEUE[@]} 个顶层目录，失败会自动拆成子目录）"

SKIPPED=()
while [ ${#QUEUE[@]} -gt 0 ]; do
  d="${QUEUE[0]}"
  QUEUE=("${QUEUE[@]:1}")
  printf '    %-40s ' "$d"
  ok=0
  for try in 1 2 3; do
    if [ ${#OK[@]} -eq 0 ]; then
      timeout "$CHUNKED_TIMEOUT" git sparse-checkout set "$d" >/dev/null 2>&1 && { ok=1; break; }
    else
      timeout "$CHUNKED_TIMEOUT" git sparse-checkout set "${OK[@]}" "$d" >/dev/null 2>&1 && { ok=1; break; }
    fi
    printf '重试%s ' "$try"
  done
  if [ $ok -eq 1 ]; then
    OK+=("$d")
    echo "OK"
  else
    echo "失败 -> 拆分"
    if [ ${#OK[@]} -gt 0 ]; then
      git sparse-checkout set "${OK[@]}" >/dev/null 2>&1
    else
      git sparse-checkout set >/dev/null 2>&1
    fi
    subs=$(git ls-tree -d "HEAD:$d" 2>/dev/null | awk -F'\t' 'split($1,a," ") && a[2]=="tree" {print $2}')
    if [ -z "$subs" ]; then
      echo "        $d 没有子目录，跳过（拉取失败）"
      SKIPPED+=("$d")
    else
      while IFS= read -r s; do QUEUE+=("$d/$s"); done <<< "$subs"
    fi
  fi
done

# ---------- 第三步：还原完整工作区 ----------
echo ">>> [3/4] 恢复正常工作区"
git sparse-checkout disable || true

echo
echo "完成:"
echo "  提交  : $(git rev-parse HEAD)"
echo "  文件数: $(find . -type f -not -path './.git/*' | wc -l)"
echo "  体积  : $(du -sh . | cut -f1)"
echo "  状态  : $(git status --porcelain | wc -l) 处改动"

RC=0
if [ ${#SKIPPED[@]} -gt 0 ]; then
  RC=2
  echo
  echo "警告: 以下目录单次拉取失败、且已无子目录可拆，未拉取：" >&2
  for s in "${SKIPPED[@]}"; do echo "  - $s" >&2; done
  echo "可手动补拉: cd \"$(pwd)\" && git sparse-checkout add <上面某个目录>" >&2
fi

if [ "$MODE" = submodule ]; then
  echo
  echo "父仓库校验:"
  git -C "$ROOT" submodule init -- "$SUBPATH" >/dev/null 2>&1 || true
  git -C "$ROOT" submodule status -- "$SUBPATH" 2>/dev/null || true
  if [ "$(git rev-parse HEAD)" != "$SHA" ]; then
    echo "警告: HEAD 与父仓库锁定的提交不一致" >&2
    RC=2
  fi
fi

# ---------- 第四步：递归子模块 ----------
if [ "$RECURSE" = 1 ] && [ -f .gitmodules ]; then
  if [ "$DEPTH" -ge "$CHUNKED_MAX_DEPTH" ]; then
    echo "警告: 递归深度达到上限 $CHUNKED_MAX_DEPTH，停止下钻" >&2
    RC=2
  else
    echo
    echo ">>> [4/4] 递归处理子模块（第 $((DEPTH + 1)) 层）"
    while read -r key val; do
      case "$key" in
        submodule.*.path)
          echo
          echo "======== 子模块: $val ========"
          CHUNKED_DEPTH=$((DEPTH + 1)) "$SELF" --submodule "$val" -r $( [ "$NOFILTER" = 1 ] && echo --no-filter ) || {
            echo "子模块 $val 处理失败" >&2
            RC=2
          }
          ;;
      esac
    done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null)
  fi
fi

exit $RC
