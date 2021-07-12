#!/bin/bash
# bundleConfigurators

# if launched with a parameter, called that function, or list available functions with -h
while [[ "$#" -gt 0 ]];
do
  case $1 in
    -h|--help) 
        echo "Available configs"
        RUNCONFIG='compgen -A function'
    ;;
    *)
      RUNCONFIG=${1}Packages-Config
    ;;
  esac
  shift
done

nvidiaPackages-Config(){
  if [[  ${USERVARIABLES[KERNEL]} = "" ]]; then
    USERVARIABLES[KERNEL]=$(retrieveSettings 'KERNEL')
  fi

  case ${USERVARIABLES[KERNEL]} in
    "linux") 
      echo "Using vanilla kernel. No change necessary."
    ;;
    "linux-lts") 
      echo "Using LTS kernel, change to nvidia-lts."
    ;;
    *) 
      echo "Using ${USERVARIABLES[KERNEL]} kernel, change nvidia-dkms."
      sudo yay -R nvidia --noconfirm
      sudo yay -S nvidia-dkms --noconfirm
    ;;
  esac

  echo 'VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json' | sudo tee -a /etc/environment
}

nvidiaPrimePackages-Config(){
  ##Add nvidia kernel modules
  sudo sed -i "s/^MODULES=().*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/" /etc/mkinitcpio.conf
  sudo mkinitcpio -P
}

grubPackages-Config(){
  if [[ "${USERVARIABLES[ROOTPART]}" == "" ]]; then
    USERVARIABLES[ROOTPART]=$(retrieveSettings 'ROOTPART')
  fi

  if [[ "${USERVARIABLES[ENCRYPT]}" == "" ]]; then
      USERVARIABLES[ENCRYPT]=$(retrieveSettings 'ENCRYPT')
  fi

  if [[ "${USERVARIABLES[ENCRYPT]}" == "YES" ]]; then
      ##Enable grub boot crypto
      ROOTUUID=$(sudo blkid -s UUID -o value "${USERVARIABLES[ROOTPART]}")
      sudo sed -i 's|^GRUB_CMDLINE_LINUX="".*|GRUB_CMDLINE_LINUX="cryptdevice=UUID='"${ROOTUUID}"':root"|' /etc/default/grub
      sudo sed -i 's|^#GRUB_ENABLE_CRYPTODISK=y.*|GRUB_ENABLE_CRYPTODISK=y|' /etc/default/grub
      sudo grub-mkconfig -o /boot/grub/grub.cfg
  fi
}

btrfsPackages-Config(){
  if [[ "${USERVARIABLES[ROOTPART]}" == "" ]]; then
    USERVARIABLES[ROOTPART]=$(retrieveSettings 'ROOTPART')
  fi

  yay -S --noconfirm snapper grub-btrfs snap-pac

  ##Add the snapper config manually
  sudo cp /etc/snapper/config-templates/default /etc/snapper/configs/root
  sudo sed -i 's/SNAPPER_CONFIGS=""/SNAPPER_CONFIGS="root"/' /etc/conf.d/snapper
  
  ##enable grub snapshots
  sudo systemctl enable grub-btrfs.path
  sudo sed -i 's|^#GRUB_DISABLE_RECOVERY=.*|GRUB_DISABLE_RECOVERY=false|' /etc/default/grub
  sudo grub-mkconfig -o /boot/grub/grub.cfg
  sudo systemctl enable snapper-boot.timer
}

##TODO
touchpadPackages-Config(){
  ##Natural Scrolling
  ##Enable touchpad click
  echo "Not yet enabled"
}

vboxGuestPackages-Config(){
  sudo systemctl enable vboxservice.service
  printf "\"FS0:\EFI\refind\refind_x64.efi\"" | sudo tee -a /boot/startup.nsh
}

qemuGuestPackages-Config(){
  sudo sed -i "s/^MODULES=().*/MODULES=(virtio virtio_blk virtio_pci virtio_net)/" /etc/mkinitcpio.conf

  mkdir ~/xf86-video-qxl-git
  cd ~/xf86-video-qxl-git
  curl https://gist.githubusercontent.com/matty-r/200bed9bfea6e920ac71701941f66a06/raw/bfb2fa9afdb0d4a56bf9ce010cbe703f00e5a227/PKGBUILD > PKGBUILD
  makepkg -sri --noconfirm
  cd ~

  sudo mkinitcpio -P
  sudo systemctl enable qemu-guest-agent.service
}

