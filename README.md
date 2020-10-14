# arch-build
# WARNING !
This script was intended for personal use only. Use at your own risk - and may result in a loss of data.

### About

Created because I install Arch Linux on almost all of my PCs (Desktops, Laptops, VMs), and I wanted a way to automate the boring stuff - such as partitioning, installing a DE with it's packages, and setting up a boot loader. With that said, this script may not work as intended for everybody, and it's still very much a work in progress.

### Contributing

There are a lot of Arch Linux install scripts out there, but if you think you'd like to help then I won't stop you - the more the merrier.

### Script Overview

Creates two partitions (if using UEFI), Boot and Root. Root will be encrypted, and use BTRFS for the file system. There will be various base packages installed (softwareBundles/archBasePackages), GRUB for the boot loader, plus modules needed for handling the encrypted Root partition. 

### Usage

* Clone/Download the GitHub repository onto your local drive at /root (/root is the expected directory the arch-build files will reside)
* Edit arch-build.sh with the appropriate bundles you need
* Set arch-build.sh to executable
* Execute arch-build.sh, if you wish to log the entire install, execute with script -c ./arch-build.sh arch-build.log 

```sh
curl https://raw.githubusercontent.com/matty-r/arch-build/master/arch-build.sh > arch-build.sh
chmod +x arch-build.sh
./arch-build.sh
```

Using git (Least Likely option - as git isn't installed on the arch iso)
```sh
git clone https://github.com/matty-r/arch-build
cd arch-build
mv * ~/
chmod +x arch-build.sh
./arch-build.sh
```
