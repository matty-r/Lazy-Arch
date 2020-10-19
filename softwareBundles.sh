#!/bin/bash
SOFTWAREBUNDLESPATH=$( readlink -m $( type -p $0 ))
SOFTWAREBUNDLESROOT=${SOFTWAREBUNDLESPATH%/*}


declare -a gamingPackages nvidiaPackages virtualPackages rdpPackages dailyPackages officePackages mediaPackages
declare -a adminPackages devPackages themePackages kdePackages gnomePackages xfcePackages
declare -a vboxGuestPackages qemuGuestPackages hyperGuestPackages amdgpuPackages esxiGuestPackages
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

#Guest Type Bundles
availableBundles[vboxGuest]=vboxGuestPackages
availableBundles[qemuGuest]=qemuGuestPackages
availableBundles[hyperGuest]=hyperGuestPackages
availableBundles[esxiGuest]=esxiGuestPackages

#GPU Bundles
availableBundles[nvidia]=nvidiaPackages
availableBundles[amdgpu]=amdgpuPackages

#Theming Bundles
availableBundles[theme]=themePackages

##Desktop Environment Bundles
availableBundles[kde]=kdePackages
availableBundles[gnome]=gnomePackages
availableBundles[xfce]=xfcePackages

# if launched with a parameter, call that function, or list available functions with -h
while [[ "$#" -gt 0 ]];
do
  case $1 in
    *)
      INSTALLPACKAGES+=("${1}")
    ;;
  esac
  shift
done

#Software Packages
gamingPackages=(steam obs-studio discord lib32-fontconfig)
virtualPackages=(libvirt qemu virt-manager ebtables dnsmasq ovmf)
rdpPackages=(xrdp-git xorgxrdp-git xorg-xinit xterm xorg-xrdb)
dailyPackages=(protonmail-bridge nextcloud-client)
officePackages=(cups cups-pdf tesseract tesseract-data-eng pdftk-bin libreoffice-fresh okular masterpdfeditor-free gscan2pdf)
mediaPackages=(spotify glimpse-editor-git pulseaudio-bluetooth vlc) 
adminPackages=(htop rsync filezilla putty networkmanager-openvpn remmina-git freerdp-git gnome-keyring wget fwupd)
devPackages=(visual-studio-code-bin qtcreator)

#Wine Gaming Packages
#https://github.com/lutris/lutris/wiki/Game:-Blizzard-App
battleNetPackages=(lib32-gnutls lib32-libldap lib32-libgpg-error lib32-sqlite lib32-libpulse wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs )
wineGamingPackages=(lutris vulkan-icd-loader lib32-vulkan-icd-loader)

#Guest Type Packages
vboxGuestPackages=(vbox-guest-utils)
qemuGuestPackages=(qemu-guest-agent spice-vdagent)
hyperGuestPackages=(xf86-video-fbdev)
esxiGuestPackages=(open-vm-tools xf86-input-vmmouse xf86-video-vmware mesa)

#GPU Packages
nvidiaPackages=(nvidia lib32-nvidia-utils nvidia-settings)
amdgpuPackages=(mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon)

##Theming Packages
##Old theming adapta-gtk-theme adapta-kde papirus-icon-theme ttf-roboto 
themePackages=(numix-circle-icon-theme-git qogir-gtk-theme-git qogir-kde-theme-git arch-silence-grub-theme-git)

##Desktop Environment Packages
kdePackages=(plasma kcalc konsole spectacle dolphin dolphin-plugins filelight kate kwalletmanager kdeconnect kdf kdialog kfind packagekit-qt5 ffmpegthumbs ark gwenview print-manager sddm partitionmanager)
gnomePackages=(gnome gnome-extra networkmanager)
xfcePackages=(xfce4 xfce4-goodies lxdm networkmanager network-manager-applet)


installSoftwareBundles(){
  IN=${@}
  arrIN=(${IN// / })
  declare -a aggregatePackagesArr
  aggregatePackagesString=""

  for bundle in "${arrIN[@]}"
  do
      if [[ ${availableBundles[$bundle]} ]]; then
        arrayBundle=${availableBundles[$bundle]}[@]
        for package in "${!arrayBundle}"
        do
            echo "Installing ${!arrayBundle}"
            yay -S "${!arrayBundle}"
            if [ -f $SOFTWAREBUNDLESROOT/bundleConfigurators.sh ]; then
                read -p "Run configurator (if available) for $bundle?:" answer
                if [[ "$answer" =~ "y" ]]; then
                    ./bundleConfigurators.sh $bundle
                fi
            fi
        done
      else
        echo "Chosen bundle $bundle is invalid. Skipping!"
      fi
  done  
}


if [[ $INSTALLPACKAGES ]]; then
    installSoftwareBundles ${INSTALLPACKAGES[*]}
fi