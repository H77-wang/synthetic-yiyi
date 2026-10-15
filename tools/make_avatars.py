#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
把 D:/code/naina/照片1..11.jpg 做成游戏用的圆形头像精灵图（512x512 RGBA PNG）。

为什么不是抠底：这 11 张是实景自拍（窗帘/墙/床背景），区域生长抠底会啃得全是毛边，
圆形头像币反而干净、也好旋转。物理碰撞本身就是按 alpha 现算的，圆形刚好。

流程：
  1. EXIF 转正 → YCbCr + RGB 双规则肤色掩膜 → 取最大连通块当「脸」
  2. 以脸框为中心裁正方形（K 倍脸宽，可逐张微调），缩放回 512x512
  3. 盖直径 = 92% 画布的圆形蒙版（与 normalize_assets.py 的 FILL 一致），
     边缘 6px 烤一圈柔和暗边（浅色脸在奶油色棋盘上也分得清）
  4. 输出 assets/fruits/NN-photoN.png，并打印圆内平均色（填 FRUITS 的 pc1/pc2 用）

跑法： python tools/make_avatars.py
微调： ABS 是绝对裁切（编号 -> (cx, cy, side)，原图像素），优先于自动定位；
       CFG 是自动定位的微调（编号 -> (K, dx, dy)，K = 裁切边长 / 脸宽）。
       照片 8/9/10 是小图幅 + 暖色调，肤色掩膜会把整张图判成肤色，只能用 ABS。
"""
import os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

SRC_DIR = r"D:\code\naina"
OUT = os.path.join("assets", "fruits")
SIZE = 512
FILL = 0.92                       # 与 normalize_assets.py / optimize_sprites.py 一致
DISC_R = SIZE * FILL / 2.0        # 头像币半径（像素）
RIM = 6.0                         # 暗边宽度（像素）
RIM_DARK = 0.42                   # 暗边最深处的压暗系数
N = 11

# 绝对裁切（原图像素）：编号 -> (cx, cy, side)
ABS = {
    8:  (327, 390, 620),
    9:  (259, 630, 470),
    10: (259, 370, 500),
}

# 自动定位微调：编号 -> (K, dx, dy)
CFG = {}


def skin_mask(arr):
    """YCbCr 经典区间 + RGB 经验规则，取并集。"""
    r = arr[..., 0].astype(np.int16)
    g = arr[..., 1].astype(np.int16)
    b = arr[..., 2].astype(np.int16)
    cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b
    cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b
    m1 = (cb >= 77) & (cb <= 127) & (cr >= 133) & (cr <= 173)
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    m2 = (r > 95) & (g > 40) & (b > 20) & ((mx - mn) > 15) \
        & (np.abs(r - g) > 15) & (r > g) & (r > b)
    return m1 | m2


def largest_blob_bbox(mask):
    """最大连通块的包围盒 (x0, y0, x1, y1)（8 连通 BFS，输入为小图掩膜）。"""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    best = None
    ys, xs = np.nonzero(mask)
    for sy, sx in zip(ys, xs):
        if seen[sy, sx]:
            continue
        q = deque([(sy, sx)])
        seen[sy, sx] = True
        x0 = x1 = sx
        y0 = y1 = sy
        n = 0
        while q:
            y, x = q.popleft()
            n += 1
            if x < x0: x0 = x
            if x > x1: x1 = x
            if y < y0: y0 = y
            if y > y1: y1 = y
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
        if best is None or n > best[0]:
            best = (n, x0, y0, x1, y1)
    if best is None:
        return None
    return (best[1], best[2], best[3], best[4])


def auto_box(im):
    """肤色定位：最大肤色连通块的包围盒（原图像素）。"""
    W, H = im.size
    # 检测在 1/4 分辨率上做：够用，且 BFS 很快
    small = im.resize((max(1, W // 4), max(1, H // 4)), Image.BILINEAR)
    m = skin_mask(np.asarray(small.convert("RGB")))
    # 轻度闭运算（Max/Min 滤波 = 先膨胀后侵蚀），把眼镜/口罩造成的小缺口连起来
    mi = Image.fromarray((m * 255).astype(np.uint8))
    mi = mi.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    m = np.asarray(mi) > 127
    bb = largest_blob_bbox(m)
    if bb is None:
        return (W * 0.30, H * 0.18, W * 0.70, H * 0.62)
    return (bb[0] * 4, bb[1] * 4, bb[2] * 4, bb[3] * 4)


def make_one(idx):
    src = os.path.join(SRC_DIR, "照片%d.jpg" % idx)
    im = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
    W, H = im.size

    if idx in ABS:
        # 绝对裁切：直接指定中心和边长
        cx, cy, side = ABS[idx]
        tag = "ABS"
    else:
        x0, y0, x1, y1 = auto_box(im)
        fw, fh = x1 - x0, y1 - y0
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        K, dx, dy = CFG.get(idx, (1.75, 0, 0))
        side = int(round(max(fw, fh) * K))
        side = max(side, int(0.45 * min(W, H)))
        side = min(side, int(0.98 * min(W, H)))
        cx += dx
        cy += dy
        tag = "auto"
    side = int(round(side))
    side = max(1, min(side, int(0.995 * min(W, H))))
    # 保证裁剪框不越界
    cx = min(max(cx, side / 2.0), W - side / 2.0)
    cy = min(max(cy, side / 2.0), H - side / 2.0)
    box = (int(round(cx - side / 2.0)), int(round(cy - side / 2.0)),
           int(round(cx + side / 2.0)), int(round(cy + side / 2.0)))

    crop = im.crop(box).resize((SIZE, SIZE), Image.LANCZOS)

    # ---- 圆形蒙版（4 倍超采样抗锯齿） ----
    S = SIZE * 4
    mm = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mm).ellipse(
        [(S / 2 - DISC_R * 4), (S / 2 - DISC_R * 4),
         (S / 2 + DISC_R * 4), (S / 2 + DISC_R * 4)], fill=255)
    mm = mm.resize((SIZE, SIZE), Image.LANCZOS)

    out = crop.convert("RGBA")
    out.putalpha(mm)

    # ---- 烤暗边：离轮廓 6px 内逐渐压暗 ----
    a = np.asarray(out).astype(np.float32)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    d = np.sqrt((xx - SIZE / 2.0) ** 2 + (yy - SIZE / 2.0) ** 2) / SIZE  # 归一化半径
    edge = np.clip((FILL / 2.0 - d) / (RIM / SIZE), 0.0, 1.0)            # 边缘=0, 内部=1
    dark = RIM_DARK * (1.0 - edge)
    a[..., 0] *= (1.0 - dark)
    a[..., 1] *= (1.0 - dark)
    a[..., 2] *= (1.0 - dark)
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")

    dst = os.path.join(OUT, "%02d-photo%d.png" % (idx, idx))
    out.save(dst)

    # 圆内平均色（粒子/汁水颜色用）
    aa = np.asarray(out)
    inside = aa[..., 3] > 200
    mean = aa[..., :3][inside].mean(axis=0)

    def hx(v):
        return "#%02x%02x%02x" % tuple(int(round(c)) for c in v)

    print("照片%-2d  %-4s  side=%3d  平均色 %s / %s"
          % (idx, tag, side, hx(mean), hx(mean * 0.72)))
    return dst


def main():
    os.makedirs(OUT, exist_ok=True)
    for i in range(1, N + 1):
        make_one(i)
    print("\n完成：assets/fruits/NN-photoN.png")


if __name__ == "__main__":
    main()
