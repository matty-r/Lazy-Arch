#!/bin/bash
# Version 2.2
# Arch Linux INSTALL SCRIPT

#Exit on error
#set -e
# Check what params this has been launched with.
# Unattended install is default.
# -d or --dry-run will *NOT* make any changes to your system - used to export the settings and
#   show what *WOULD* be done
# -p or --prompt will ask the user to input settings
while [[ "$#" -gt 0 ]];
do
  case $1 in
    -d|--dry-run)
        DRYRUN=1
    ;;
    -p|--prompt)
        PROMPT=1
    ;;
    *)
      echo "Unknown parameter passed: $1"
      exit 1
    ;;
  esac
  shift
done

# User Variables. Change these if Unattended install
declare -A USERVARIABLES
USERVARIABLES[USERNAME]="username"
USERVARIABLES[HOSTNAME]="computer-name"
USERVARIABLES[BUNDLES]="theme" ## Seperate by single space only (Example "gaming dev"). Found in softwareBundles.sh
USERVARIABLES[DESKTOP]="kde" #Sets the DE for RDP, and will run the package configurator - enabling the default WM for that DE. ## "kde" for Plasma, "xfce" for XFCE, "gnome" for Gnome, "none" for no DE
USERVARIABLES[KERNEL]="linux-zen" ## https://wiki.archlinux.org/index.php/Kernel: Stable="kernel", Hardened="linux-hardened", Longterm="linux-lts" Zen Kernel="linux-zen"
USERVARIABLES[BOOTPART]="/dev/vda1" ## Default Config: If $BOOTTYPE is BIOS, ROOTPART will be the same as BOOTPART (Only EFI needs the seperate partition)
USERVARIABLES[BOOTMODE]="CREATE" ## "CREATE" will destroy the *DISK* with a new label, "FORMAT" will only format the partition, "LEAVE" will do nothing
USERVARIABLES[ROOTPART]="/dev/vda2"
USERVARIABLES[ROOTMODE]="CREATE"

