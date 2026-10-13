#!/usr/bin/env python3
"""Build a reviewable paired capture report, preserving fixture limitations.

Requires Pillow. Converts Display P3 iOS attachments to sRGB before comparison.
Rejects blank screenshots; a successful screenshot test is not sufficient evidence.
"""
import argparse
import html
import io
import json
from pathlib import Path
from PIL import Image, ImageCms, ImageDraw, ImageStat


def normalized(path):
    image = Image.open(path)
    profile = image.info.get("icc_profile")
    image = image.convert("RGB")
    if profile:
        image = ImageCms.profileToProfile(image, ImageCms.ImageCmsProfile(io.BytesIO(profile)), ImageCms.createProfile("sRGB"), outputMode="RGB")
    if max(ImageStat.Stat(image).stddev) < 3:
        raise ValueError(f"Blank or uniform capture: {path}")
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--android", type=Path, required=True)
    parser.add_argument("--ios", type=Path, nargs="+", required=True, help="xcresult exported directories, newest first")
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    lookup = {}
    for directory in args.ios:
        for test in json.loads((directory / "manifest.json").read_text()):
            for attachment in test["attachments"]:
                name = attachment["suggestedHumanReadableName"].split("_0_")[0]
                lookup.setdefault(name, directory / attachment["exportedFileName"])
    args.output.mkdir(parents=True, exist_ok=True)
    records, sections = [], []
    for spec in json.loads(args.spec.read_text()):
        android_path = args.android / spec["android"]
        # The API35 ReminderSettingsShotTest baseline includes its 52dp inset.
        if spec["id"].startswith("reminders-") and spec.get("androidReference"):
            android_path = Path(spec["androidReference"])
        android, ios = normalized(android_path), normalized(lookup[spec["ios"]])
        images = []
        for platform, image in [("android", android), ("ios", ios)]:
            image = image.resize((390, round(image.height * 390 / image.width)), Image.Resampling.LANCZOS)
            filename = f"{spec['id']}-{platform}.png"
            image.save(args.output / filename)
            images.append(image)
        pair = Image.new("RGB", (780, max(image.height for image in images) + 28), "#e5e7eb")
        draw = ImageDraw.Draw(pair)
        for x, platform, image in [(0, "Android", images[0]), (390, "iOS", images[1])]:
            draw.text((x + 12, 8), platform, fill="#111827"); pair.paste(image, (x, 28))
        pair.save(args.output / f"{spec['id']}-pair.png")
        label = {"same": "동일 데이터·폭", "layout": "상태/기기 차이 있음", "different": "다른 데이터 — 구조 참고"}[spec["fixture"]]
        sections.append(f'<article><h2>{html.escape(spec["id"])} <small>{label}</small></h2><p>{html.escape(spec["note"])}</p><p><strong>검수: {html.escape(spec.get("review", "검토 전"))}</strong></p><div class="pair"><figure><figcaption>Android</figcaption><img src="{spec["id"]}-android.png"></figure><figure><figcaption>iOS</figcaption><img src="{spec["id"]}-ios.png"></figure></div></article>')
        if motion := spec.get("motion"):
            android_frames = sorted(args.android.glob(motion["androidPattern"]))
            ios_frames = [lookup[key] for key in sorted(lookup) if key.startswith(motion["iosPrefix"])]
            for platform, paths, duration in [("android", android_frames, motion["androidFrameMs"]), ("ios", ios_frames, motion["iosFrameMs"])]:
                if not paths:
                    raise ValueError(f"Missing motion frames for {platform}")
                frames = []
                for path in paths:
                    frame = normalized(path)
                    frame = frame.resize((390, round(frame.height * 390 / frame.width)), Image.Resampling.LANCZOS)
                    frames.append(frame)
                frames[0].save(args.output / f"{spec['id']}-{platform}.gif", save_all=True, append_images=frames[1:], duration=duration, loop=0)
            sections.append(f'<article><h2>낙하 연속 캡처</h2><p>각 플랫폼의 실제 연속 캡처입니다. 촬영 시작 시점과 간격이 달라 두 GIF의 재생 위상을 일치 판정에 사용하지 않습니다. 궤적 수치는 Android 원본 실행 결과 133개 프레임으로 별도 검사했습니다.</p><div class="pair"><figure><figcaption>Android · 170ms 간격</figcaption><img src="{spec["id"]}-android.gif"></figure><figure><figcaption>iOS · 120ms 대기 + 캡처 시간</figcaption><img src="{spec["id"]}-ios.gif"></figure></div></article>')
        records.append({**spec, "androidSource": str(android_path), "iosSource": str(lookup[spec["ios"]]), "verdict": spec.get("verdict", "human_review_required")})
    (args.output / "manifest.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
    page = '''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Android · iOS 화면 대조</title>
<style>body{font-family:system-ui,sans-serif;background:#f6f7f9;color:#17191e;max-width:1100px;margin:auto;padding:28px}h1{font-size:26px}h2{font-size:19px}p{line-height:1.6}small{font-size:12px;background:#fff0d8;padding:6px;border-radius:8px;margin-left:8px}article{padding:20px;background:white;border:1px solid #ddd;border-radius:16px;margin:24px 0}.pair{display:flex;gap:16px;overflow:auto}figure{margin:0;flex:0 0 390px}img{max-width:100%;display:block}figcaption{font-weight:bold;padding:8px 0}.notice{padding:16px;background:#fff0d8;border-radius:10px}</style>
<h1>Android · iOS 실제 캡처 대조 · 2026-10-13</h1><p class="notice">전 화면 완전 일치 판정이 아닙니다. 동일 조건의 캡처와 구조 참고 캡처를 구분했습니다. 이미지 색 공간은 sRGB로 통일했습니다. 문구·배치·모션 차이를 숨기는 자동 유사도 점수는 사용하지 않습니다.</p>
'''+"\n".join(sections)+"</html>"
    (args.output / "index.html").write_text(page)
    print(f"Wrote {len(records)} paired comparisons to {args.output / 'index.html'}")


if __name__ == "__main__":
    main()
