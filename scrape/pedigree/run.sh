#!/usr/bin/bash
# run.sh - Node.js版（pedigree）
set -euo pipefail

# ========= 設定 =========
BATCH_SIZE=2000
BASE_DIR="/home/ubuntu/netkeiba/scraper_horses/scrape/pedigree"
PROGRESS_FILE="$BASE_DIR/last_id.txt"
SCRIPT="$BASE_DIR/scrape_pedigree.js"
LOG_FILE="$BASE_DIR/batch.log"
# ========================

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Batch start ===" >> "$LOG_FILE"

# 進捗を読み込み
if [ -f "$PROGRESS_FILE" ]; then
    START=$(cat "$PROGRESS_FILE")
    START=$((START + 1))
else
    START=1
fi
END=$((START + BATCH_SIZE - 1))

echo "Processing horses from $START to $END ..." >> "$LOG_FILE"

# Node.jsで実行
if node "$SCRIPT" "$START" "$END" >> "$LOG_FILE" 2>&1; then
    echo "$END" > "$PROGRESS_FILE"
    echo "Progress saved: last ID = $END" >> "$LOG_FILE"
else
    echo "Error occurred during scraping. Progress not saved." >> "$LOG_FILE"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Batch end ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
