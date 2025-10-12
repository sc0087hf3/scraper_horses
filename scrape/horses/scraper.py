import requests
from bs4 import BeautifulSoup
import re
import json
from pathlib import Path
import argparse
import logging
import sys
import random
import time

# User-Agentリスト
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
]

# ログ設定
logging.basicConfig(
    filename="scraper.log",
    filemode="a",
    format="%(asctime)s [%(levelname)s] %(message)s",
    level=logging.INFO
)
console = logging.StreamHandler(sys.stdout)
console.setLevel(logging.INFO)
formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
console.setFormatter(formatter)
logging.getLogger("").addHandler(console)


def parse_money(text):
    """金額を整数に変換"""
    text = text.replace(",", "").replace(" ", "")
    if text == "-" or text == "0万円":
        return 0
    match = re.match(r"(?:(\d+)億)?(?:(\d+)万)?円", text)
    if match:
        oku = int(match.group(1)) if match.group(1) else 0
        man = int(match.group(2)) if match.group(2) else 0
        return oku * 100000000 + man * 10000
    return 0


def scrape_horse_info(horse_id):
    """1頭分のデータ取得"""
    url = f"https://db.netkeiba.com/horse/{horse_id}/"
    headers = {"User-Agent": random.choice(USER_AGENTS)}

    res = requests.get(url, headers=headers, timeout=30)

    # --- レート制限対応 ---
    if res.status_code in (403, 429):
        logging.warning(f"⚠️ HTTP {res.status_code} for {horse_id}. Sleeping 10 minutes...")
        time.sleep(600)
        return scrape_horse_info(horse_id)

    res.encoding = res.apparent_encoding
    soup = BeautifulSoup(res.text, "html.parser")

    data = {"horse_id": horse_id}

    # 馬名
    name_tag = soup.select_one("div.horse_title h1")
    if name_tag:
        data["horse_name"] = name_tag.text.strip()

    # 性別・毛色・現役/引退
    txt01 = soup.select_one("div.horse_title p.txt_01")
    if txt01:
        txt = txt01.get_text(strip=True)
        sex_match = re.search(r"(牡|牝|せん)", txt)
        data["sex"] = sex_match.group(1) if sex_match else None
        color_match = re.search(r"(鹿毛|黒鹿毛|芦毛|栗毛|青鹿毛|白毛)", txt)
        data["color"] = color_match.group(1) if color_match else None
        data["retired"] = any(x in txt for x in ["抹消", "引退", "クラシック"])

    # プロフィールテーブル
    table = soup.select_one("table.db_prof_table")
    if table:
        for row in table.select("tr"):
            th = row.find("th").get_text(strip=True)
            td = row.find("td")
            if not td:
                continue
            text = td.get_text(strip=True)
            if th == "生年月日":
                data["birth"] = text
            elif th == "調教師":
                a = td.find("a")
                data["trainer_name"] = a.text.strip() if a else None
                trainer_id = re.search(r"/trainer/(\d+)/", a["href"]) if a else None
                data["trainer_id"] = trainer_id.group(1) if trainer_id else None
            elif th == "馬主":
                a = td.find("a")
                data["owner_name"] = a.text.strip() if a else None
                owner_id = re.search(r"/owner/(\d+)/", a["href"]) if a else None
                data["owner_id"] = owner_id.group(1) if owner_id else None
            elif th == "生産者":
                a = td.find("a")
                data["breeder_name"] = a.text.strip() if a else None
                breeder_id = re.search(r"/breeder/(\d+)/", a["href"]) if a else None
                data["breeder_id"] = breeder_id.group(1) if breeder_id else None
            elif "獲得賞金 (中央)" in th:
                data["earnings_central"] = parse_money(text)
            elif "獲得賞金 (地方)" in th:
                data["earnings_local"] = parse_money(text)
            elif "通算成績" in th:
                rec_match = re.search(r"(\d+-\d+-\d+-\d+)", text)
                data["record"] = rec_match.group(1) if rec_match else ""

    return data


def main(start, end):
    horse_ids_file = Path("horse_ids.txt")
    with open(horse_ids_file, "r", encoding="utf-8") as f:
        horse_ids = [line.strip() for line in f if line.strip()]

    horse_ids = horse_ids[start-1:end]

    results = []
    for idx, horse_id in enumerate(horse_ids, start=start):
        logging.info(f"[{idx}] Scraping {horse_id}")
        try:
            horse_data = scrape_horse_info(horse_id)
            results.append(horse_data)
            logging.info(f"[{idx}] ✅ Success: {horse_id}")
        except Exception as e:
            logging.error(f"[{idx}] ❌ Error scraping {horse_id}: {e}")
            backoff = random.uniform(120, 300)
            logging.warning(f"Backing off for {backoff:.1f} seconds...")
            time.sleep(backoff)
            continue

        # --- ランダム待機（安全運用） ---
        wait = random.uniform(30, 60)
        logging.info(f"Waiting {wait:.1f} seconds before next request...")
        time.sleep(wait)

    # --- JSON保存 ---
    output_dir = Path("json_output")
    output_dir.mkdir(exist_ok=True)
    output_file = output_dir / f"horses_{start}_{end}.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    logging.info(f"💾 Saved {len(results)} horses to {output_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", type=int, required=True)
    parser.add_argument("--end", type=int, required=True)
    args = parser.parse_args()
    main(args.start, args.end)
