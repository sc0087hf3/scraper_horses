#!/usr/bin/bash
set -e
set -u
set -o pipefail

# ========= 設定 =========
BATCH_SIZE=2000
DATA_DIR="/home/ubuntu/netkeiba/data/horses"
LOG_DIR="/home/ubuntu/netkeiba/data/logs"
SCRAPER="/home/ubuntu/netkeiba/scraper_horses/scrape/horses/scraper.py"
VENV_PATH="/home/ubuntu/netkeiba/venv/bin/activate"

PROGRESS_FILE="$DATA_DIR/last_id.txt"
LOG_FILE="$LOG_DIR/batch.log"
# ========================

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Batch start ===" >> "$LOG_FILE"

if [ -f "$PROGRESS_FILE" ]; then
    START=$(cat "$PROGRESS_FILE")
    START=$((START + 1))
else
    START=1
fi
END=$((START + BATCH_SIZE - 1))

echo "Processing horses from $START to $END ..." >> "$LOG_FILE"

# 仮想環境
if [ -f "$VENV_PATH" ]; then
    source "$VENV_PATH"
else
    echo "Error: Virtual environment not found at $VENV_PATH" >> "$LOG_FILE"
    exit 1
fi

# スクレイピング実行
if python "$SCRAPER" --start "$START" --end "$END" >> "$LOG_FILE" 2>&1; then
    echo "$END" > "$PROGRESS_FILE"
    echo "Progress saved: last ID = $END" >> "$LOG_FILE"
else
    echo "Error occurred during scraping. Progress not saved." >> "$LOG_FILE"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Batch end ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
