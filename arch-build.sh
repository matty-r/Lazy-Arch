#!/bin/bash
# Version 2.12
# Arch Linux INSTALL SCRIPT

GITURL="https://raw.githubusercontent.com/matty-r/lazy-arch/"
GITBRANCH="master"

# Detect if we have been piped
# if so, close it and reopen to standard input

if [ ! -t 0 ]; then
  tmpcfg=$(cat -)
  exec 0<&-       # close current pipeline input
  exec 0</dev/tty # reopen input fd with standard input
fi

#Exit on error
#set -e
# Check what params this has been launched with.
# Unattended install is default.
# -d or --dry-run will *NOT* make any changes to your system - used to export the settings and
#   show what *WOULD* be done
# -p or --prompt will ask the user to input settings
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -d | --dry-run)
    DRYRUN=1
    ;;
  -p | --prompt)
    PROMPT=1
    ;;
  --rootpwd)
    ROOTPWD="$2"
    shift
    ;;
  --userpwd)
    USERPWD="$2"
    shift
    ;;
  *)
    echo "Unknown parameter passed: $1"
    exit 1
    ;;
  esac
  shift
done

# User Variables array
declare -A USERVARIABLES

# Script Variables. DO NOT CHANGE THESE
SCRIPTPATH=$(readlink -m "$(type -p "$0")")
SCRIPTROOT=${SCRIPTPATH%/*}
BOOTDEVICE=""
ROOTDEVICE=""
EFIPATH="/sys/firmware/efi/efivars"
BOOTTYPE=""
NETINT=""
CPUTYPE=""
GPUBUNDLE=""
INSTALLSTAGE=""

checkISOVersion() {
  echo "Checking ISO versions..."
  LATESTVERSION=$(curl -s https://gitlab.archlinux.org/api/v4/projects/10190/releases/ | grep -Po '(?<=version ).*?(?=\))' | head -n 1)
  LOCALVERSION=$(cat /run/archiso/airootfs/version)

  if [[ $(echo "${LATESTVERSION}" | wc -w) != 0 ]] && [[ $(echo "${LOCALVERSION}" | wc -w) != 0 ]]; then

    shopt -s nocasematch
    ANSWER="Y"
    if [[ "$LOCALVERSION" != "$LATESTVERSION" ]]; then
      echo "$(tput setaf 0)$(tput setab 3) **You're not running the latest Arch Linux ISO which could cause problems.** $(tput sgr0)"
      CONTINUEPLZ=""
      read -p "$(tput setaf 0)$(tput setab 3)Continue anyway?$(tput sgr0)($DEFAULTANSWER/n): " CONTINUEPLZ
      CONTINUEPLZ=${CONTINUEPLZ:-$ANSWER}
      if [[ "$CONTINUEPLZ" != "$ANSWER" ]]; then
        exit 1
      else
        echo "$(tput setaf 7)$(tput setab 1)Alrighty then, you're the boss! Let's do this..$(tput sgr0)"
      fi
    else
      echo "Running the latest version ($LOCALVERSION) of the Arch Linux ISO."
    fi

    shopt -u nocasematch

  else
    echo "$(tput setaf 0)$(tput setab 3)Unable to verify your ISO with the latest release.. continuing anyway..$(tput sgr0)"
  fi
}

checkISOVersion

if [ ! -f "$SCRIPTROOT"/bundleConfigurators.sh ]; then
  echo "$(tput setaf 2)$(tput setab 0) **Downloading bundleConfigurators.sh..** $(tput sgr0)"
  curl -s -SLO "$GITURL""$GITBRANCH"/bundleConfigurators.sh
fi

if [ ! -f "$SCRIPTROOT"/softwareBundles.sh ]; then
  echo "$(tput setaf 2)$(tput setab 0) **Downloading softwareBundles.sh..** $(tput sgr0)"
  curl -s -SLO "$GITURL""$GITBRANCH"/softwareBundles.sh
fi

if [ ! -f "$SCRIPTROOT"/softwareBundles.sh ] || [ ! -f "$SCRIPTROOT"/softwareBundles.sh ]; then
  echo "$(tput setaf 7)$(tput setab 1) **Check internet access. Unable to download required files.** $(tput sgr0)"
  exit 1
fi

if [ ! -f "$SCRIPTROOT"/settings.conf ]; then
  echo "$(tput setaf 2)$(tput setab 0) **Downloading settings.conf..** $(tput sgr0)"
  curl -s -SLO "$GITURL""$GITBRANCH"/settings.conf
  echo "$(tput setaf 0)$(tput setab 3) **First run? Be sure to change the settings.conf file before continuing.** $(tput sgr0)"
  exit 1
fi

#Prompt User for settings
promptSettings() {
  for variable in "${!USERVARIABLES[@]}"; do
    read -rp "$variable?:" answer
    USERVARIABLES[$variable]=$answer
  done
}

# Print out the settings
printSettings() {
  for variable in "${!USERVARIABLES[@]}"; do
    echo "$variable = ${USERVARIABLES[$variable]}"
  done
}

getDevice() {
  USERPARTITION=$1
  DEVICES=($(lsblk -no PATH))
  for DEVICE in "${DEVICES[@]}"; do
    if [ ${#DEVICE} -lt ${#USERPARTITION} ]; then
      if [[ "$USERPARTITION" =~ $DEVICE ]]; then
        echo "$DEVICE"
      fi
    fi
  done
}

importSettings() {
  IMPORTTYPE=$1
  echo "Importing ${IMPORTTYPE} Settings.."

  if [[ $IMPORTTYPE == "all" ]] || [[ $IMPORTTYPE == "script" ]]; then
    SCRIPTPATH=$(retrieveSettings 'SCRIPTPATH')
    SCRIPTROOT=$(retrieveSettings 'SCRIPTROOT')
    BOOTDEVICE=$(retrieveSettings 'BOOTDEVICE')
    ROOTDEVICE=$(retrieveSettings 'ROOTDEVICE')
    EFIPATH=$(retrieveSettings 'EFIPATH')
    BOOTTYPE=$(retrieveSettings 'BOOTTYPE')
    NETINT=$(retrieveSettings 'NETINT')
    CPUTYPE=$(retrieveSettings 'CPUTYPE')
    GPUBUNDLE=$(retrieveSettings 'GPUBUNDLE')
    INSTALLSTAGE=$(retrieveSettings 'INSTALLSTAGE')
  fi

  if [[ $IMPORTTYPE == "all" ]] || [[ $IMPORTTYPE == "user" ]]; then
    USERVARIABLES[BUNDLES]=$(retrieveSettings 'BUNDLES')
    USERVARIABLES[USERNAME]=$(retrieveSettings 'USERNAME')
    USERVARIABLES[HOSTNAME]=$(retrieveSettings 'HOSTNAME')
    USERVARIABLES[DESKTOP]=$(retrieveSettings 'DESKTOP')
    USERVARIABLES[KERNEL]=$(retrieveSettings 'KERNEL')
    USERVARIABLES[BOOTPART]=$(retrieveSettings 'BOOTPART')
    USERVARIABLES[BOOTMODE]=$(retrieveSettings 'BOOTMODE')
    USERVARIABLES[ROOTFILE]=$(retrieveSettings 'ROOTFILE')
    USERVARIABLES[ENCRYPT]=$(retrieveSettings 'ENCRYPT')
    USERVARIABLES[ROOTPART]=$(retrieveSettings 'ROOTPART')
    USERVARIABLES[ROOTMODE]=$(retrieveSettings 'ROOTMODE')
  fi
}

# Export out the settings used/selected to settings.conf
generateSettings() {

  exportSettings "USERNAME" "${USERVARIABLES[USERNAME]}"
  exportSettings "HOSTNAME" "${USERVARIABLES[HOSTNAME]}"
  exportSettings "DESKTOP" "${USERVARIABLES[DESKTOP]}"
  exportSettings "ROOTPART" "${USERVARIABLES[ROOTPART]}"
  exportSettings "BOOTPART" "${USERVARIABLES[BOOTPART]}"
  exportSettings "BOOTMODE" "${USERVARIABLES[BOOTMODE]}"
  exportSettings "ROOTMODE" "${USERVARIABLES[ROOTMODE]}"
  exportSettings "ROOTFILE" "${USERVARIABLES[ROOTFILE]}"
  exportSettings "ENCRYPT" "${USERVARIABLES[ENCRYPT]}"

  # Grab the device chosen for the boot part
  BOOTDEVICE=$(getDevice "${USERVARIABLES[BOOTPART]}")
  exportSettings "BOOTDEVICE" "$BOOTDEVICE"
  # Grab the device chosen for the root part
  ROOTDEVICE=$(getDevice "${USERVARIABLES[ROOTPART]}")
  exportSettings "ROOTDEVICE" "$ROOTDEVICE"
  exportSettings "SCRIPTPATH" "$SCRIPTPATH"
  exportSettings "SCRIPTROOT" "$SCRIPTROOT"
  # Find the currently used interface - used to enable dhcpcd on that interface
  AVAILABLEINTERFACES=($(ip route | grep default | grep -Po '(?<=dev ).*(?= proto)'))
  for EXTERNALINTERFACE in "${AVAILABLEINTERFACES[@]}"; do
    echo "Testing interface ${EXTERNALINTERFACE}."
    ping -c4 -I "$EXTERNALINTERFACE" archlinux.org >/dev/null 2>&1
    PINGRESULT=$?
    if [ "$PINGRESULT" = 0 ]; then
      NETINT="$EXTERNALINTERFACE"
      echo "${NETINT} looks good, lets use that."
      break
    fi
  done

  exportSettings "NETINT" "${NETINT}"
  exportSettings "KERNEL" "${USERVARIABLES[KERNEL]}"

  # Determine if it's an EFI install or not
  if [ -d "$EFIPATH" ]; then
    BOOTTYPE="EFI"
    exportSettings "EFIPATH" "$EFIPATH"
  else
    BOOTTYPE="BIOS"
  fi
  exportSettings "BOOTTYPE" "$BOOTTYPE"

  #set comparison to ignore case temporarily
  shopt -s nocasematch

  #Detect platform type. Add the appropriate packages to install.
  PLATFORM=$(hostnamectl | grep Chassis | cut -f2,2 -d':' | xargs)

  if [[ $PLATFORM =~ 'vm' ]]; then
    VMTYPE=$(hostnamectl | grep Virtualization | cut -f2,2 -d':' | xargs)
    case $VMTYPE in
    'kvm')
      PLATFORM="qemuGuest"
      ;;
    'vmware')
      PLATFORM="esxiGuest"
      ;;
    'microsoft')
      PLATFORM="hyperGuest"
      ;;
    'oracle')
      PLATFORM="vboxGuest"
      ;;
    esac
    if [[ ! "${USERVARIABLES[BUNDLES]}" =~ $PLATFORM ]]; then
      USERVARIABLES[BUNDLES]+=" $PLATFORM"
    fi
  elif [[ $PLATFORM =~ 'laptop' ]]; then
    USERVARIABLES[BUNDLES]+=" $PLATFORM"
  fi

  #Add the selected desktop to the bundles - if it isn't there already
  if [[ ! "${USERVARIABLES[DESKTOP]}" =~ ${USERVARIABLES[BUNDLES]} ]]; then
    echo "Adding ${USERVARIABLES[DESKTOP]} to bundles."
    # Add it to the front so that it's installed before any other bundles
    USERVARIABLES[BUNDLES]="${USERVARIABLES[DESKTOP]} ${USERVARIABLES[BUNDLES]}"
  fi

  #Detect CPU type. Used for setting the microcode (ucode) on the boot loader
  CPUTYPE=$(lscpu | grep Vendor)
  if [[ $CPUTYPE =~ "AMD" ]]; then
    CPUTYPE="amd"
  elif [[ $CPUTYPE =~ "Intel" ]]; then
    CPUTYPE="intel"
  fi
  exportSettings "CPUTYPE" "$CPUTYPE"

  #Detect GPU type. Add the appropriate packages to install.
  VGACONTROLLER=$(echo "$(lspci -vnn | grep VGA)" | tr '[:upper:]' '[:lower:]')
  GFXCONTROLLER=$(echo "$(lspci -vnn | grep 3D)" | tr '[:upper:]' '[:lower:]')

  if [[ ${GFXCONTROLLER} =~ "nvidia" && ${VGACONTROLLER} =~ "intel" ]] || [[ ${VGACONTROLLER} =~ "nvidia" && ${VGACONTROLLER} =~ "intel" ]]; then
    GPUBUNDLE="nvidia nvidiaPrime"
  elif [[ ${VGACONTROLLER} =~ "nvidia" ]]; then
    GPUBUNDLE="nvidia"
  elif [[ ${VGACONTROLLER} =~ "amd" ]]; then
    GPUBUNDLE="amdgpu"
  elif [[ ${VGACONTROLLER} =~ "intelgpu" ]]; then
    GPUBUNDLE="intelgpu"
  else
    GPUBUNDLE="vm"
  fi

  USERVARIABLES[BUNDLES]+=" $GPUBUNDLE"
  exportSettings "GPUBUNDLE" "$GPUBUNDLE"
  exportSettings "BUNDLES" "${USERVARIABLES[BUNDLES]}"
  #reset comparisons
  shopt -u nocasematch
}

driver() {
  importSettings "user"

  #Available Software Bundles
  # shellcheck source=softwareBundles.sh
  source "$SCRIPTROOT/softwareBundles.sh"
  #Addtional configurations needed for selected bundles
  # shellcheck source=bundleConfigurators.sh
  source "$SCRIPTROOT/bundleConfigurators.sh"

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
  "FIRST" | "")
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

firstInstallStage() {
  echo "0. Set passwords"
  if [[ $DRYRUN -ne 1 ]]; then
    ROOTPWD=""
    read -sp 'ROOT Password: ' ROOTPWD
    echo
    USERPWD=""
    read -sp "${USERVARIABLES[USERNAME]} Password: " USERPWD
    echo
    if [[ $ROOTPWD == "" ]] || [[ $USERPWD == "" ]]; then
      echo "$(tput setaf 7)$(tput setab 1) **Passwords are required. Exiting..** $(tput sgr0)"
      exit 1
    fi
  fi

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

  # If a dryrun, then just run the functions as is. Don't bother running it in the chroot environment (It doesn't exist yet).
  if [[ $DRYRUN -eq 1 ]]; then
    secondInstallStage
    thirdInstallStage
  else
    #Go into chroot. Should start at secondInstallStage
    arch-chroot /mnt ./home/"${USERVARIABLES[USERNAME]}"/arch-build.sh --rootpwd "$ROOTPWD" --userpwd "$USERPWD"

    #Go into chroot as new user. Should start at thirdInstallStage as new user.
    arch-chroot /mnt su "${USERVARIABLES[USERNAME]}" ./home/"${USERVARIABLES[USERNAME]}"/arch-build.sh
  fi

  echo "Done. Perform reboot when ready."
}

secondInstallStage() {
  echo "10. chroot: Import Settings"
  importSettings "all"

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
}

thirdInstallStage() {
  importSettings "all"

  echo "20. chroot: Install yay - AUR package manager"
  makeYay

  echo "21. chroot: Enable lib32"
  enableMultilibPackages

  echo "22. chroot: Install selected bundles"
  runCommand installSoftwareBundles "${USERVARIABLES[BUNDLES]}"

  echo "23. chroot: Run the file system packages "
  if [[ "${USERVARIABLES[ROOTFILE]}" = "BTRFS" ]]; then
    runCommand btrfsPackages-Config
  elif [[ "${USERVARIABLES[ROOTFILE]}" = "F2FS" ]]; then
    runCommand f2fsPackages-Config
  fi

  echo "24. Readying final boot"
  runCommand grubPackages-Config
  readyFinalBoot
}

exportSettings() {
  SETTINGNAME=$1
  SETTING=$2
  # echo "Exporting $1=$2" 1>&2
  EXPORTPARAM="${SETTINGNAME}=${SETTING}"

  CURRENTSETTING=$(grep "^${SETTINGNAME}=" "$SCRIPTROOT/settings.conf")
  if [[ "${CURRENTSETTING}" == "" ]]; then
    printf "\n%s" "${EXPORTPARAM}" | tee -a "$SCRIPTROOT/settings.conf" >/dev/null
  else
    # replace any previously matching settings
    sed -i "s%^${SETTINGNAME}=.*%${EXPORTPARAM}%" "$SCRIPTROOT/settings.conf"
  fi

}

#retrieveSettings 'SETTINGNAME'
retrieveSettings() {
  if [[ $DRYRUN -eq 1 ]]; then
    SETTINGSPATH="./settings.conf"
  else
    SETTINGSPATH="$SCRIPTROOT/settings.conf"
  fi

  SETTINGNAME=$1

  SETTING=$(grep "^${SETTINGNAME}=" "$SETTINGSPATH" | cut -f2,2 -d'=')
  echo "$SETTING"
}

runCommand() {
  if [[ $DRYRUN -eq 1 ]]; then
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

# Update the system clock
systemClock() {
  runCommand timedatectl set-ntp true
}

# PARTITION DISKS
partDisks() {
  if [[ $BOOTTYPE = "EFI" ]]; then
    case ${USERVARIABLES[BOOTMODE]} in
    "LEAVE" | "FORMAT")
      echo "Leaving the boot partition..."
      ;;
    "CREATE")
      echo "EFI: Boot partition will be created. Whole disk will be destroyed!"
      runCommand parted -s "$BOOTDEVICE" -- mklabel gpt mkpart "ARCH_BOOT" fat32 0% 256MiB
      ;;
    esac
  fi

  case ${USERVARIABLES[ROOTMODE]} in
  "LEAVE" | "FORMAT")
    echo "Leaving the root partition..."
    ;;
  "CREATE")
    if [[ $BOOTTYPE = "EFI" ]]; then
      #If the root device matches the boot device, don't setup device label
      if [ "$BOOTDEVICE" = "$ROOTDEVICE" ]; then
        echo "EFI: Root partition will be created."
        runCommand parted -s "$ROOTDEVICE" -- mkpart "ARCH_ROOT" ext4 256MiB 100%
      else
        echo "EFI: Root partition will be created. Whole disk will be destroyed!"
        runCommand parted -s "$ROOTDEVICE" -- mklabel gpt mkpart "ARCH_ROOT" ext4 0% 100%
      fi
    else
      #BIOS system. If boot device matches root device, then make root part the same as boot part
      if [ "$BOOTDEVICE" = "$ROOTDEVICE" ]; then
        USERVARIABLES[ROOTPART]="${USERVARIABLES[BOOTPART]}"
      fi
      echo "BIOS: Root partition will be created. Whole disk will be destroyed!"
      runCommand parted -s "$ROOTDEVICE" -- mklabel msdos mkpart primary ext4 0% 100% set 1 boot on
    fi
    ;;
  esac
}

# FORMAT PARTITIONS
formatParts() {
  FMTROOTPART="${USERVARIABLES[ROOTPART]}"
  if [[ "$BOOTTYPE" = "EFI" ]]; then
    if [ "${USERVARIABLES[BOOTMODE]}" = "CREATE" ] || [ "${USERVARIABLES[BOOTMODE]}" = "FORMAT" ]; then
      runCommand mkfs.fat -F32 "${USERVARIABLES[BOOTPART]}"
    fi

    if [ "${USERVARIABLES[ROOTMODE]}" = "CREATE" ] || [ "${USERVARIABLES[ROOTMODE]}" = "FORMAT" ]; then
      if [[ "${USERVARIABLES[ENCRYPT]}" = "YES" ]]; then
        echo "Set up encryption for ${USERVARIABLES[ROOTPART]}"
        runCommand cryptsetup -q -y -v --cipher=aes-xts-plain64 --key-size 512 --hash=sha512 luksFormat "${USERVARIABLES[ROOTPART]}"
        runCommand cryptsetup luksOpen "${USERVARIABLES[ROOTPART]}" luks

        FMTROOTPART="/dev/mapper/luks"
      else
        echo "no encryption"
      fi

      if [[ "${USERVARIABLES[ROOTFILE]}" = "EXT4" ]]; then
        echo "Make ext4 on root $FMTROOTPART"
        runCommand mkfs.ext4 -L ARCH_ROOT -F -F $FMTROOTPART
      elif [[ "${USERVARIABLES[ROOTFILE]}" = "BTRFS" ]]; then
        echo "Make btrfs on root $FMTROOTPART"
        runCommand mkfs.btrfs -L ARCH_ROOT -f -f $FMTROOTPART
      elif [[ "${USERVARIABLES[ROOTFILE]}" = "F2FS" ]]; then
        echo "Make btrfs on root $FMTROOTPART"
        runCommand mkfs.f2fs -O extra_attr,inode_checksum,sb_checksum,compression -l ARCH_ROOT -f -f $FMTROOTPART
      fi
    fi
  else
    if [ "${USERVARIABLES[ROOTMODE]}" = "CREATE" ] || [ "${USERVARIABLES[ROOTMODE]}" = "FORMAT" ]; then
      if [[ "${USERVARIABLES[ROOTFILE]}" = "EXT4" ]]; then
        echo "Make ext4 on root $FMTROOTPART"
        runCommand mkfs.ext4 -L ARCH_ROOT -F -F $FMTROOTPART
      elif [[ "${USERVARIABLES[ROOTFILE]}" = "BTRFS" ]]; then
        echo "Make btrfs on root $FMTROOTPART"
        runCommand mkfs.btrfs -L ARCH_ROOT -f -f $FMTROOTPART
      fi
    fi
  fi
}

# Mount the file systems
mountParts() {
  FMTROOTPART="${USERVARIABLES[ROOTPART]}"
  if [[ "${USERVARIABLES[ENCRYPT]}" = "YES" ]]; then
    FMTROOTPART="/dev/mapper/luks"
  fi

  if [[ "${USERVARIABLES[ROOTFILE]}" = "BTRFS" ]]; then
    #mount encrypted partition instead
    echo "Mount root partition... (BTRFS)"
    runCommand mount -o compress=zstd $FMTROOTPART /mnt

    #btrfs sub volumes
    runCommand cd /mnt
    runCommand btrfs subvolume create @
    runCommand btrfs subvolume create @home
    runCommand btrfs subvolume create @log
    runCommand btrfs subvolume create @srv
    runCommand btrfs subvolume create @pkg
    runCommand btrfs subvolume create @tmp
    runCommand btrfs subvolume create @snapshots
    runCommand cd ~
    runCommand umount /mnt
    runCommand mount -o compress=zstd,subvol=@ $FMTROOTPART /mnt

    runCommand cd /mnt
    runCommand mkdir -p {home,srv,var/{log,cache/pacman/pkg},tmp,.snapshots}

    runCommand mount -o compress=zstd,subvol=@home $FMTROOTPART home
    runCommand mount -o compress=zstd,subvol=@log $FMTROOTPART var/log
    runCommand mount -o compress=zstd,subvol=@pkg $FMTROOTPART var/cache/pacman/pkg
    runCommand mount -o compress=zstd,subvol=@srv $FMTROOTPART srv
    runCommand mount -o compress=zstd,subvol=@tmp $FMTROOTPART tmp
    runCommand mount -o compress=zstd,subvol=@snapshots $FMTROOTPART .snapshots
  elif [[ "${USERVARIABLES[ROOTFILE]}" = "EXT4" ]]; then
    echo "Mount root partition... (EXT4)"
    runCommand mount $FMTROOTPART /mnt
  elif [[ "${USERVARIABLES[ROOTFILE]}" = "F2FS" ]]; then
    echo "Mount root partition... (F2FS)"
    runCommand mount $FMTROOTPART /mnt
  fi

  if [[ "$BOOTTYPE" = "EFI" ]]; then

    runCommand mkdir /mnt/boot
    runCommand mount "${USERVARIABLES[BOOTPART]}" /mnt/boot
  else
    runCommand mount "${USERVARIABLES[ROOTPART]}" /mnt
  fi
}

setLocalMirrors() {
  GEOLOCATE=$(curl -sX GET "http://ip-api.com/json/$(curl -s icanhazip.com)")
  COUNTRYCODE=$(echo "$GEOLOCATE" | grep -Po '(?<="countryCode":").*?(?=")')
  echo "MIRRORS will be retrieved from $COUNTRYCODE"

  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write Local Mirrors to /etc/pacman.d/mirrorlist"
  else

    runCommand curl -s "https://archlinux.org/mirrorlist/?country=${COUNTRYCODE}&protocol=https&use_mirror_status=on" | sed "s/#Server/Server/" >/etc/pacman.d/mirrorlist
    runCommand sed -i '/options/a ParallelDownloads = 5' /etc/pacman.conf
  fi
}

## Install the base packages
installArchLinuxBase() {
  setLocalMirrors
  runCommand pacstrap /mnt "${archBasePackages[@]}"
}

## Generate an fstab file
makeFstab() {
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Generate fstab at /mnt/etc/fstab"
  else
    runCommand genfstab -U /mnt >>/mnt/etc/fstab
  fi
}

## Change root into the new system:
chrootTime() {
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write SECOND to $SCRIPTROOT/stage.cfg"
  else
    runCommand echo "SECOND" >"$SCRIPTROOT"/stage.cfg
  fi

  ##re-export the settings for the new stages (in chroot)
  exportSettings "SCRIPTPATH" "/home/${USERVARIABLES[USERNAME]}/arch-build.sh"
  exportSettings "SCRIPTROOT" "/home/${USERVARIABLES[USERNAME]}"

  runCommand mkdir /mnt/home/"${USERVARIABLES[USERNAME]}"
  runCommand cp "$SCRIPTROOT"/stage.cfg /mnt/home/"${USERVARIABLES[USERNAME]}"
  runCommand cp "$SCRIPTPATH" /mnt/home/"${USERVARIABLES[USERNAME]}"
  runCommand cp "$SCRIPTROOT"/softwareBundles.sh /mnt/home/"${USERVARIABLES[USERNAME]}"
  runCommand cp "$SCRIPTROOT"/bundleConfigurators.sh /mnt/home/"${USERVARIABLES[USERNAME]}"
  runCommand cp "$SCRIPTROOT"/settings.conf /mnt/home/"${USERVARIABLES[USERNAME]}"
  runCommand cp /etc/pacman.conf /mnt/etc/
  runCommand cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/
}

## Set the time zone
setTime() {
  GEOLOCATE=$(curl -sX GET "http://ip-api.com/json/$(curl -s icanhazip.com)")
  TIMEZONE=$(echo "$GEOLOCATE" | grep -Po '(?<="timezone":").*?(?=",)')
  echo "TIMEZONE will be set to $TIMEZONE"

  runCommand ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
  runCommand hwclock --systohc
}

## Uncomment en_US.UTF-8 UTF-8 and other needed locales in /etc/locale.gen
genLocales() {
  GEOLOCATE=$(curl -sX GET "http://ip-api.com/json/$(curl -s icanhazip.com)")
  COUNTRYCODE=$(echo "$GEOLOCATE" | grep -Po '(?<="countryCode":").*?(?=")')
  COUNTRYINFO=$(curl -sX GET "https://raw.githubusercontent.com/annexare/Countries/master/data/countries.json" | tr -d '\n' | tr -d ' ')
  LANGUAGES=$(echo "$COUNTRYINFO" | grep -Po '(?<="'"$COUNTRYCODE"'":{).*?(?=})' | grep -Po '(?<=:\[).*?(?=\])')
  #LANGUAGES=$(echo $LANGUAGES | grep -oP '(?<=").*?(?=")' | head -n 1)
  readarray -t LANGARRAY < <(echo "$LANGUAGES" | grep -oP '(?<=").*?(?=")')
  declare -p LANGARRAY
  for LANGUAGE in "${LANGARRAY[@]}"; do
    LANGCODE="${LANGUAGE}_${COUNTRYCODE}.UTF-8"
    if grep -q "${LANGCODE}" /etc/locale.gen; then
      echo "found - ${LANGCODE}"
      break
    fi
  done

  echo "LANGUAGE CODE will be set to $LANGCODE"

  runCommand sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
  runCommand sed -i "s/#$LANGCODE UTF-8/$LANGCODE UTF-8/" /etc/locale.gen
  runCommand locale-gen
  runCommand echo "LANG=$LANGCODE" >>/etc/locale.conf
}

## Create the hostname file:
applyHostname() {
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write ${USERVARIABLES[HOSTNAME]} to /etc/hostname"
  else
    runCommand echo "${USERVARIABLES[HOSTNAME]}" >>/etc/hostname
  fi
}

## ADD HOSTS ENTRIES
addHosts() {
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write Localinfo to /etc/hosts"
  else
    {
      echo "127.0.0.1     localhost"
      echo "::1       localhost"
      echo "127.0.1.1     ${USERVARIABLES[HOSTNAME]}.mydomain      ${USERVARIABLES[HOSTNAME]}"
    } >>/etc/hosts
  fi
}

## GENERATE INITRAMFS
genInit() {
  if [[ "${USERVARIABLES[ENCRYPT]}" = "YES" ]]; then
    runCommand sudo sed -i "s/^HOOKS=(base udev autodetect modconf block filesystems keyboard fsck).*/HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck shutdown)/" /etc/mkinitcpio.conf
  else
    runCommand sudo sed -i "s/^HOOKS=(base udev autodetect modconf block filesystems keyboard fsck).*/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck shutdown)/" /etc/mkinitcpio.conf
  fi
  runCommand mkinitcpio -P
}