# Script Variables. DO NOT CHANGE THESE
SCRIPTPATH=$( readlink -m $( type -p $0 ))
SCRIPTROOT=${SCRIPTPATH%/*}
BOOTDEVICE=""
ROOTDEVICE=""
EFIPATH="/sys/firmware/efi/efivars"
BOOTTYPE=""
NETINT=""
CPUTYPE=""
GPUTYPE=""
INSTALLSTAGE=""

if [ ! -f $SCRIPTROOT/bundleConfigurators.sh ]; then
  curl -LO https://raw.githubusercontent.com/matty-r/arch-build/linux-zen/bundleConfigurators.sh
fi

if [ ! -f $SCRIPTROOT/softwareBundles.sh ]; then
  curl -LO https://raw.githubusercontent.com/matty-r/arch-build/linux-zen/softwareBundles.sh
fi

#Available Software Bundles
source $SCRIPTROOT/softwareBundles.sh
#Addtional configurations needed for selected bundles
source $SCRIPTROOT/bundleConfigurators.sh

#Prompt User for settings
promptSettings(){
  for variable in "${!USERVARIABLES[@]}"
  do
    read -p "$variable?:" answer
    USERVARIABLES[$variable]=$answer
  done
}

#Print out the settings
printSettings(){
  for variable in "${!USERVARIABLES[@]}"
  do
    echo "$variable = ${USERVARIABLES[$variable]}"
  done
}

#Export out the settings used/selected to installsettings.cfg
generateSettings(){
  # create settings file
    echo "" > "$SCRIPTROOT/installsettings.cfg"

  $(exportSettings "USERNAME" "${USERVARIABLES[USERNAME]}")
  $(exportSettings "HOSTNAME" "${USERVARIABLES[HOSTNAME]}")
  $(exportSettings "DESKTOP" "${USERVARIABLES[DESKTOP]}")
  $(exportSettings "ROOTPART" "${USERVARIABLES[ROOTPART]}")
  $(exportSettings "BOOTPART" "${USERVARIABLES[BOOTPART]}")
  $(exportSettings "BOOTMODE" "${USERVARIABLES[BOOTMODE]}")
  $(exportSettings "ROOTMODE" "${USERVARIABLES[ROOTMODE]}")

  #Grab the device chosen for the boot part
  BOOTDEVICE=$(echo "${USERVARIABLES[BOOTPART]}" | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  $(exportSettings "BOOTDEVICE" $BOOTDEVICE)
  #Grab the device chosen for the root part
  ROOTDEVICE=$(echo "${USERVARIABLES[ROOTPART]}" | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  $(exportSettings "ROOTDEVICE" $ROOTDEVICE)
  $(exportSettings "SCRIPTPATH" "$SCRIPTPATH")
  $(exportSettings "SCRIPTROOT" "$SCRIPTROOT")
  #Find the currently used interface - used to enable dhcpcd on that interface
  NETINT=$(ip link | grep "BROADCAST,MULTICAST,UP,LOWER_UP" | grep -oP '(?<=: ).*(?=: )')
  $(exportSettings "NETINT" $NETINT)
  $(exportSettings "KERNEL" "${USERVARIABLES[KERNEL]}")

  #Determine if it's an EFI install or not
  if [ -d "$EFIPATH" ]
  then
    BOOTTYPE="EFI"
    $(exportSettings "EFIPATH" $EFIPATH)
  else
    BOOTTYPE="BIOS"
  fi
  $(exportSettings "BOOTTYPE" $BOOTTYPE)

  
  #set comparison to ignore case temporarily
  shopt -s nocasematch

  #Detect platform type. Add the appropriate packages to install.
  if [[ $(hostnamectl | grep Chassis | cut -f2,2 -d':' | xargs) =~ 'vm' ]]; then
    VMTYPE=$(hostnamectl | grep Virtualization | cut -f2,2 -d':' | xargs)
    case $VMTYPE in
      'kvm' )
        PLATFORM="qemuGuest"
        ;;
      'vmware' )
        PLATFORM="esxiGuest"
        ;;
      'microsoft' )
        PLATFORM="hyperGuest"
        ;;
      'oracle' )
        PLATFORM="vboxGuest"
        ;;
    esac
    if [[ ! "${USERVARIABLES[BUNDLES]}" =~ "$PLATFORM" ]]; then
      USERVARIABLES[BUNDLES]+=" $PLATFORM"
    fi
  else
    PLATFORM="phys"
  fi

  #Add the selected desktop to the bundles - if it isn't there already
  if [[ ! "${USERVARIABLES[DESKTOP]}" =~ "${USERVARIABLES[BUNDLES]}" ]]; then
    echo "Adding ${USERVARIABLES[DESKTOP]} to bundles."
    USERVARIABLES[BUNDLES]+=" ${USERVARIABLES[DESKTOP]}"
  fi

  #Add the selected linux kernel to the bundles - if it isn't there already
  if [[ ! "${USERVARIABLES[KERNEL]}" =~ "${USERVARIABLES[BUNDLES]}" ]]; then
    echo "Adding ${USERVARIABLES[KERNEL]} to bundles."
    USERVARIABLES[BUNDLES]+=" ${USERVARIABLES[KERNEL]}"
  fi

  #Detect CPU type. Used for setting the microcode (ucode) on the boot loader
  CPUTYPE=$(lscpu | grep Vendor)
  if [[ $CPUTYPE =~ "AMD" ]]; then
    CPUTYPE="amd"
  elif [[ $CPUTYPE =~ "Intel" ]]; then
    CPUTYPE="intel"
  fi
  $(exportSettings "CPUTYPE" "$CPUTYPE")

  #Detect GPU type. Add the appropriate packages to install.
  GPUTYPE=$(lspci -vnn | grep VGA)
  if [[ $GPUTYPE =~ "nvidia" ]]; then
    GPUTYPE="nvidia"
    USERVARIABLES[BUNDLES]+=" $GPUTYPE"
  elif [[ $GPUTYPE =~ "amd" ]]; then
    GPUTYPE="amdgpu"
    USERVARIABLES[BUNDLES]+=" $GPUTYPE"
  elif [[ $GPUTYPE =~ "intelgpu" ]]; then
    GPUTYPE="intelgpu"
    USERVARIABLES[BUNDLES]+=" $GPUTYPE"
  else
    GPUTYPE="vm"
  fi
  $(exportSettings "GPUTYPE" "$GPUTYPE")
  $(exportSettings "BUNDLES" "${USERVARIABLES[BUNDLES]}")
  #reset comparisons
  shopt -u nocasematch
}

driver(){
  if [[ $PROMPT -eq 1 ]]; then
    promptSettings
  fi

  #Check if stage file exists
  if [[ -f "$SCRIPTROOT/stage.cfg" ]]; then
    INSTALLSTAGE=$(cat "$SCRIPTROOT/stage.cfg")
  else
    INSTALLSTAGE=""
  fi
  case $INSTALLSTAGE in
    "FIRST"|"")
      echo "FIRST INSTALL STAGE"
      firstInstallStage
      ;;
    "SECOND")
      echo "SECOND INSTALL STAGE"
      secondInstallStage
      ;;
    "THIRD")
      echo "THIRD INSTALL STAGE"
      thirdInstallStage
      ;;
    "FOURTH")
      echo "LAST INSTALL STAGE"
      finalInstallStage
      ;;
    esac
}

firstInstallStage(){
  echo "1. Generate Settings"
  generateSettings

  echo "2. System Clock"
  systemClock

  echo "3. Partition Disks"
  partDisks

  echo "4. Format Partitions"
  formatParts

  echo "5. Mount partitions"
  mountParts

  echo "6. Install Arch Linux base packages"
  installArchLinuxBase

  echo "7. Making the FSTAB"
  makeFstab

  echo "8. Setup chroot."
  chrootTime

  #Go into chroot. Should start at secondInstallStage
  if [[ $DRYRUN -eq 1 ]]; then
    secondInstallStage
    thirdInstallStage
  else
    arch-chroot /mnt ./home/${USERVARIABLES[USERNAME]}/arch-build.sh

    #Go into chroot as new user. Should start at thirdInstallStage as new user.
    arch-chroot /mnt su ${USERVARIABLES[USERNAME]} ./home/${USERVARIABLES[USERNAME]}/arch-build.sh
  fi

  runCommand umount -R /mnt

  #runCommand reboot
}

secondInstallStage(){
  echo "10. chroot: Import Settings"
  importSettings

  echo "11. chroot: Set root password"
  rootPassword

  echo "12. chroot: Create new user"
  createUser

  echo "13. chroot: Set Time"
  setTime

  echo "14. chroot: Generate locales"
  genLocales

  echo "15. chroot: Apply HostName"
  applyHostname

  echo "16. chroot: Add hosts file entries"
  addHosts

  echo "17. chroot: Generate mkinitcpio"
  genInit

  echo "18. chroot: Getting ready to boot"
  readyForBoot

  echo "19. chroot: Fix network on boot"
  enableNetworkBoot
}


thirdInstallStage(){
  importSettings

  echo "20. chroot: Install yay - AUR package manager"
  makeYay

  echo "21. chroot: Enable lib32"
  enableMultilibPackages

  echo "22. chroot: Install selected bundles"
  installSelectedBundles

  echo "23. chroot: Final step"
  finalInstallStage
}

installSelectedBundles(){
  IN=${USERVARIABLES[BUNDLES]}
  arrIN=(${IN// / })
  declare -a aggregatePackagesArr
  aggregatePackagesString=""

  for bundle in "${arrIN[@]}"
  do
      if [[ ${availableBundles[$bundle]} ]]; then
        arrayBundle=${availableBundles[$bundle]}[@]
        for package in "${!arrayBundle}"
        do
            aggregatePackagesArr+=("$package")
        done
      else
        echo "Chosen bundle $bundle is invalid. Skipping!"
      fi
  done

  aggregatePackagesString="${aggregatePackagesArr[@]}"
  runCommand yay -S --noconfirm $aggregatePackagesString

  configInstalledBundles

  #Only used if the install craps out or something
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write Fourth to /home/${USERVARIABLES[USERNAME]}/stage.cfg"
  else
    runCommand echo "FOURTH" > /home/${USERVARIABLES[USERNAME]}/stage.cfg
  fi
}

configInstalledBundles(){
  IN=${USERVARIABLES[BUNDLES]}
  arrIN=(${IN// / })
  
  for bundle in "${arrIN[@]}"
  do
    if [[ ${availableBundles[$bundle]} ]]; then
      bundleConfig="${availableBundles[$bundle]}-Config"
      #Test function exists
      declare -f $bundleConfig > /dev/null
      #Run the function if it exists
      if [[ $? -eq 0 ]]; then
        echo "Configuring ${availableBundles[$bundle]}.."
        runCommand $bundleConfig
      else
        echo "No additional config necessary for ${availableBundles[$bundle]}"
      fi
    fi
  done

  runCommand btrfsPackages-Config
}

finalInstallStage(){
  importSettings

  echo "23. Readying final boot"
  readyFinalBoot

  echo "Script done. You're good to go after you reboot"
  
  #We now leave the final chroot - then reboot.
}


exportSettings(){
  echo "Exporting $1=$2" 1>&2
  EXPORTPARAM="$1=$2"
  ## write all settings to a file on new root

  ## delete any previously matching settings
  sed -i "s/^$1=.*//" "$SCRIPTROOT/installsettings.cfg"

  echo -e "$EXPORTPARAM" >> "$SCRIPTROOT/installsettings.cfg"
}

