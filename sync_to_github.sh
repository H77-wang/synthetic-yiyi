#!/usr/bin/env bash
# ============================================================
#  同步本地改动到 GitHub（无需 WorkBuddy）
#  原理：用 GitHub Contents API（curl 通道，绕开本机 git 对 github 的 TLS 限制）
#  只上传“与 GitHub 上内容不同”的文件，其余跳过，速度快。
#
#  用法（任选其一）：
#   1) 把令牌写进本目录的 .ghtoken 文件（一行），然后直接运行：
#        bash sync_to_github.sh
#   2) 或临时用环境变量：
#        GH_TOKEN=你的github令牌 bash sync_to_github.sh
#
#  令牌生成：GitHub -> 右上角头像 -> Settings -> Developer settings
#           -> Personal access tokens -> Fine-grained token
#           权限勾：Administration / Contents / Pages 均为 Read and write
#
#  运行后 GitHub Pages 会在约 1 分钟内自动重新部署。
# ============================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
WIN_DIR="$(cygpath -m "$DIR" 2>/dev/null || echo "$DIR")"

TOKEN="${GH_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -f .ghtoken ]; then TOKEN="$(head -n1 .ghtoken | tr -d '\r')"; fi
if [ -z "$TOKEN" ]; then
  echo "未找到令牌。请执行以下之一："
  echo "  GH_TOKEN=你的令牌 bash $0"
  echo "  或把令牌写入本目录 .ghtoken 文件（一行）"
  exit 1
fi

OWNER=H77-wang
REPO=synthetic-yiyi
API="https://api.github.com/repos/$OWNER/$REPO"
AUTH="Authorization: Bearer $TOKEN"
ACC="Accept: application/vnd.github+json"
CT="Content-Type: application/json"
BODY="$WIN_DIR/.ghbody.tmp"
MAP="$WIN_DIR/.ghmap.tmp"
# 加超时与重试，避免代理偶发断连导致脚本挂起
CURL="curl -s --max-time 60 --connect-timeout 15 --retry 2 --retry-delay 2"

# 拉一次完整文件树（含 sha），本地建 path->sha 映射
echo "获取 GitHub 文件清单..."
tree_json=$($CURL "$API/git/trees/main?recursive=1" -H "$AUTH" -H "$ACC")
echo "$tree_json" | python -c "
import sys,json
d=json.load(sys.stdin)
m={t['path']:t['sha'] for t in d.get('tree',[]) if t['type']=='blob'}
json.dump(m, open(r'$MAP','w'))
print('远程文件数:', len(m))
"

# 要同步的文件：已跟踪的（排除 preview.png）+ 未跟踪的游戏文件（排除临时/令牌）
# 注意：换行符统一按 LF 计算 sha，避免 Windows/Unix 差异导致误判为改动
tracked=$(git ls-files | grep -v '^preview.png$')
untracked=$(git ls-files --others --exclude-standard \
  | grep -vE '^\.ghtoken$|^\.ghbody\.tmp$|^\.ghmap\.tmp$' \
  | grep -vE '\.(tmp|log|map)$' \
  | grep -vE '\.genie$')
all=$(printf '%s\n%s\n' "$tracked" "$untracked" | grep -v '^$')

if [ -z "$all" ]; then echo "没有需要同步的文件。"; rm -f "$MAP"; exit 0; fi

n=0; up=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  n=$((n+1))
  # 本地 blob sha（CRLF 归一化为 LF，与 GitHub 存储一致）
  local_sha=$(python -c "
import hashlib,sys
data=open(sys.argv[1],'rb').read().replace(b'\r\n',b'\n')
h=hashlib.sha1(); h.update(('blob %d\0'%len(data)).encode()); h.update(data)
print(h.hexdigest())
" "$f")
  remote_sha=$(python -c "import json,sys;m=json.load(open(r'$MAP'));print(m.get(sys.argv[1],''))" "$f" 2>/dev/null)
  if [ "$local_sha" = "$remote_sha" ]; then
    echo "[$n] $f -> 相同，跳过"; continue
  fi
  # 上传体也按 LF 归一化，保证 GitHub 上始终是 LF
  python -c "
import base64,json,sys
data=open(sys.argv[1],'rb').read().replace(b'\r\n',b'\n')
b=base64.b64encode(data).decode()
open(r'$BODY','w',encoding='utf-8').write(json.dumps({'message':'update '+sys.argv[1],'content':b},ensure_ascii=False))
" "$f"
  if [ -n "$remote_sha" ]; then
    python -c "import json,sys;p=r'$BODY';b=json.load(open(p));b['sha']=sys.argv[1];json.dump(b,open(p,'w'),ensure_ascii=False)" "$remote_sha"
  fi
  resp=$($CURL -X PUT "$API/contents/$f" -H "$AUTH" -H "$ACC" -H "$CT" -d "@$BODY")
  ok=$(printf '%s' "$resp" | python -c "import sys,json;d=json.load(sys.stdin);print('OK' if 'content' in d else 'ERR:'+d.get('message','?'))" 2>/dev/null)
  echo "[$n] $f -> $ok"
  if [ "$ok" != "OK" ]; then echo "  上传失败：$resp"; rm -f "$BODY" "$MAP"; exit 1; fi
  up=$((up+1))
done <<< "$all"

rm -f "$BODY" "$MAP"
echo "=== 完成：本次上传 $up 个文件。GitHub Pages 约 1 分钟内自动重新部署 ==="
echo "在线地址：https://h77-wang.github.io/synthetic-yiyi/"
