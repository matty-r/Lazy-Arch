#!/bin/bash
SOFTWAREBUNDLESPATH=$( readlink -m "$( type -p "$0" )")
SOFTWAREBUNDLESROOT=${SOFTWAREBUNDLESPATH%/*}

declare -a gamingPackages nvidiaPackages virtualPackages rdpPackages dailyPackages officePackages mediaPackages
declare -a adminPackages devPackages kdePackages gnomePackages xfcePackages kdeThemePackages grubThemePackages
declare -a vboxGuestPackages qemuGuestPackages hyperGuestPackages amdgpuPackages esxiGuestPackages laptopPackages
declare -A availableBundles

#Software Bundles
availableBundles[gaming]=gamingPackages
availableBundles[virtual]=virtualPackages
availableBundles[rdp]=rdpPackages
availableBundles[daily]=dailyPackages
availableBundles[office]=officePackages
availableBundles[media]=mediaPackages
availableBundles[admin]=adminPackages
availableBundles[dev]=devPackages

#Platform Bundles
availableBundles[laptop]=laptopPackages

#Guest Type Bundles
availableBundles[vboxGuest]=vboxGuestPackages
availableBundles[qemuGuest]=qemuGuestPackages
availableBundles[hyperGuest]=hyperGuestPackages
availableBundles[esxiGuest]=esxiGuestPackages

#GPU Bundles
availableBundles[nvidia]=nvidiaPackages
availableBundles[amdgpu]=amdgpuPackages

#Theming Bundles
availableBundles[kdeTheme]=kdeThemePackages
availableBundles[grubTheme]=grubThemePackages

##Desktop Environment Bundles
availableBundles[kde]=kdePackages
availableBundles[gnome]=gnomePackages
availableBundles[xfce]=xfcePackages

# if launched with a parameter, call that function, or list available functions with -h
while [[ "$#" -gt 0 ]];
do
  case $1 in
    *)
      INSTALLPACKAGES="${1}"
      ##if UNATTENDED is set, then this has been called from the arch-build script - so don't ask to run the config.. just run it.
      UNATTENDED=false
    ;;
  esac
  shift
done

#Software Packages
gamingPackages=(steam obs-studio discord lib32-fontconfig fontconfig lutris mangohud lib32-mangohud gamemode lib32-gamemode goverlay-bin)
virtualPackages=(libvirt qemu virt-manager ebtables dnsmasq ovmf)
rdpPackages=(xrdp-git xorgxrdp-git xorg-xinit xterm xorg-xrdb)
dailyPackages=(protonmail-bridge-bin nextcloud-client)
officePackages=(cups cups-pdf tesseract tesseract-data-eng pdftk libreoffice-fresh okular masterpdfeditor-free gscan2pdf otf-ibm-plex ttf-carlito ttf-caladea ttf-liberation)
mediaPackages=(spotify glimpse-editor-git pulseaudio-bluetooth vlc bluez bluez-utils pulseaudio-alsa) 
adminPackages=(rsync filezilla networkmanager-openvpn remmina-git freerdp-git gnome-keyring)
devPackages=(visual-studio-code-bin qtcreator)

#Boot Packages
## TODO
#grubPackages=()

laptopPackages=(power-profiles-daemon)

#Wine Gaming Packages
#https://github.com/lutris/lutris/wiki/Game:-Blizzard-App
battleNetPackages=(lib32-gnutls lib32-libldap lib32-libgpg-error lib32-sqlite lib32-libpulse wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs)

## Add to /etc/environment "VK_ICD_FILENAMES=/" See Arch Wiki vulkan

#Arch Linux Base
archBasePackages=(base "${USERVARIABLES[KERNEL]}" "${USERVARIABLES[KERNEL]}"-headers linux-firmware cryptsetup sudo device-mapper e2fsprogs ntfs-3g inetutils logrotate lvm2 man-db mdadm nano netctl pciutils perl procps-ng sysfsutils texinfo usbutils util-linux vi xfsprogs openssh git autoconf automake binutils bison fakeroot findutils flex gcc libtool m4 make pacman patch pkgconf which networkmanager btrfs-progs unzip wget alsa-utils htop)

#Guest Type Packages
vboxGuestPackages=(virtualbox-guest-utils)
qemuGuestPackages=(qemu-guest-agent spice-vdagent)
hyperGuestPackages=(xf86-video-fbdev)
esxiGuestPackages=(open-vm-tools xf86-input-vmmouse xf86-video-vmware mesa)

#GPU Packages
nvidiaPackages=(nvidia lib32-nvidia-utils nvidia-settings vulkan-icd-loader vulkan-headers lib32-vulkan-icd-loader)
nvidiaPrimePackages=(nvidia-prime)
amdgpuPackages=(mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon)

##Theming Packages
kdeThemePackages=(papirus-icon-theme-git)
grubThemePackages=(arch-silence-grub-theme-git)


##Desktop Environment Packages
kdePackages=(plasma kcalc konsole spectacle dolphin dolphin-plugins filelight kate kwalletmanager kdeconnect kdf kdialog kfind packagekit-qt5 ffmpegthumbs ark gwenview print-manager sddm partitionmanager firefox bluedevil)
gnomePackages=(gnome gnome-extra networkmanager firefox)
xfcePackages=(xfce4 xfce4-goodies lxdm networkmanager network-manager-applet firefox pavucontrol pulseaudio pulseaudio-alsa networkmanager-openvpn file-roller p7zip unrar tar)


installSoftwareBundles(){
  IN=${*}
  arrIN=(${IN// / })
  declare -a aggregatePackagesArr


  for bundle in "${arrIN[@]}"
  do
    if [[ ${availableBundles[$bundle]} ]]; then
      arrayBundle="${availableBundles[$bundle]}[@]"
      aggregatePackagesArr=()
      for package in "${!arrayBundle}"
      do
          aggregatePackagesArr+=("$package")
      done
      ##Install each bundle seperately
      yay -S --noconfirm "${aggregatePackagesArr[@]}"

      ## Go through and check to make sure each app has been successfully installed.
      ## Otherwise try and reinstall the app individiually. This would occur when there is an error on a single app in the
      ## array of apps to install, which prevents the remainder of the apps from installing.
      for app in "${aggregatePackagesArr[@]}"
      do
        if [[ "error" =~ $(pacman -Q "$app") ]]; then
          echo "$app was not installed. Retrying.."
          yay -S --noconfirm "$app"
        else
          echo "$app installed successfully. Continuing.."
        fi
      done

      if [ -f "$SOFTWAREBUNDLESROOT"/bundleConfigurators.sh ]; then
        if [ "$UNATTENDED" = false ] ; then
          read -rp "Run configurator (if available) for $bundle?:" answer
          if [[ "$answer" =~ "y" ]]; then
              ./bundleConfigurators.sh "$bundle"
          fi
        else 
          echo "$(tput setaf 3)$(tput setab 1) ------------------- Start ${bundle}Packages-Config ------------------- $(tput sgr0)"
          "${bundle}Packages-Config"
          echo "$(tput setaf 2)$(tput setab 1) ------------------- Done ${bundle}Packages-Config ------------------- $(tput sgr0)"
        fi
      fi
    else
      echo "Chosen bundle $bundle is invalid. Skipping!"
    fi
  done 
}


if [[ "$INSTALLPACKAGES" ]]; then
    installSoftwareBundles "${INSTALLPACKAGES[*]}"
fi