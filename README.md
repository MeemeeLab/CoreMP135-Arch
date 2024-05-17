# CoreMP135-Arch

## About
An effort to use Arch Linux on M5Stack CoreMP135.  
Also latest kernel. cuz Arch.

## Installation
Run build.sh or download prebuilt binary from GitHub.

Prebuilt binaries can be found here:  
https://github.com/MeemeeLab/CoreMP135-Arch/releases

Burn sdcard.img to your SD card.

Because default rootfs has a size of 2GiB, it's good idea to extend rootfs to match your SD card.  
Use any partition modification utilities to extend.

Don't erase `legacy_boot` flag on rootfs, or your M5Stack will be unable to boot.

## Setup
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

Add `fb_ili9342c` and `axp2101_m5stack_bl` to `MODULES`

fb_ili9342c provides frame buffer driver, while axp2101_m5stack_bl provides backlight driver.

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

