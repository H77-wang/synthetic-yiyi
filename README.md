# 合成一一

![preview](preview.png)

纯 **HTML + CSS + JavaScript** 的静态网页小游戏，零依赖、零构建、离线可玩。
物理引擎（PBD 位置约束求解）是自己写的，没有引入 matter.js 等任何第三方库。

玩法是经典的「合成大西瓜」类：**照片 1 → 11 共 11 级合成链**，两个相同的撞在一起
合成更大一级，越合越大；两个「一一 11」撞在一起会一起炸掉，换 500 分和一枚复活币。

> 本项目基于开源项目 [ai-ziming/synthetic-big-baby](https://gitee.com/ai-ziming/synthetic-big-baby)
> （合成大奶娃）换皮开发：游戏逻辑、物理引擎沿用其代码，贴图全部替换为本人照片，
> 排行榜改用独立前缀。感谢原作者的开源工作。

## 🎮 在线玩

Gitee Pages 部署后打开对应网址即可（手机浏览器打开就能玩，也可以「添加到主屏幕」当 App 用）。

本地双击 `index.html` 即可（`file://` 协议下也能跑，排行榜同样可用）。也可以起个静态服务：

```
python -m http.server 8080
# 打开 http://localhost:8080
```

## 玩法

- **鼠标**：移动瞄准，点击即投放。
- **触屏**：按住拖动瞄准，**松手才投放**——手指不会挡住落点，也方便微调。
- 棋盘右上角的「下一个」是**下一颗**；当前这颗画在准星位置（虚线顶端）。投放后的冷却期间当前这颗会**变淡**显示（还不能投），这样两个位置始终各是各的，不会看混。
- 两个**同级别**的碰到一起就合成为高一级，并获得分数。
- 顶上虚线是**警戒线**：有水果**卡在线的上方并且基本停住**、累计超过 1.5 秒即判负（被弹起来飞过线的不算）。
- 结束后**自动上榜**（进不了前 20 就不提交）；没填昵称就记作「默认用户」，昵称随时可以在排行榜弹窗里改。
- `←` `→` 微调位置，`Space` / `Enter` 投放，`R` 重新开始。（结束后空格/回车不再重开，避免手快连开新局。）

合成链（11 级，顺序 = 照片 1 → 11）：

```
一一1 → 一一2 → 一一3 → … → 一一10 → 一一11
```

合成得分采用三角数：1 / 3 / 6 / 10 / 15 / 21 / 28 / 36 / 45 / 55，
两只一一11撞在一起会一起炸掉，额外加 500 分、并送一枚复活币
（后期唯一的泄压阀：两只一一11占满棋盘，不炸掉就没法继续玩）。

### 失败规则

**唯一判负条件：有水果卡在警戒线上方、且基本停住，累计超过 1.5 秒。**

```
const DANGER_Y   = 142;   // 警戒线
const OVER_LIMIT = 1.5;   // 累计秒数
const REST_SPEED = 140;   // 低于这个速度才算"卡住了"（px/s）
```

- 好几只在线上方轮流卡：**不会**加在一起，`overTime` 是每只各自的变量；
- 被弹飞路过线上方：**不算**，速度 ≥ 140px/s 时不计时还在倒扣；
- 贴着线上下反复弹：线下方按 2 倍速扣，只有线上方时间占比 > 2/3 才攒得起来；
- 不限步数、不限数量、不限时间，除了这条没有别的失败条件。

想调：`DANGER_Y` 调高低、`OVER_LIMIT` 调容忍时间、`REST_SPEED` 调"多慢才算卡住"。
`node physics.test.js` 的第 7 组会把这三条规则各验一遍。

## 运行

线上直接开 Pages 网址；本地双击 `index.html` 即可（`file://` 协议下也能跑）。
也可以起个静态服务：

```
python -m http.server 8080
# 打开 http://localhost:8080
```

部署：仓库打开 **Settings → Pages → Source = Deploy from a branch → main / (root)** 即可，
根目录已经放了 `.nojekyll`，静态文件原样发布。

## 文件

| 文件 | 说明 |
| --- | --- |
| `index.html` | 页面结构：棋盘、结束遮罩、侧边面板、排行榜弹窗 |
| `style.css` | 全部样式：玻璃拟态面板、响应式布局、结束动画、排行榜 |
| `game.js` | 游戏逻辑 + 自研物理 + Canvas 渲染 + WebAudio 音效 |
| `leaderboard.min.js` | 在线排行榜（TinyWebDB 接口 + 弹窗渲染），前缀 `yiyi_` |
| `assets/fruits/` | 头像贴图：`NN-photoN.webp` 是页面实际加载的，`NN-photoN.png` 是 512×512 源图；另有 `parts.js` 碰撞形状、`blur.js` 极模糊占位图 |
| `assets/sfx/` `assets/bgm.mp3` | 音效与背景音乐 |
| `tools/make_avatars.py` | **照片 → 头像精灵**：肤色/眼睛定位、裁切、圆形蒙版、烤暗边 |
| `tools/build_parts.py` | 按贴图轮廓生成碰撞形状，产出 `assets/fruits/parts.js` |
| `tools/optimize_sprites.py` | 把源图压成 WebP 并裁到每级实际需要的尺寸 |
| `tools/make_blur.py` | 生成极模糊占位图 `blur.js`（11 张缩略图拼成一条、内联成 data URL） |
| `tools/normalize_assets.py` | （原项目保留）异形贴图的抠底/归一化管线，圆形头像用不到 |
| `physics.test.js` | 物理手感自检脚本（`node physics.test.js`） |
| `gameplay.test.js` | 复活 / 清场玩法自检（`node gameplay.test.js`） |
| `preview.png` | 预览图（11 级合成链） |

## 素材是怎么来的（换照片）

11 张贴图全部由 `tools/make_avatars.py` 从 `D:\code\naina\照片1..11.jpg` 生成：

1. **EXIF 转正** → YCbCr + RGB 双规则肤色掩膜 → 取最大连通块当「脸」；
2. 以脸框为中心裁正方形（默认 1.75 倍脸宽），缩放回 512×512；
3. 盖直径 = 92% 画布的**圆形蒙版**（头像币），边缘 6px 烤一圈柔和暗边——
   浅色脸在奶油色棋盘上也分得清，运行时零开销；
4. 输出 `assets/fruits/NN-photoN.png`，同时打印圆内平均色（已填进 `game.js` 的 `pc1/pc2` 粒子色）。

为什么是圆形而不是抠底：这 11 张是实景自拍（窗帘/墙/床背景），区域生长抠底会啃得全是毛边，
圆形头像币反而干净、也好旋转。物理碰撞本来就是按 alpha 现算的，圆形刚好——
`tools/build_parts.py` 会识别"近似正圆"的贴图并直接用一个内接圆（IoU 0.996）。

照片 8/9/10 是小图幅 + 暖色调，肤色掩膜会把整张图判成肤色，自动定位不可用，
在 `make_avatars.py` 顶部的 `ABS` 里按原图像素指定了裁切框（编号 -> (cx, cy, side)）。

换一批照片重新生成：

```
python tools/make_avatars.py        # 照片 -> assets/fruits/NN-photoN.png
python tools/build_parts.py         # -> parts.js（碰撞形状）
python tools/optimize_sprites.py    # -> *.webp（压缩 + 按显示尺寸裁剪）
python tools/make_blur.py           # -> blur.js（占位图）
```

注意：`game.js` 的 `FRUITS` 表里每级的 `r`（半径 17 → 124）、`name`、`file`、`pc1/pc2`
要和贴图对应上；`ASSET_FILL = 0.92` 必须与生成脚本的 `FILL` 一致。

## 排行榜

用的是 **TinyWebDB**（`https://tinywebdb.appinventor.space/api`）——一个给 App Inventor 用的
极简 key-value 云存储，靠 POST 表单调用，跨域头是 `Access-Control-Allow-Origin: *`，
所以纯静态页也能直接读写，不需要自建后端。

- 本游戏使用独立前缀 **`yiyi_`**，和原项目的榜互不干扰（改 `leaderboard.min.js` 里的 `PREFIX` 即可另开一个榜）；
- 榜单内容 = **最近 20 次提交**，是一条滚动的时间窗，不是历史最高分榜；
- 结算流程：游戏结束自动提交（没填昵称记「默认用户」）→ 重新读榜显示窗口内排名；
- 只写自己那条记录，没有任何 `delete`；网络不通只是排行榜打不开，游戏照常玩；
- 0 分不上榜；分数 > 99999999 不收；昵称限长 12 字、全部用 `textContent` 渲染防 XSS。

## 实现要点

- **物理**：位置约束求解（PBD）。每帧 3 个子步 × 6 次迭代，每个水果带一组碰撞子圆
  （本作是单圆，半径 = r），速度由位置差反推——堆叠稳定、不抖动。
- **Q 弹回弹**：位置约束会把法向速度吃掉，所以在每个子步末尾额外做一次弹性冲量，
  把法向相对速度直接改写成 `e × 碰撞前速度`（球球 `e=0.38`、墙 `e=0.45`）。
  撞速低于 `REST_THRESHOLD` 时完全不弹，静止堆叠零抖动。
- **合成判定**：接触容差 0.8px，同级别贴身即合；只在每个子步的第 0 次迭代判定一次。
- **渲染**：整体按 devicePixelRatio 缩放（封顶 2×）。有贴图就画贴图
  （`box = 2r / 0.92`，保证**视觉大小 = 物理直径**），没贴图就画程序化头像币；
  贴图跟着 `b.angle` 一起旋转，撞击时的挤压变形同样作用于贴图。
- **素材加载**：等 `img.decode()` 完成才交给 `drawImage`；每张图失败会退避重试 3 次。
- **回退三级**：贴图 → `blur.js` 极模糊同形状缩略图 → 程序化圆形水果，别让玩家看到"图挂了"。
- **音效**：WebAudio 振荡器实时合成 + mp3 音效/BGM，可一键静音并记忆设置。
- **存档**：最高分与静音状态存 `localStorage`。
- **调试**：控制台可用 `__SUIKA__.state`、`__SUIKA__.reset()`、`__SUIKA__.drop()`、`__SUIKA__.FRUITS`、`__SUIKA__.render()`。

### 物理自检

```
node physics.test.js
```

用桩件模拟 DOM/Canvas，在 Node 里跑真物理（连 `parts.js` 一起加载，用的是真实碰撞形状），
覆盖：自由落体回弹高度、球对球弹起、12 秒堆叠稳定性、静止后形状之间无穿透、
自动投放 60 次不走样、触屏/鼠标两套输入、结束后按键行为、判负规则三连验。

### 手机端适配

- 布局：窄屏（≤860px）侧面板提到棋盘上方，横屏压成顶部信息条；
- 棋盘尺寸 `height: min(可用高度, 96vw × 700/420)`，任何机型不出滚动条；
- 视口高度用 `100dvh`（带 `100vh` 回退），`padding` 叠 `env(safe-area-inset-*)`；
- 触控：棋盘 `touch-action:none`，`body` 上 `touch-action:manipulation` + `overscroll-behavior:none`；
- 合成时按等级给 `navigator.vibrate` 轻震（跟随静音开关）；
- canvas 内部分辨率按 `devicePixelRatio` 缩放但封顶 2×。

### 参数速查（`game.js` 顶部）

| 常量 | 默认值 | 作用 |
| --- | --- | --- |
| `GRAVITY` | 2600 | 重力加速度 px/s² |
| `SUBSTEPS` / `ITER` | 3 / 6 | 物理精度，调高更稳更费 CPU |
| `RESTITUTION` | 0.38 | 球与球之间的弹性 |
| `WALL_RESTITUTION` | 0.45 | 撞墙 / 撞地面的弹性 |
| `REST_THRESHOLD` | 55 | 撞速低于此值不反弹（保堆叠稳定） |
| `FRICTION` | 0.955 | 接触切向摩擦 |
| `SQUASH_MAX` / `SQUASH_DECAY` | 0.30 / 9 | 撞击挤压的最大变形与回弹速度 |
| `DROP_MS` | 360 | 两次投放的最小间隔 |
| `OVER_LIMIT` / `DANGER_Y` / `REST_SPEED` | 1.5 / 142 / 140 | 越线判负三件套 |
| `MERGE_PAD` | 0.8 | 合成接触容差 |
| `AVOID_REPEAT` | true | 「下一个」避开与当前相同的等级 |
| `SPAWN_WEIGHTS` | [.28 .24 .20 .16 .12] | 前 5 级的掉落权重 |
| `ASSET_FILL` | 0.92 | 贴图主体占画布比例，**必须与生成脚本的 `FILL` 一致** |
| `FRUITS` | 11 项 | 每级的半径 / 贴图路径 / 兜底配色，改这里即可换皮 |

## 许可

仅供学习娱乐使用。游戏逻辑与物理引擎来自上述开源项目，照片素材为私人所有，请勿外传。
