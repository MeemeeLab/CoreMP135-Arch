#!/bin/bash

set -e

if [ ! -b /dev/mmcblk0p5 ]; then
    exit 1
fi

echo fix | parted ---pretend-input-tty /dev/mmcblk0 print | true # Fix GPT if needed
echo yes | parted ---pretend-input-tty /dev/mmcblk0 resizepart 5 100%
resize2fs /dev/mmcblk0p5

systemctl disable resize-rootfs.service
