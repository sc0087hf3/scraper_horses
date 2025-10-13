#!/usr/bin/bash
# run.sh
# 自動進捗管理 + cron対応版（ログイン不要で動作）
# 1回の実行で処理する件数を BATCH_SIZE で設定

set -e  # 途中でエラーが出たらスクリプトを停止
set -u  # 未定義変数を使うとエラーにする
set -o pipefail

# ========= 設定 =========
BATCH_SIZE=4000
BASE_DIR="/home/ubuntu/netkeiba/scraper_horses/scrape/horses"
PROGRESS_FILE="$BASE_DIR/last_id.txt"
VENV_PATH="/home/ubuntu/netkeiba/venv/bin/activate"
SCRAPER="/home/ubuntu/netkeiba/scraper_horses/scrape/horses/scraper.py"
LOG_FILE="$BASE_DIR/batch.log"
# ========================

echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Batch start ===" >> "$LOG_FILE"

# 進捗読み込み
if [ -f "$PROGRESS_FILE" ]; then
    START=$(cat "$PROGRESS_FILE")
    START=$((START + 1))
else
    START=20000
fi
END=$((START + BATCH_SIZE - 1))

echo "Processing horses from $START to $END ..." >> "$LOG_FILE"

# 仮想環境を有効化
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