kdePackages-Config(){
  if [[ "${USERVARIABLES[USERNAME]}" == "" ]]; then
    USERVARIABLES[USERNAME]=$(retrieveSettings 'USERNAME')
  fi

  #enable SDDM and set autologin, also set theme to breeze
  sudo systemctl enable sddm
  sudo mkdir /etc/sddm.conf.d

  sudo kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Autologin --key Session plasma
  sudo kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Autologin --key User "${USERVARIABLES[USERNAME]}"
  sudo kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Theme --key Current breeze

  kwriteconfig5 --file ~/.config/kdeglobals --group KDE --key SingleClick false

  kwriteconfig5 --file ~/.config/kwinrc --group Plugins --key magiclampEnabled true
  kwriteconfig5 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_squashEnabled false
  kwriteconfig5 --file ~/.config/kwinrc --group Plugins --key blurEnabled true

  ## Dolphin / Configure Dolphin
  kwriteconfig5 --file ~/.config/dolphinrc --group CompactMode --key FontWeight 50
  kwriteconfig5 --file ~/.config/dolphinrc --group DetailsMode --key ExpandableFolders false
  kwriteconfig5 --file ~/.config/dolphinrc --group DetailsMode --key FontWeight 50
  kwriteconfig5 --file ~/.config/dolphinrc --group DetailsMode --key PreviewSize 16
  kwriteconfig5 --file ~/.config/dolphinrc --group General --key ShowSelectionToggle false
  kwriteconfig5 --file ~/.config/dolphinrc --group IconsMode --key FontWeight 50
  kwriteconfig5 --file ~/.config/dolphinrc --group MainWindow --key MenuBar Disabled
  ## Set Dolphin to start up at home folder

  ## Settings / Screen Edges. Top right desktop view, bottom right window view

  ## Set icon view to show all, not just current desktop
  

}

gnomePackages-Config(){
  sudo systemctl enable gdm
}

xfcePackages-Config(){
  sudo systemctl enable lxdm
}

virtualPackages-Config(){
  sudo systemctl enable libvirtd
}

hyperGuestPackages-Config(){
  git clone https://github.com/Microsoft/linux-vm-tools
  cd linux-vm-tools/arch
  yay -S --noconfirm xrdp-git
  ./makepkg.sh
  cd ~/linux-vm-tools/arch
  sudo ./install-config.sh
  cd ~
  cp /etc/X11/xinit/xinitrc ~/.xinitrc
}

esxiGuestPackages-Config(){
  sudo systemctl enable vmtoolsd.service vmware-vmblock-fuse.service
  echo "needs_root_rights=yes" | sudo tee /etc/X11/Xwrapper.config
}

officePackages-Config(){
  sudo systemctl enable org.cups.cupsd
}

mediaPackages-Config(){
  sudo systemctl enable bluetooth
}

grubThemePackages-Config(){
  ## Apply Grub Theme
  sudo sed -i 's|^#GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/arch-silence/theme.txt"|' /etc/default/grub
  sudo grub-mkconfig -o /boot/grub/grub.cfg
}

