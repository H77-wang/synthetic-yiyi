set -u
TOKEN="$GH_TOKEN"
OWNER=H77-wang; REPO=synthetic-yiyi
API="https://api.github.com/repos/$OWNER/$REPO"
AUTH="Authorization: Bearer $TOKEN"; ACC="Accept: application/vnd.github+json"; CT="Content-Type: application/json"
BODY="D:/code/naina/synth-game/.ghbody.tmp"
MAP="D:/code/naina/synth-game/.ghmap.tmp"
CURL="curl -s --max-time 40 --connect-timeout 15 --retry 2 --retry-delay 2"
cd "D:/code/naina/synth-game"
# 一次拉全量文件树建 path->sha 映射（可靠，避免逐文件 GET 被代理打断）
echo "获取文件树..."
tree_json=$($CURL "$API/git/trees/main?recursive=1" -H "$AUTH" -H "$ACC")
echo "$tree_json" | python -c "import sys,json;d=json.load(sys.stdin);m={t['path']:t['sha'] for t in d.get('tree',[]) if t['type']=='blob'};json.dump(m,open(r'D:/code/naina/synth-game/.ghmap.tmp','w'));print('远程文件数:',len(m))"
tracked=$(git ls-files | grep -v '^preview.png$')
extra="sync_to_github.sh sync_to_github.bat"
all=$(printf '%s\n%s\n' "$tracked" "$extra" | grep -v '^$')
n=0; up=0
for f in $all; do
  [ -f "$f" ] || continue
  n=$((n+1))
  python -c "import base64,json,sys;data=open(sys.argv[1],'rb').read().replace(b'\r\n',b'\n');b=base64.b64encode(data).decode();open(r'D:/code/naina/synth-game/.ghbody.tmp','w',encoding='utf-8').write(json.dumps({'message':'sync '+sys.argv[1],'content':b},ensure_ascii=False))" "$f"
  remote_sha=$(python -c "import json,sys;m=json.load(open(r'D:/code/naina/synth-game/.ghmap.tmp'));print(m.get(sys.argv[1],''))" "$f" 2>/dev/null)
  if [ -n "$remote_sha" ]; then python -c "import json,sys;p=r'D:/code/naina/synth-game/.ghbody.tmp';b=json.load(open(p));b['sha']=sys.argv[1];json.dump(b,open(p,'w'),ensure_ascii=False)" "$remote_sha"; fi
  resp=$($CURL -X PUT "$API/contents/$f" -H "$AUTH" -H "$ACC" -H "$CT" -d "@$BODY")
  ok=$(printf '%s' "$resp" | python -c "import sys,json;d=json.load(sys.stdin);print('OK' if 'content' in d else 'ERR:'+d.get('message','?'))" 2>/dev/null)
  echo "[$n] $f -> $ok"
  [ "$ok" = "OK" ] && up=$((up+1)) || echo "  失败: $resp"
done
rm -f "$BODY" "$MAP"
echo "=== 全量同步完成，上传 $up 个文件 ==="
