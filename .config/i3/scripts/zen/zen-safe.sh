#!/bin/bash

if ! systemctl --user is-active --quiet zen-limited.service; then
    systemctl --user start zen-limited.service
    
    if ! pgrep -f zen-limited-monitor.sh > /dev/null; then
        ~/.config/i3/scripts/zen/zen-limited-monitor.sh &
    fi
fi

sleep 1