## ROOT PASSWORD
rootPassword() {
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Set root password to $ROOTPWD"
  else
    echo "root:$ROOTPWD" | chpasswd
    echo
  fi
}

## INSTALL BOOTLOADER AND MICROCODE
readyForBoot() {
  if [[ "$BOOTTYPE" = "EFI" ]]; then
    runCommand pacman -S --noconfirm grub "$CPUTYPE"'-ucode' os-prober efibootmgr
    runCommand grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
    runCommand grub-mkconfig -o /boot/grub/grub.cfg
  else
    runCommand pacman -S --noconfirm grub "$CPUTYPE"'-ucode' os-prober
    runCommand grub-install --target=i386-pc "$ROOTDEVICE"
    runCommand grub-mkconfig -o /boot/grub/grub.cfg
  fi
}

# Create the new user and add them to the wheel group.
# Disable the password requirement to run sudo. Will be re-enabled in the final stages of arch-build.
createUser() {
  runCommand useradd -m "${USERVARIABLES[USERNAME]}"
  runCommand gpasswd -a "${USERVARIABLES[USERNAME]}" wheel
  # set user password
  runCommand echo "Set password for ${USERVARIABLES[USERNAME]}"

  if [[ $DRYRUN -eq 1 ]]; then
    echo "Set User password to $USERPWD"
  else
    echo "${USERVARIABLES[USERNAME]}:$USERPWD" | chpasswd
  fi

  # enable wheel group for sudoers
  runCommand sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers
  # enable wheel group for sudoers - no password. TEMPORARY
  runCommand sed -i "s/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/" /etc/sudoers
  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write THIRD to /home/${USERVARIABLES[USERNAME]}/stage.cfg"
  else
    runCommand echo "THIRD" >/home/"${USERVARIABLES[USERNAME]}"/stage.cfg
  fi

  # SET OWNERSHIP OF SCRIPT FILES
  runCommand chown "${USERVARIABLES[USERNAME]}":"${USERVARIABLES[USERNAME]}" "$SCRIPTROOT" --recursive
}

