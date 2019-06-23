#!/bin/bash
# Version 1.0
# Arch Linux INSTALL SCRIPT

declare -A USERVARIABLES

# User Variables. Change these if Unattended install
USERVARIABLES[PLATFORM]="phys" #Platform currently unused ## "phys" for install on physical hardware. "vbox" for install as VirtualBox Guest. "qemu" for install as QEMU/ProxMox Guest.
USERVARIABLES[USERNAME]="matt"
USERVARIABLES[HOSTNAME]="arch-temp"
USERVARIABLES[BUNDLES]="rdp qemuGuest admin kde theme" ## Seperate by single space only (Example "gaming dev qemuGuest"). Found in softwareBundles.conf
USERVARIABLES[DESKTOP]="none" #DESKTOP currently unused. ## "kde" for Plasma, "xfce" for XFCE, "gnome" for Gnome, "none" for no DE
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

#Available Software Bundles
source $SCRIPTROOT/softwareBundles.conf
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

  $(exportSettings "PLATFORM" ${USERVARIABLES[PLATFORM]})
  $(exportSettings "USERNAME" ${USERVARIABLES[USERNAME]})
  $(exportSettings "HOSTNAME" ${USERVARIABLES[HOSTNAME]})
  $(exportSettings "DESKTOP" ${USERVARIABLES[DESKTOP]})
  $(exportSettings "BOOTPART" ${USERVARIABLES[BOOTPART]})
  $(exportSettings "BOOTMODE" ${USERVARIABLES[BOOTMODE]})
  $(exportSettings "ROOTPART" ${USERVARIABLES[ROOTPART]})
  $(exportSettings "ROOTMODE" ${USERVARIABLES[ROOTMODE]})

  #Grab the device chosen for the boot part
  BOOTDEVICE=$(echo ${USERVARIABLES[BOOTPART]} | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  $(exportSettings "BOOTDEVICE" $BOOTDEVICE)
  #Grab the device chosen for the root part
  ROOTDEVICE=$(echo ${USERVARIABLES[ROOTPART]} | cut -f3,3 -d'/' | sed 's/[0-9]//g')
  $(exportSettings "ROOTDEVICE" $ROOTDEVICE)
  $(exportSettings "SCRIPTPATH" "$SCRIPTPATH")
  $(exportSettings "SCRIPTROOT" "$SCRIPTROOT")
  #Find the currently used interface - used to enable dhcpcd on that interface
  NETINT=$(ip link | grep "BROADCAST,MULTICAST,UP,LOWER_UP" | grep -oP '(?<=: ).*(?=: )')
  $(exportSettings "NETINT" $NETINT)

  #Determine if it's an EFI install or not
  if [ -d "$EFIPATH" ]
  then
    BOOTTYPE="EFI"
  else
    BOOTTYPE="BIOS"
  fi
  $(exportSettings "BOOTTYPE" $BOOTTYPE)

  #set comparison to ignore case temporarily
  shopt -s nocasematch

  #Detect CPU type. Used for settings the microcode (ucode) on the boot loader
  CPUTYPE=$(lscpu | grep Vendor)
  if [[ $CPUTYPE =~ "AMD" ]]; then
    CPUTYPE="amd"
  else
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

  #reset comparisons
  shopt -u nocasematch
}


driver(){
  INSTALLSTAGE=$(cat "$SCRIPTROOT/stage.cfg")
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
  arch-chroot /mnt ./home/${USERVARIABLES[USERNAME]}/arch-build.sh

  #Go into chroot as new user. Should start at thirdInstallStage as new user.
  arch-chroot /mnt su ${USERVARIABLES[USERNAME]} ./home/${USERVARIABLES[USERNAME]}/arch-build.sh

  umount /mnt/boot
  umount /mnt

  reboot
}

secondInstallStage(){
  echo "10. chroot: Generate Settings"
  generateSettings

  echo "11. chroot: Set Time"
  setTime

  echo "12. chroot: Generate locales"
  genLocales

  echo "13. chroot: Apply HostName"
  applyHostname

  echo "14. chroot: Add hosts file entries"
  addHosts

  echo "15. chroot: Generate mkinitcpio"
  genInit

  echo "16. chroot: Set root password"
  rootPassword

  echo "17. chroot: Getting ready to boot"
  readyForBoot

  echo "18. chroot: Fix network on boot"
  enableNetworkBoot

  echo "19. chroot: Create new user"
  createUser

}


thirdInstallStage(){
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
  yay -S --noconfirm $aggregatePackagesString

  configInstalledBundles
  #Only used if the install craps out or something
  echo "FOURTH" > /home/${USERVARIABLES[USERNAME]}/stage.cfg
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
          $bundleConfig
        else
          echo "No additional config necessary for ${availableBundles[$bundle]}"
        fi
      fi
    done
}

