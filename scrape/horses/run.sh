#!/bin/bash
# ==========================================
# netkeiba スクレイピング自動運用スクリプト
# ==========================================

PYTHON="/usr/bin/python3"
SCRIPT="scraper.py"
LOG="batch.log"
HORSE_COUNT=150000
BATCH_SIZE=1000
WAIT_MIN=600   # バッチ間の最小待機（秒）=10分
WAIT_MAX=1200  # バッチ間の最大待機（秒）=20分
PROGRESS_FILE=".progress"

# --- 進捗をロード ---
if [ -f "$PROGRESS_FILE" ]; then
  START=$(cat "$PROGRESS_FILE")
else
  START=1
fi

echo "Start index: $START"

# --- メインループ ---
while [ $START -le $HORSE_COUNT ]; do
  END=$((START + BATCH_SIZE - 1))
  if [ $END -gt $HORSE_COUNT ]; then
    END=$HORSE_COUNT
  fi

  echo "============================" | tee -a $LOG
  echo "$(date '+%F %T')  Running batch: $START - $END" | tee -a $LOG

  $PYTHON $SCRIPT --start $START --end $END >> $LOG 2>&1
  RESULT=$?

  if [ $RESULT -eq 0 ]; then
    echo "$(date '+%F %T')  ✅ Batch completed: $START - $END" | tee -a $LOG
    START=$((END + 1))
    echo $START > $PROGRESS_FILE
  else
    echo "$(date '+%F %T')  ❌ Error detected, pausing 15 minutes..." | tee -a $LOG
    sleep 900
    continue
  fi

  WAIT=$((WAIT_MIN + RANDOM % (WAIT_MAX - WAIT_MIN)))
  echo "$(date '+%F %T')  Waiting $WAIT seconds before next batch..." | tee -a $LOG
  sleep $WAIT
done

echo "$(date '+%F %T')  🎉 All scraping finished!" | tee -a $LOG
