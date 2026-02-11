#!/bin/bash
cd "$(dirname "$0")"
python3 main.py &
PID=$!
sleep 1
open "http://localhost:8000"
wait $PID
