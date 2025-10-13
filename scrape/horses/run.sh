#!/bin/bash
# run.sh
# 自動進捗管理版
# 1回の実行で何件ずつ処理するかを BATCH_SIZE で設定

BATCH_SIZE=1500
PROGRESS_FILE=~/netkeiba/scraper_horses/scrape/horses/last_id.txt

# 前回の進捗を取得
if [ -f "$PROGRESS_FILE" ]; then
    START=$(cat "$PROGRESS_FILE")
    START=$((START + 1))  # 次のIDから開始
else
    START=20000  # 初回は20000行目から開始
fi

END=$((START + BATCH_SIZE - 1))

echo "Scraping horses from $START to $END ..."

# 仮想環境有効化
source ~/netkeiba/venv/bin/activate

# スクレイピング実行
python ~/netkeiba/scraper_horses/scrape/horses/scraper.py --start $START --end $END

# 進捗を保存
echo $END > "$PROGRESS_FILE"
echo "Progress saved: last ID = $END"