importSettings(){
  echo "Importing Settings.."
  
  SCRIPTPATH=$(retrieveSettings 'SCRIPTPATH')
  SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')
  BOOTDEVICE=$(retrieveSettings 'BOOTDEVICE')
  ROOTDEVICE=$(retrieveSettings 'ROOTDEVICE')
  EFIPATH=$(retrieveSettings 'EFIPATH')
  BOOTTYPE=$(retrieveSettings 'BOOTTYPE')
  NETINT=$(retrieveSettings 'NETINT')
  CPUTYPE=$(retrieveSettings 'CPUTYPE')
  GPUTYPE=$(retrieveSettings 'GPUTYPE')
  INSTALLSTAGE=$(retrieveSettings 'INSTALLSTAGE')
  
  USERVARIABLES[BUNDLES]=$(retrieveSettings 'BUNDLES')
  USERVARIABLES[USERNAME]=$(retrieveSettings 'USERNAME')
  USERVARIABLES[HOSTNAME]=$(retrieveSettings 'HOSTNAME')
  USERVARIABLES[DESKTOP]=$(retrieveSettings 'DESKTOP')
  USERVARIABLES[BOOTPART]=$(retrieveSettings 'BOOTPART')
  USERVARIABLES[BOOTMODE]=$(retrieveSettings 'BOOTMODE')
  USERVARIABLES[ROOTPART]=$(retrieveSettings 'ROOTPART')
  USERVARIABLES[ROOTMODE]=$(retrieveSettings 'ROOTMODE')

  echo "Imported SCRIPTPATH=${SCRIPTPATH}"
  echo "Imported SCRIPTROOT=${SCRIPTROOT}"
  echo "Imported BOOTDEVICE=${BOOTDEVICE}"
  echo "Imported ROOTDEVICE=${ROOTDEVICE}"
  echo "Imported EFIPATH=${EFIPATH}"
  echo "Imported BOOTTYPE=${BOOTTYPE}"
  echo "Imported NETINT=${NETINT}"
  echo "Imported CPUTYPE=${CPUTYPE}"
  echo "Imported GPUTYPE=${GPUTYPE}"
  echo "Imported INSTALLSTAGE=${INSTALLSTAGE}"

  echo "Imported USERNAME=${USERVARIABLES[USERNAME]}"
  echo "Imported HOSTNAME=${USERVARIABLES[HOSTNAME]}"
  echo "Imported BUNDLES=${USERVARIABLES[BUNDLES]}"
  echo "Imported DESKTOP=${USERVARIABLES[DESKTOP]}"
  echo "Imported BOOTPART=${USERVARIABLES[BOOTPART]}"
  echo "Imported ROOTPART=${USERVARIABLES[ROOTPART]}"
  echo "Imported ROOTMODE=${USERVARIABLES[ROOTMODE]}"
  echo "Imported BOOTMODE=${USERVARIABLES[BOOTMODE]}"
}

