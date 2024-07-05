#!/data/data/com.termux/files/usr/bin/bash

LOG_FILE=$HOME/log/"{{environment-name}}.log"

mkdir --parents "$(dirname "$LOG_FILE")"

exec &>> "$LOG_FILE"

echo "---- START DESKTOP: $(date) -----------------------" >> $LOG_FILE
tudo $HOME/bin/"{{environment-name}}.sh" desktop
echo "---- STOP DESKTOP: $(date) ------------------------" >> $LOG_FILE