enableMultilibPackages() {
  runCommand sudo sed -i '/#\[multilib\]/a Include = \/etc\/pacman.d\/mirrorlist' /etc/pacman.conf
  runCommand sudo sed -i "s/#\[multilib\]/[multilib]/" /etc/pacman.conf
  runCommand sudo pacman -Syyu --noconfirm
}

# make yay
makeYay() {
  if [[ $(pacman -Ss "yay-bin") ]]; then
    echo "yay-bin found custom repo.. install direct"
    runCommand sudo pacman -S yay-bin --noconfirm
  else
    runCommand cd /home/"${USERVARIABLES[USERNAME]}"
    runCommand git clone https://aur.archlinux.org/yay-bin.git
    runCommand cd yay-bin
    runCommand makepkg -sri --noconfirm
    runCommand cd /home/"${USERVARIABLES[USERNAME]}"
  fi
}

# enable network manager/disable dhcpcd
readyFinalBoot() {
  runCommand sudo systemctl enable NetworkManager

  if [[ $DRYRUN -eq 1 ]]; then
    echo "Write DONE to $SCRIPTROOT/stage.cfg"
  else
    runCommand echo "DONE" >"$SCRIPTROOT"/stage.cfg
  fi
  # Remove no password for sudoers
  runCommand sudo sed -i "s/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
}

#Start the script
driver