#retrieveSettings 'SETTINGNAME'
retrieveSettings(){
  SETTINGSPATH="$SCRIPTROOT/installsettings.cfg"

  SETTINGNAME=$1
  SETTING=$(cat $SETTINGSPATH | grep $1 | cut -f2,2 -d'=')
  echo $SETTING
}

runCommand(){
  if [[ $DRYRUN -eq 1 ]]; then
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

###Update the system clock
systemClock(){
  runCommand timedatectl set-ntp true
}

### PARTITION DISKS
partDisks(){
  if [[ $BOOTTYPE = "EFI" ]]; then
    case ${USERVARIABLES[BOOTMODE]} in
      "LEAVE"|"FORMAT")
        echo "Leaving the boot partition..."
        ;;
      "CREATE")
        echo "EFI: Boot partition will be created. Whole disk will be destroyed!"
        DEVICE=$(echo ${USERVARIABLES[BOOTPART]} | sed 's/[0-9]//g')
        runCommand parted -s $DEVICE -- mklabel gpt mkpart primary fat32 0% 256MiB
        ;;
    esac
  fi

    case ${USERVARIABLES[ROOTMODE]} in
      "LEAVE"|"FORMAT")
        echo "Leaving the root partition..."
        ;;
      "CREATE")
        DEVICE=$(echo ${USERVARIABLES[ROOTPART]} | sed 's/[0-9]//g')
        if [[ $BOOTTYPE = "EFI" ]]; then
          #If the root device matches the boot device, don't setup device label
          if [ $BOOTDEVICE = $ROOTDEVICE ]; then
            runCommand parted -s $DEVICE -- mkpart primary ext4 256MiB 100%
          else
            echo "EFI: Root partition will be created. Whole disk will be destroyed!"
            runCommand parted -s $DEVICE -- mklabel gpt mkpart primary ext4 0% 100%
          fi
        else
          #BIOS system. If boot device matches root device, then make root part the same as boot part
          if [ $BOOTDEVICE = $ROOTDEVICE ]; then
            USERVARIABLES[ROOTPART]="${USERVARIABLES[BOOTPART]}"
          fi
          echo "BIOS: Root partition will be created. Whole disk will be destroyed!"
          runCommand parted -s $DEVICE -- mklabel msdos mkpart primary ext4 0% 100% set 1 boot on
        fi
        ;;
    esac
}