finalInstallStage(){
  echo "23. Readying final boot"
  readyFinalBoot

  echo "Script done. You're good to go after reboot. Rebooting in 20 seconds..."
  sleep 20
  #We now leave the final chroot - then reboot.
}


exportSettings(){
  echo "Exporting $1=$2" 1>&2
  EXPORTPARAM="$1=$2"
  ## write all settings to a file on new root
  echo -e "$EXPORTPARAM" >> "$SCRIPTROOT/installsettings.cfg"
}

#retrieveSettings 'SETTINGNAME'
retrieveSettings(){
  SETTINGSPATH="$SCRIPTROOT/installsettings.cfg"

  SETTINGNAME=$1
  SETTING=$(cat $SETTINGSPATH | grep $1 | cut -f2,2 -d'=')
  echo $SETTING
}

###Update the system clock
systemClock(){
  timedatectl set-ntp true
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
        parted -s $DEVICE -- mklabel gpt \
              mkpart primary fat32 0% 256MiB
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
            parted -s $DEVICE -- mkpart primary ext4 256MiB 100%
          else
            echo "EFI: Root partition will be created. Whole disk will be destroyed!"
            parted -s $DEVICE -- mklabel gpt \
                  mkpart primary ext4 0% 100%
          fi
        else
          #BIOS system. If boot device matches root device, then make root part the same as boot part
          if [ $BOOTDEVICE = $ROOTDEVICE ]; then
            USERVARIABLES[ROOTPART]="${USERVARIABLES[BOOTPART]}"
          fi
          echo "BIOS: Root partition will be created. Whole disk will be destroyed!"
          parted -s $DEVICE -- mklabel msdos \
                mkpart primary ext4 0% 100% \
                set 1 boot on
        fi
        ;;
    esac
}

##FORMAT PARTITIONS

formatParts(){
  if [[ $BOOTTYPE = "EFI" ]]; then
    if [ ${USERVARIABLES[BOOTMODE]} = "CREATE" ] || [ ${USERVARIABLES[BOOTMODE]} = "FORMAT" ]; then
      mkfs.fat -F32 ${USERVARIABLES[BOOTPART]}
    fi

    if [ ${USERVARIABLES[ROOTMODE]} = "CREATE" ] || [ ${USERVARIABLES[ROOTMODE]} = "FORMAT" ]; then
      mkfs.ext4 -F -F ${USERVARIABLES[ROOTPART]}
    fi
  else
    if [ ${USERVARIABLES[ROOTMODE]} = "CREATE" ] || [ ${USERVARIABLES[ROOTMODE]} = "FORMAT" ]; then
      mkfs.ext4 -F -F ${USERVARIABLES[ROOTPART]}
    fi
  fi
}

## Mount the file systems
mountParts(){
  if [[ $BOOTTYPE = "EFI" ]]; then
    mount ${USERVARIABLES[ROOTPART]} /mnt
    mkdir /mnt/boot
    mount ${USERVARIABLES[BOOTPART]} /mnt/boot
  else
    mount ${USERVARIABLES[ROOTPART]} /mnt
  fi
}


setAussieMirrors(){
cat <<EOF > /etc/pacman.d/mirrorlist
##
## Arch Linux repository mirrorlist
## Filtered by mirror score from mirror status page
## Generated on 2019-05-02
##
## Australia
Server = http://archlinux.melbourneitmirror.net/\$repo/os/\$arch
## Australia
Server = http://archlinux.mirror.digitalpacific.com.au/\$repo/os/\$arch
## Australia
Server = http://ftp.iinet.net.au/pub/archlinux/\$repo/os/\$arch
## Australia
Server = http://ftp.swin.edu.au/archlinux/\$repo/os/\$arch
## Australia
Server = http://mirror.internode.on.net/pub/archlinux/\$repo/os/\$arch
EOF
}

### Install the base packages
installArchLinuxBase(){
  setAussieMirrors
  pacstrap /mnt base base-devel openssh git
}

### Generate an fstab file
makeFstab(){
  genfstab -U /mnt >> /mnt/etc/fstab
}

### Change root into the new system:
chrootTime(){
  echo "SECOND" > $SCRIPTROOT/stage.cfg

  mkdir /mnt/home/${USERVARIABLES[USERNAME]}
  cp $SCRIPTROOT/stage.cfg /mnt/home/${USERVARIABLES[USERNAME]}
  cp $SCRIPTPATH /mnt/home/${USERVARIABLES[USERNAME]}
  cp $SCRIPTROOT/softwareBundles.conf /mnt/home/${USERVARIABLES[USERNAME]}
  cp $SCRIPTROOT/bundleConfigurators.sh /mnt/home/${USERVARIABLES[USERNAME]}
  cp $SCRIPTROOT/installsettings.cfg /mnt/home/${USERVARIABLES[USERNAME]}
}

