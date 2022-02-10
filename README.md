## Purpose

Created because i'm lazy. I use Arch Linux regularly and on almost all of my PCs (Desktops, Laptops, VMs), and I wanted a way to automate the boring stuff - such as partitioning, installing a DE with it's packages, and setting up a boot loader. 

The overall intent was to have a script that can be launched from within the official Arch Linux ISO, and require minimal input from the user during the installation process. Throughout the installation process it attempts to detect your CPU, GPU, virtualization platform (If relevant), and geo-graphic location (For localization settings), so that it's all integrated and ready to go once the installation is complete.

### Contributing

There are a lot of Arch Linux install scripts out there, but if you think you'd like to help then I won't stop you - the more the merrier :). Please create a fork, and create a pull-request from that fork for any fixes/improvements.

**See Lazy-Arch wiki entry for more details. **

### Testing platforms

* Qemu/KVM
* Desktop: AMD CPU & Nvidia GPU
* Laptop: Intel CPU & Nvidia (Prime) GPU

### Script Overview

Creates two partitions (if using UEFI), Boot and Root. Root will be encrypted, and use BTRFS for the file system. Snapshots will also be enabled. There will be various base packages installed, GRUB for the boot loader, plus modules needed for handling the encrypted Root partition and Snapshots from the GRUB menu.

### Features
* Choice of Kernel
* BTRFS/F2FS on root
* Encrypted root partition
* Auto-Snapshots through Snapper
* Snapshots integrated into GRUB
* GRUB Boot Manager
* Software Bundles with scripted configuration (Such as Steam, Lutris, RDP etc..)
* Sane defaults for KDE (other choices of DE available)
* Auto-detect GPU (including if nVidia Prime is required)
* Auto-detect platform (i.e VM - vmware/hyper-v/qemu/virtualbox)

### Usage - Full Build


1. Clone/Download the GitHub repository onto your local drive at /root (/root is the expected directory the arch-build files will reside)

* Download:
    ```sh
    curl -LO https://raw.githubusercontent.com/matty-r/lazy-arch/master/arch-build.sh
    ```
    
2. Set arch-build.sh to executable
    ```sh
    chmod +x arch-build.sh
    ```

3. Execute the script to download the extra files
    ```sh
    ./arch-build.sh
    ```

4. Edit settings.conf with the appropriate bundles/settings you need
    ### READ SETTINGS.CONF CAREFULLY
    ```sh
    USERNAME=matty-r
    HOSTNAME=matts-desktop
    BUNDLES=kdeTheme gaming
    DESKTOP=kde
    KERNEL=linux-zen
    BOOTPART=/dev/vda1
    BOOTMODE=CREATE
    ROOTPART=/dev/vda2
    ROOTMODE=CREATE
    ROOTFILE=EXT4
    ENCRYPT=NO
    ```

5. In the first instance, execute with ./arch-build.sh -d (This will display all of the commands the script intends to run, without making any system changes)
    ```sh
    ./arch-build.sh -d
    ```

7. If you're happy, Execute ./arch-build.sh.
    ```sh
    ./arch-build.sh
    ```

#### Usage - Bundle Configurators
Running this is only required after installation as they are ran automatically as part of the full build.

```sh
* ./bundleConfigurators.sh {bundle name} to run the associated configurator, example ./bundleConfigurators.sh kde
```
#### Usage - Software Bundles
Running this is only required after installation as they are ran automatically as part of the full build.

```sh
* ./softwareBundles.sh {bundle name} to run the associated bundle installer. Will ask if you want to run the associated configurator if available.
```