##FORMAT PARTITIONS

formatParts(){
  if [[ $BOOTTYPE = "EFI" ]]; then
    if [ ${USERVARIABLES[BOOTMODE]} = "CREATE" ] || [ ${USERVARIABLES[BOOTMODE]} = "FORMAT" ]; then
      runCommand mkfs.fat -F32 ${USERVARIABLES[BOOTPART]}
    fi

    if [ ${USERVARIABLES[ROOTMODE]} = "CREATE" ] || [ ${USERVARIABLES[ROOTMODE]} = "FORMAT" ]; then
      ##Adjust for encryption
      echo "Set up encryption for ${USERVARIABLES[ROOTPART]}"
      runCommand cryptsetup -q -y -v --cipher=aes-xts-plain64 --key-size 512 --hash=sha512 luksFormat ${USERVARIABLES[ROOTPART]}
      runCommand cryptsetup luksOpen ${USERVARIABLES[ROOTPART]} luks

      echo "Make btrfs on /dev/mapper/luks"
      runCommand mkfs.btrfs -L archRoot -f -f /dev/mapper/luks
      #runCommand mkfs.btrfs -L archRoot -f -f ${USERVARIABLES[ROOTPART]}
    fi
  else
    if [ ${USERVARIABLES[ROOTMODE]} = "CREATE" ] || [ ${USERVARIABLES[ROOTMODE]} = "FORMAT" ]; then
      runCommand mkfs.ext4 -f -f ${USERVARIABLES[ROOTPART]}
    fi
  fi
}


## Mount the file systems
mountParts(){
  if [[ $BOOTTYPE = "EFI" ]]; then
    #mount encrypted partition instead
    echo "Mount new luks partition..."
    runCommand mount -o compress=zstd /dev/mapper/luks /mnt

    #btrfs sub volumes
    runCommand cd /mnt
    runCommand btrfs subvolume create @
    runCommand btrfs subvolume create @home
    runCommand btrfs subvolume create @log
    runCommand btrfs subvolume create @srv
    runCommand btrfs subvolume create @pkg
    runCommand btrfs subvolume create @tmp
    runCommand cd ~
    runCommand umount /mnt
    runCommand mount -o compress=zstd,subvol=@ /dev/mapper/luks /mnt

    runCommand cd /mnt
    runCommand mkdir -p {home,srv,var/{log,cache/pacman/pkg},tmp}

    runCommand mount -o compress=zstd,subvol=@home /dev/mapper/luks home
    runCommand mount -o compress=zstd,subvol=@log /dev/mapper/luks var/log
    runCommand mount -o compress=zstd,subvol=@pkg /dev/mapper/luks var/cache/pacman/pkg
    runCommand mount -o compress=zstd,subvol=@srv /dev/mapper/luks srv
    runCommand mount -o compress=zstd,subvol=@tmp /dev/mapper/luks tmp

    runCommand mkdir /mnt/boot
    runCommand mount ${USERVARIABLES[BOOTPART]} /mnt/boot
  else
    runCommand mount ${USERVARIABLES[ROOTPART]} /mnt
  fi
}