### Set the time zone
setTime(){
  ln -sf /usr/share/zoneinfo/Australia/Brisbane /etc/localtime
  hwclock --systohc
}

### Uncomment en_US.UTF-8 UTF-8 and other needed locales in /etc/locale.gen
genLocales(){
  sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
  sed -i "s/#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/" /etc/locale.gen
  locale-gen
  echo "LANG=en_AU.UTF-8" >> /etc/locale.conf
}

### Create the hostname file:
applyHostname(){
  echo "${USERVARIABLES[HOSTNAME]}" >> /etc/hostname
}

### ADD HOSTS ENTRIES
addHosts(){
  echo "127.0.0.1     localhost" >> /etc/hosts
  echo "::1       localhost" >> /etc/hosts
  echo "127.0.1.1     ${USERVARIABLES[HOSTNAME]}.mydomain      ${USERVARIABLES[HOSTNAME]}" >> /etc/hosts
}

### GENERATE INITRAMFS
genInit(){
  mkinitcpio -p linux
}

### ROOT PASSWORD
rootPassword(){
  passwd
}

### INSTALL BOOTLOADER AND MICROCODE
readyForBoot(){
  if [[ $BOOTTYPE = "EFI" ]]; then
    pacman -S --noconfirm refind-efi $CPUTYPE'-ucode'
    refind-install
    fixRefind
  else
    DEVICE=$(echo ${USERVARIABLES[ROOTPART]} | sed 's/[0-9]//g')
    pacman -S --noconfirm grub $CPUTYPE'-ucode'
    grub-install --target=i386-pc $DEVICE
    grub-mkconfig -o /boot/grub/grub.cfg
  fi
}

fixRefind(){
  ROOTUUID=$(blkid | grep ${USERVARIABLES[ROOTPART]} | grep -oP '(?<= UUID=").*(?=" TYPE)')

cat <<EOF > /boot/refind_linux.conf
"Boot with standard options"  "root=UUID=$ROOTUUID rw add_efi_memmap initrd=$CPUTYPE-ucode.img initrd=initramfs-linux.img"
"Boot using fallback initramfs"  "root=UUID=$ROOTUUID rw add_efi_memmap initrd=$CPUTYPE-ucode.img initrd=initramfs-linux-fallback.img"
"Boot to terminal"  "root=UUID=$ROOTUUID rw add_efi_memmap initrd=$CPUTYPE-ucode.img initrd=initramfs-linux.img systemd.unit=multi-user.target"
EOF
}

enableNetworkBoot(){
  sudo systemctl enable dhcpcd@$NETINT.service
}

####### add a user add to wheel group
createUser(){
  useradd -m ${USERVARIABLES[USERNAME]}
  gpasswd -a ${USERVARIABLES[USERNAME]} wheel
  ####### change user password
  # su - ${USERVARIABLES[USERNAME]}
  echo "Set password for ${USERVARIABLES[USERNAME]}"
  passwd ${USERVARIABLES[USERNAME]}
  ###### enable wheel group for sudoers
  sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers
  ###### enable wheel group for sudoers - no password. TEMPORARY
  sed -i "s/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
  echo "THIRD" > /home/${USERVARIABLES[USERNAME]}/stage.cfg

  ##SET OWNERSHIP OF SCRIPT FILES TO BE RUN AFTER REBOOT
  chown ${USERVARIABLES[USERNAME]}:${USERVARIABLES[USERNAME]} $SCRIPTROOT --recursive
}


enableMultilibPackages(){
  sudo sed -i '/#\[multilib\]/a Include = \/etc\/pacman.d\/mirrorlist' /etc/pacman.conf
  sudo sed -i "s/#\[multilib\]/[multilib]/" /etc/pacman.conf

  sudo pacman -Syyu
}

###### make yay
makeYay(){
  cd /home/${USERVARIABLES[USERNAME]}
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -sri --noconfirm
  cd /home/${USERVARIABLES[USERNAME]}
}

############ enable network manager/disable dhcpcd
readyFinalBoot(){
  sudo systemctl disable dhcpcd@$NETINT.service
  sudo systemctl disable sshd
  sudo systemctl enable NetworkManager
  echo "DONE" > $SCRIPTROOT/stage.cfg
  ###### Remove no password for sudoers
  sudo sed -i "s/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
}

#Start the script
driver