kdeThemePackages-Config(){
  ## Installed the tiled menu
  ## Remove
  #cd ~
  #curl -LO https://github.com/Zren/plasma-applet-tiledmenu/archive/v40.zip 
  #unzip v40.zip
  #cd ~/plasma-applet-tiledmenu-40/
  #kpackagetool5 -t Plasma/Applet -i package
  
  ## WIP - Change application menu to tiled menu
  #sudo sed -i 's|org.kde.plasma.kickoff|com.github.zren.tiledmenu|' /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js

echo 'kickoff.currentConfigGroup = ["Configuration","General"] 
kickoff.writeConfig("appDescription", "hidden")
kickoff.writeConfig("appListWidth", "248")
kickoff.writeConfig("defaultTileColor", "#00000000")
kickoff.writeConfig("menuItemHeight", "28")
kickoff.writeConfig("popupHeight", "633")
kickoff.writeConfig("searchFieldFollowsTheme", "true")
kickoff.writeConfig("searchFieldHeight", "36")
kickoff.writeConfig("sidebarButtonSize", "36")
kickoff.writeConfig("sidebarIconSize", "28")
kickoff.writeConfig("tileMargin", "4")' | sudo tee -a /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js

  kwriteconfig5 --file ~/.config/plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 24 formfactor 2
  kwriteconfig5 --file ~/.config/plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 24 immutability 1
  kwriteconfig5 --file ~/.config/plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 24 location 4
  kwriteconfig5 --file ~/.config/plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 24 plugin org.kde.panel

  ##temporary fix for the dark theme colours being incorrect
  sudo cp /usr/share/color-schemes/Qogirdark.colors /usr/share/plasma/desktoptheme/Qogir-dark/colors

  ##Apply the themes to qogir and icons set to numix
  kwriteconfig5 --file ~/.config/kdeglobals --group General --key ColorScheme BreezeLight
  kwriteconfig5 --file ~/.config/kdeglobals --group General --key Name 'Breeze Light'
  kwriteconfig5 --file ~/.config/kdeglobals --group Icons --key Theme Papirus
  kwriteconfig5 --file ~/.config/kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezetwilight.desktop
  kwriteconfig5 --file ~/.config/kdeglobals --group KDE --key SingleClick false
  
  kwriteconfig5 --file ~/.kde4/share/config/kdeglobals --group General --key ColorScheme BreezeLight
  kwriteconfig5 --file ~/.kde4/share/config/kdeglobals --group General --key Name 'Breeze Light'
  kwriteconfig5 --file ~/.kde4/share/config/kdeglobals --group General --key widgetStyle Breeze
  kwriteconfig5 --file ~/.kde4/share/config/kdeglobals --group Icons --key Theme Papirus
  
  kwriteconfig5 --file ~/.config/kwinrc --group TabBox --key BorderActivate 9
  kwriteconfig5 --file ~/.config/kwinrc --group TabBox --key DesktopLayout org.kde.breeze.desktop
  kwriteconfig5 --file ~/.config/kwinrc --group TabBox --key DesktopListLayout org.kde.breeze.desktop
  kwriteconfig5 --file ~/.config/kwinrc --group TabBox --key LayoutName org.kde.breeze.desktop

  kwriteconfig5 --file ~/.config/kwinrc --group Effect-PresentWindows --key BorderActivate 7
  kwriteconfig5 --file ~/.config/kwinrc --group Effect-DesktopGrid --key BorderActivateAll 9

  kwriteconfig5 --file ~/.config/kwinrc --group Desktops --key Number 4
  kwriteconfig5 --file ~/.config/kwinrc --group Desktops --key Rows 2

  kwriteconfig5 --file ~/.config/kwinrc --group KDE --key AnimationDurationFactor 0.25

  kwriteconfig5 --file ~/.config/kwinrc --group org.kde.kdecoration2 --key BorderSize None
  kwriteconfig5 --file ~/.config/kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto false
  kwriteconfig5 --file ~/.config/kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft ''
  kwriteconfig5 --file ~/.config/kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight IAX

  ## Settings / Input Devices / Keyboard
  kwriteconfig5 --file ~/.config/kcminputrc --group Keyboard --key NumLock 0

  ## Settings / Startup and Shutdown / desktop session
  kwriteconfig5 --file ~/.config/ksmserverrc --group General --key offerShutdown false
  kwriteconfig5 --file ~/.config/ksmserverrc --group General --key confirmLogout false

  ##Settings / Plasma Style
  kwriteconfig5 --file ~/.config/plasmarc --group Theme --key name breeze-dark 
  kwriteconfig5 --file ~/.config/plasmarc --group Theme-plasmathemeexplorer --key name breeze-dark 
  
  ##Settings / Screen Locker
  # kwriteconfig5 --file ~/.config/kscreenlockerrc --group Greeter --key Theme com.github.vinceliuice.Qogir
  # kwriteconfig5 --file ~/.config/kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.potd
  # kwriteconfig5 --file ~/.config/kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.potd --group General --key Category 1065374
  # kwriteconfig5 --file ~/.config/kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.potd --group General --key Provider unsplash

  ##Settings / Application Style / GTK 3
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-application-prefer-dark-theme false
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-button-images true
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-cursor-theme-name breeze_cursors
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-decoration-layout :minimize,maximize,close
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-enable-animations true
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-fallback-icon-theme Adwaita
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-font-name 'Noto Sans, 10'
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-icon-theme-name Papirus
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-menu-images true
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-modules colorreload-gtk-module:window-decorations-gtk-module
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-primary-button-warps-slider true
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-theme-name Breeze 
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-toolbar-style 3

  ##Settings / Application Style / GTK 2
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-enable-animations 1
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-cursor-theme-name '"breeze_cursors"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-primary-button-warps-slider 1
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-font-name '"Noto Sans,  10"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-theme-name '"Breeze"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-icon-theme-name '"Papirus"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-fallback-icon-theme '"Adwaita"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-toolbar-style 3
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-menu-images 1
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-button-images 1

}

