#!/bin/bash

if ! systemctl --user is-active --quiet chrome-limited.service; then
    systemctl --user start chrome-limited.service
    
    if ! pgrep -f chrome-limited-monitor.sh > /dev/null; then
        ~/.config/i3/scripts/chrome/chrome-limited-monitor.sh &
    fi
fi

sleep 1
