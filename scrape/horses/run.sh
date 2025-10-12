#!/bin/bash
# run.sh
# 引数: start end
# 例: ./run.sh 1 1500

START=$1
END=$2

source ~/netkeiba/venv/bin/activate

python ~/netkeiba/scraper_horses/scrape/horses/scraper.py --start $START --end $END