setLocalMirrors(){
if [[ $DRYRUN -eq 1 ]]; then
  echo "Write Local Mirrors to /etc/pacman.d/mirrorlist"
else

LOCALJSON=$(curl -sX GET https://api.ipgeolocationapi.com/geolocate/$(curl -s icanhazip.com))
LOCALARRAY=($(echo $LOCALJSON | grep -Po '"alpha2":.*?[^\\]"' | tr ':' $'\n'))
COUNTRYCODE=$(echo ${LOCALARRAY[1]} | sed 's/"//g')
echo $COUNTRYCODE

runCommand curl -s "https://www.archlinux.org/mirrorlist/?country=${COUNTRYCODE}&protocol=https&use_mirror_status=on" | sed "s/#Server/Server/" > /etc/pacman.d/mirrorlist

}

### Install the base packages
installArchLinuxBase(){
  setLocalMirrors
  #Arch Linux Base

  archBasePackages=(base linux-firmware cryptsetup sudo device-mapper e2fsprogs ntfs-3g inetutils logrotate lvm2 man-db mdadm nano netctl pciutils perl procps-ng sysfsutils texinfo usbutils util-linux vi xfsprogs openssh git autoconf automake binutils bison fakeroot findutils flex gcc libtool m4 make pacman patch pkgconf which networkmanager btrfs-progs unzip wget snapper grub-btrfs snap-pac)

  aggregatePackagesString="${archBasePackages[@]}"
  runCommand pacstrap /mnt $aggregatePackagesString
}

### Generate an fstab file
makeFstab(){
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Generate fstab at /mnt/etc/fstab"
  else
    runCommand genfstab -U /mnt >> /mnt/etc/fstab
  fi
}

### Change root into the new system:
chrootTime(){
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write SECOND to $SCRIPTROOT/stage.cfg"
  else
    runCommand echo "SECOND" > $SCRIPTROOT/stage.cfg
  fi

  ##re-export the settings for the new stages (in chroot)
  $(exportSettings "SCRIPTPATH" "/home/${USERVARIABLES[USERNAME]}/arch-build.sh")
  $(exportSettings "SCRIPTROOT" "/home/${USERVARIABLES[USERNAME]}")

  runCommand mkdir /mnt/home/${USERVARIABLES[USERNAME]}
  runCommand cp $SCRIPTROOT/stage.cfg /mnt/home/${USERVARIABLES[USERNAME]}
  runCommand cp $SCRIPTPATH /mnt/home/${USERVARIABLES[USERNAME]}
  runCommand cp $SCRIPTROOT/softwareBundles.sh /mnt/home/${USERVARIABLES[USERNAME]}
  runCommand cp $SCRIPTROOT/bundleConfigurators.sh /mnt/home/${USERVARIABLES[USERNAME]}
  runCommand cp $SCRIPTROOT/installsettings.cfg /mnt/home/${USERVARIABLES[USERNAME]}
}

### Set the time zone
setTime(){
  runCommand ln -sf /usr/share/zoneinfo/Australia/Brisbane /etc/localtime
  runCommand hwclock --systohc
}

### Uncomment en_US.UTF-8 UTF-8 and other needed locales in /etc/locale.gen
genLocales(){
  runCommand sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
  runCommand sed -i "s/#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/" /etc/locale.gen
  runCommand locale-gen
  if [[ $DRYRUN -eq 1 ]]; then
    echo "LANG=en_AU.UTF-8 to /etc/locale.conf"
  else
    runCommand echo "LANG=en_AU.UTF-8" >> /etc/locale.conf
  fi
}

### Create the hostname file:
applyHostname(){
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write ${USERVARIABLES[HOSTNAME]} to /etc/hostname"
  else
    runCommand echo "${USERVARIABLES[HOSTNAME]}" >> /etc/hostname
  fi
}

### ADD HOSTS ENTRIES
addHosts(){
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write Localinfo to /etc/hosts"
  else
    runCommand echo "127.0.0.1     localhost" >> /etc/hosts
    runCommand echo "::1       localhost" >> /etc/hosts
    runCommand echo "127.0.1.1     ${USERVARIABLES[HOSTNAME]}.mydomain      ${USERVARIABLES[HOSTNAME]}" >> /etc/hosts
  fi
}

### GENERATE INITRAMFS
genInit(){
  sudo sed -i "s/^HOOKS=(base udev autodetect modconf block filesystems keyboard fsck).*/HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)/" /etc/mkinitcpio.conf
  runCommand mkinitcpio -P
}

### ROOT PASSWORD
rootPassword(){
  runCommand passwd
}

### INSTALL BOOTLOADER AND MICROCODE
readyForBoot(){
  DEVICE=$(echo ${USERVARIABLES[ROOTPART]} | sed 's/[0-9]//g')
  
  if [[ $BOOTTYPE = "EFI" ]]; then
    runCommand pacman -S --noconfirm grub $CPUTYPE'-ucode' os-prober efibootmgr
    runCommand grub-install --target=x86_64-efi --efi-directory=/boot  --bootloader-id=GRUB --recheck
    runCommand grub-mkconfig -o /boot/grub/grub.cfg
  else
    runCommand pacman -S --noconfirm grub $CPUTYPE'-ucode' os-prober
    runCommand grub-install --target=i386-pc $DEVICE
    runCommand grub-mkconfig -o /boot/grub/grub.cfg
  fi
}

enableNetworkBoot(){
  runCommand sudo systemctl enable dhcpcd@$NETINT.service
}

####### add a user add to wheel group
createUser(){
  runCommand useradd -m ${USERVARIABLES[USERNAME]}
  runCommand gpasswd -a ${USERVARIABLES[USERNAME]} wheel
  ####### change user password
  # su - ${USERVARIABLES[USERNAME]}
  runCommand echo "Set password for ${USERVARIABLES[USERNAME]}"
  runCommand passwd ${USERVARIABLES[USERNAME]}
  ###### enable wheel group for sudoers
  runCommand sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers
  ###### enable wheel group for sudoers - no password. TEMPORARY
  runCommand sed -i "s/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write THIRD to /home/${USERVARIABLES[USERNAME]}/stage.cfg"
  else
    runCommand echo "THIRD" > /home/${USERVARIABLES[USERNAME]}/stage.cfg
  fi

  ##SET OWNERSHIP OF SCRIPT FILES TO BE RUN AFTER REBOOT
  runCommand chown ${USERVARIABLES[USERNAME]}:${USERVARIABLES[USERNAME]} $SCRIPTROOT --recursive
}


enableMultilibPackages(){
  runCommand sudo sed -i '/#\[multilib\]/a Include = \/etc\/pacman.d\/mirrorlist' /etc/pacman.conf
  runCommand sudo sed -i "s/#\[multilib\]/[multilib]/" /etc/pacman.conf

  runCommand sudo pacman -Syyu
}

###### make yay
makeYay(){
  runCommand cd /home/${USERVARIABLES[USERNAME]}
  runCommand git clone https://aur.archlinux.org/yay-bin.git
  runCommand cd yay-bin
  runCommand makepkg -sri --noconfirm
  runCommand cd /home/${USERVARIABLES[USERNAME]}
}

############ enable network manager/disable dhcpcd
readyFinalBoot(){
  runCommand sudo systemctl disable dhcpcd@$NETINT.service
  runCommand sudo systemctl disable sshd
  runCommand sudo systemctl enable NetworkManager

  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write DONE to $SCRIPTROOT/stage.cfg"
  else
    runCommand echo "DONE" > $SCRIPTROOT/stage.cfg
  fi
  ###### Remove no password for sudoers
  runCommand sudo sed -i "s/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
}

#Start the script
driver