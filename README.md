# CoreMP135-Arch

## About
An effort to use Arch Linux on M5Stack CoreMP135.  
Also latest kernel. cuz Arch.

## Support

### Hardware
|    Name    | M5Stack ROM | CoreMP135-Arch | Description |
|     :-:    |     :-:     |       :-:      |-------------|
|ILI9342C    |⚠️1           |✅️              |TFT (Display) panel
|FT6336U     |✅️           |✅️              |Touch panel
|BM8563      |✅️           |✅️              |RTC
|RTL8211F    |⚠️2           |⚠️2              |Ethernet
|LT8618SXB   |⚠️3           |⚠️4              |HDMI transmitter
|AXP2101     |⚠️5           |✅️              |Power management unit
|NS4168      |⚠️6           |✅️              |Audio amplifier
|SIT1051T/3  |✅️           |✅️              |CAN TX/RX

### Software
|    Name    | M5Stack ROM | CoreMP135-Arch | Description |
|     :-:    |     :-:     |       :-:      |-------------|
|Linux Kernel|6.1.82 (LTS) |6.9.0           |Linux Kernel version
|Init system |BusyBox      |systemd (BusyBox initramfs)|Init process launched by kernel
|FS resize   |❌️           |✅️7             |Automatic file system resize for first boot

⚠️1 Only FB driver supported  
⚠️2 100Mbps downshift occurs  
⚠️3 User-space driver and 1280x1024 only (no EDID handling)  
⚠️4 1280x1024 only (no EDID handling)  
⚠️5 Missing poweroff driver  
⚠️6 Wrong audio playback speed  
✅️7 OOB image only

Any other components not listed here, should work on both M5Stack and CoreMP135-Arch ROM.

## OOB images
OOB image contains sudo and mkinitcpio already set-up with configurations found in `configs`.  
This image contains pacman key already generated and this can be severe security risk. it is recommended to regenerate keys.

When you first boot up OOB image, the GUID Partition Table (GPT) will be checked for size difference and fixed if needed.  
rootfs will be resized to match size of SD card. However, this might not be best fit for your purpose. In this case, I recommend to use non-OOB images.

## Installation
Run build.sh or download prebuilt binary from GitHub.

Prebuilt binaries can be found here:  
https://github.com/MeemeeLab/CoreMP135-Arch/releases

Burn sdcard.img or sdcard_oob.img to your SD card.

You should extend rootfs size to match your SD card.  
I recommend using parted/gparted to extend. (Don't use fdisk or it will erase `legacy_boot`, read below)

Don't erase `legacy_boot` flag on rootfs, or your M5Stack will be unable to boot.

## Non-OOB image setup
Insert your SD card to your CoreMP135, and you are good to go.  
First boot may take long.

After boot, login as root user.  
Username is `root`, password is `root`.
For user account, `alarm` with password `alarm` exists, but it's better idea to setup sudo first.


I strongly recommend upgrading your system.  
To do that, update PGP keys first:
```
# pacman-key --init
# pacman-key --populate
```

Populating keys may take long on slow systems like CoreMP135.  
Sit back, relax and wait for CoreMP135.

After that, run upgrade:
```
# pacman -Syu
```
This, takes more time than pacman-key. It's time to go touch some grass.  
But be careful, pacman asks for dbus alternatives and confirmation.

Optionally, you can install sudo like any other Arch systems:
```
# pacman -S sudo
# vi /etc/sudoers
```

### Early loading display drivers
You may want to load display drivers early, so that you can see logs while booting.  
To do this, modify your mkinitcpio.conf:
```
# vi /etc/mkinitcpio.conf
```

Add `ili9342c` and `lt8618sxb` to `MODULES`

ili9342c provides frame buffer driver, while lt8168sxb provides HDMI-TX driver.

Don't forget to update your initramfs:
```
# mkinitcpio -P
```

### Enabling getty on serial console
The image is configured to use USART2 for earlycon.  
After kernel loads console driver, linux will automatically switch to dummy device, and then TFT display.

You may want to start Getty on serial ports.  
For list of serial ports, see below:
```
/dev/ttySTM0: USART2 (Internal)
/dev/ttySTM1: USART6 (Grove Port C)
/dev/ttySTM2: USART3 (RS485)
```

Enable systemd service for getty:
```
# systemctl enable getty@ttyX
```
where X is serial device you want to enable.

