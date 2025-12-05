#!/usr/bin/bash
set -e
set -u
set -o pipefail

# ========= 設定 =========
BATCH_SIZE=2000

SCRIPT="/home/ubuntu/netkeiba/scraper_horses/scrape/pedigree/scrape_pedigree.js"
PROGRESS_FILE="/home/ubuntu/netkeiba/data/pedigree/last_index.txt"

LOG_DIR="/home/ubuntu/netkeiba/data/pedigree/logs"
LOG_FILE="$LOG_DIR/batch.log"

HORSE_ID_FILE="/home/ubuntu/netkeiba/scraper_horses/scrape/pedigree/horse_ids.txt"

# Node の PATH（重要）
export PATH="$HOME/.nvm/versions/node/v18.19.0/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# ========================

mkdir -p "$LOG_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Pedigree Batch start ===" >> "$LOG_FILE"

# horse_ids.txt の行数
TOTAL=$(wc -l < "$HORSE_ID_FILE")

# 前回の進捗位置
if [ -f "$PROGRESS_FILE" ]; then
    START=$(cat "$PROGRESS_FILE")
    START=$((START + 1))
else
    START=0
fi

END=$((START + BATCH_SIZE - 1))
if [ "$END" -ge "$TOTAL" ]; then
    END=$((TOTAL - 1))
fi

echo "Processing pedigree from line $START to $END ..." >> "$LOG_FILE"

# Playwright 実行
if node "$SCRIPT" "$START" "$END" >> "$LOG_FILE" 2>&1; then
    NEXT=$((END))

    # 終端まで来たらループ
    if [ "$NEXT" -ge "$TOTAL" ]; then
        echo 0 > "$PROGRESS_FILE"
        echo "Progress reset to 0" >> "$LOG_FILE"
    else
        echo "$NEXT" > "$PROGRESS_FILE"
        echo "Progress saved: last index = $NEXT" >> "$LOG_FILE"
    fi
else
    echo "Error occurred during Playwright scraping. Progress not saved." >> "$LOG_FILE"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Pedigree Batch end ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