gamingPackages-Config(){
  cd ~
  mkdir ~/wine-tkg-staging
  cd ~/wine-tkg-staging
  ## Download latest https://github.com/Frogging-Family/wine-tkg-git
  DOWNLOADURL="$(curl -sX GET https://api.github.com/repos/Frogging-Family/wine-tkg-git/releases/latest | grep -Po '(?<="browser_download_url": ").*?(?=")' | grep -i staging)"
  TKGFILENAME="$(basename "${DOWNLOADURL}")"
  curl -LO "${DOWNLOADURL}"
  sudo pacman -U "${TKGFILENAME}" --noconfirm
  cd ~
}

#TODO
rdpPackages-Config(){
  SESHNAME=""

  if [[ ${USERVARIABLES[DESKTOP]} == "" ]]; then
    USERVARIABLES[DESKTOP]=$(retrieveSettings 'DESKTOP')
  fi

  sudo systemctl enable xrdp xrdp-sesman

  echo "allowed_users=anybody" | sudo tee /etc/X11/Xwrapper.config
  case ${USERVARIABLES[DESKTOP]} in
    "kde" ) SESHNAME="startplasma-x11"
      ;;
    "xfce" ) SESHNAME="startxfce4"
      ;;
    "gnome" ) SESHNAME="gnome-session"
      ;;
  esac

  cp /etc/X11/xinit/xinitrc ~/.xinitrc
  sed -i "s/twm &/#twm &/" ~/.xinitrc
  sed -i "s/xclock -geometry 50x50-1+1 &/#xclock -geometry 50x50-1+1 &/" ~/.xinitrc
  sed -i "s/xterm -geometry 80x50+494+51 &/#xterm -geometry 80x50+494+51 &/" ~/.xinitrc
  sed -i "s/xterm -geometry 80x20+494-0 &/#xterm -geometry 80x20+494-0 &/" ~/.xinitrc
  sed -i "s/exec xterm -geometry 80x66+0+0 -name login/#exec xterm -geometry 80x66+0+0 -name login/" ~/.xinitrc

  echo "exec dbus-run-session -- $SESHNAME" >> ~/.xinitrc
  sudo sed -i "s/use_vsock=true/use_vsock=false/" /etc/xrdp/xrdp.ini
}

#retrieveSettings 'SETTINGNAME'
retrieveSettings(){
  # Script Variables. DO NOT CHANGE THESE
  BUNDLECONFIGPATH=$( readlink -m "$( type -p "$0" )")
  BUNDLECONFIGROOT=${BUNDLECONFIGPATH%/*}

  SETTINGSPATH="$BUNDLECONFIGROOT/installsettings.cfg" 

  if [ ! -f "$SETTINGSPATH" ]; then
    echo 'Unable to import required settings. Exiting.'
    exit 1
  fi

  SETTINGNAME=$1
  SETTING=$(grep "$SETTINGNAME" "$SETTINGSPATH" | cut -f2,2 -d'=')
  echo "$SETTING"
}

if [[ $RUNCONFIG ]]; then
    $RUNCONFIG
fi