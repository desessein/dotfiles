#!/bin/bash

SERVICE_NAME="zen-limited.service"
MEMORY_HIGH_GB=3
WARNING_THRESHOLD=85

while true; do
    if ! systemctl --user is-active --quiet "$SERVICE_NAME"; then
        sleep 5
        continue
    fi

    MEMORY_CURRENT=$(systemctl --user show "$SERVICE_NAME" -p MemoryHigh --value)
    if [ "$MEMORY_CURRENT" = "[not set]" ]; then
        sleep 5
        continue
    fi

    CGROUP_PATH="/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/$SERVICE_NAME"
    
    if [ -f "$CGROUP_PATH/memory.current" ]; then
        CURRENT_BYTES=$(cat "$CGROUP_PATH/memory.current")
        CURRENT_GB=$(echo "scale=2; $CURRENT_BYTES / 1024 / 1024 / 1024" | bc)
        PERCENTAGE=$(echo "scale=0; ($CURRENT_GB / $MEMORY_HIGH_GB) * 100" | bc)

        if [ "$PERCENTAGE" -ge "$WARNING_THRESHOLD" ]; then
            notify-send -u critical "⚠️ Chrome Μνήμη" \
                "Χρήση: ${CURRENT_GB}GB / ${MEMORY_HIGH_GB}GB (${PERCENTAGE}%)\nΘα περιοριστεί σύντομα!"
        fi
    fi

    sleep 10
done
