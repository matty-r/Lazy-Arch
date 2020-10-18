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

btrfsPackages-Config(){
  sudo snapper -c root create-config /
  sudo btrfs sub del /.snapshots/
  mkdir /.snapshots
  echo "${USERVARIABLES[ROOTPART]} 	/.snapshots  		btrfs     	rw,relatime,compress=lzo,ssd,space_cache=v2,subvol=@snapshots	0 0" | sudo tee -a /etc/fstab
  sudo mount /.snapshots/
  sudo systemctl enable grub-btrfs.path
  sudo sed -i 's|^#GRUB_DISABLE_RECOVERY=.*|GRUB_DISABLE_RECOVERY=false|' /etc/default/grub
  sudo grub-mkconfig -o /boot/grub/grub.cfg
  sudo systemctl enable snapper-boot.timer
}

vboxGuestPackages-Config(){
  sudo systemctl enable vboxservice.service
  echo "\"FS0:\EFI\refind\refind_x64.efi\"" | sudo tee -a /boot/startup.nsh
}

qemuGuestPackages-Config(){
  sudo sed -i "s/^MODULES=().*/MODULES=(virtio virtio_blk virtio_pci virtio_net)/" /etc/mkinitcpio.conf

  mkdir ~/xf86-video-qxl-git
  cd ~/xf86-video-qxl-git
  curl https://gist.githubusercontent.com/matty-r/200bed9bfea6e920ac71701941f66a06/raw/bfb2fa9afdb0d4a56bf9ce010cbe703f00e5a227/PKGBUILD > PKGBUILD
  makepkg -sri --noconfirm
  cd ~

  sudo mkinitcpio -P
  sudo systemctl enable qemu-ga.service
}

kdePackages-Config(){
  #enable SDDM and set autologin, also set theme to breeze
  sudo systemctl enable sddm
  sudo mkdir /etc/sddm.conf.d

  sudo kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Autologin --key Session plasma
  sudo kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Autologin --key User ${USERVARIABLES[USERNAME]}
  sudo kwriteconfig5 --file /etc/sddm.conf.d/kde_settings.conf --group Theme --key Current breeze
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

themePackages-Config(){
  ##Apply grub theming fixes
  ROOTUUID=$(sudo blkid -s UUID -o value ${USERVARIABLES[ROOTPART]})
  sudo sed -i 's|^#GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/arch-silence/theme.txt"|' /etc/default/grub
  sudo sed -i 's|^GRUB_CMDLINE_LINUX="".*|GRUB_CMDLINE_LINUX="cryptdevice=UUID='${ROOTUUID}':root"|' /etc/default/grub
  sudo sed -i 's|^#GRUB_ENABLE_CRYPTODISK=y.*|GRUB_ENABLE_CRYPTODISK=y|' /etc/default/grub
  sudo grub-mkconfig -o /boot/grub/grub.cfg

  ## Installed the tiled menu
  curl -L -O https://github.com/Zren/plasma-applet-tiledmenu/archive/v40.zip 
  unzip v40.zip
  cd ~/plasma-applet-tiledmenu-40/
  kpackagetool5 -t Plasma/Applet -i package
  sed -i 's|^plugin=org.kde.plasma.taskmanager.*|plugin=com.github.zren.tiledmenu|' ~/.config/plasma-org.kde.plasma.desktop-appletsrc
  sed -i 's|^org.kde.plasma.taskmanager.*|plugin=org.kde.plasma.icontasks|' ~/.config/plasma-org.kde.plasma.desktop-appletsrc

  ##temporary fix for the dark theme colours being incorrect
  sudo cp /usr/share/color-schemes/Qogirdark.colors /usr/share/plasma/desktoptheme/Qogir-dark/colors

  ##Apply the themes to qogir and icons set to numix
  kwriteconfig5 --file ~/.config/kdeglobals --group General --key ColorScheme Qogir
  kwriteconfig5 --file ~/.config/kdeglobals --group General --key Name Breeze
  kwriteconfig5 --file ~/.config/kdeglobals --group Icons --key Theme Numix-Circle
  kwriteconfig5 --file ~/.config/kdeglobals --group KDE --key widgetStyle Breeze

  kwriteconfig5 --file ~/.kde4/share/config/kdeglobals --group General --key ColorScheme Qogir
  kwriteconfig5 --file ~/.kde4/share/config/kdeglobals --group General --key Name Qogir
  kwriteconfig5 --file ~/.kde4/share/config/kdeglobals --group General --key widgetStyle Breeze
  kwriteconfig5 --file ~/.kde4/share/config/kdeglobals --group Icons --key Theme Numix-Circle

  kwriteconfig5 --file ~/.config/kwinrc --group Plugins --key magiclampEnabled true
  kwriteconfig5 --file ~/.config/kwinrc --group Plugins --key kwin4_effect_squashEnabled false
  
  kwriteconfig5 --file ~/.config/kwinrc --group TabBox --key BorderActivate 9
  kwriteconfig5 --file ~/.config/kwinrc --group TabBox --key DesktopLayout org.kde.breeze.desktop
  kwriteconfig5 --file ~/.config/kwinrc --group TabBox --key DesktopListLayout org.kde.breeze.desktop
  kwriteconfig5 --file ~/.config/kwinrc --group TabBox --key LayoutName org.kde.breeze.desktop

  kwriteconfig5 --file ~/.config/kwinrc --group org.kde.kdecoration2 --key BorderSize None
  kwriteconfig5 --file ~/.config/kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto false
  kwriteconfig5 --file ~/.config/kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight IAX
  kwriteconfig5 --file ~/.config/kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
  kwriteconfig5 --file ~/.config/kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__Qogir

  ##Settings / Plasma Style
  kwriteconfig5 --file ~/.config/plasmarc --group Theme --key name Qogir-dark
  
  ##Settings / Screen Locker
  kwriteconfig5 --file ~/.config/kscreenlockerrc --group Greeter --key Theme com.github.vinceliuice.Qogir
  kwriteconfig5 --file ~/.config/kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.potd
  kwriteconfig5 --file ~/.config/kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.potd --group General --key Category 1065374
  kwriteconfig5 --file ~/.config/kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.potd --group General --key Provider unsplash

  ##Settings / Application Style / GTK 3
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-application-prefer-dark-theme false
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-button-images true
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-cursor-theme-name breeze_cursors
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-decoration-layout :minimize,maximize,close
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-enable-animations true
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-fallback-icon-theme Adwaita
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-font-name 'Noto Sans, 10'
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-icon-theme-name Numix-Circle
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-menu-images true
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-modules colorreload-gtk-module
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-primary-button-warps-slider false
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-theme-name Qogir-win 
  kwriteconfig5 --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-toolbar-style 3

  ##Settings / Application Style / GTK 2
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-enable-animations 1
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-cursor-theme-name '"breeze_cursors"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-primary-button-warps-slider 0
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-cursor-theme-neme '"breeze_cursors"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-font-name '"Noto Sans,  10"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-theme-name '"Qogir-win"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-icon-theme-name '"Numix-Circle"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-fallback-icon-theme '"Adwaita"'
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-toolbar-style 3
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-menu-images 1
  kwriteconfig5 --file ~/.gtkrc-2.0 --group "" --key gtk-button-images 1

  
}

#TODO
rdpPackages-Config(){
  SESHNAME=""

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
  cp /etc/X11/xinit/xinitrc /home/${USERVARIABLES[USERNAME]}/.xinitrc
  sudo sed -i "s/twm &/#twm &/"
  sudo sed -i "s/xclock -geometry 50x50-1+1 &/#xclock -geometry 50x50-1+1 &/"
  sudo sed -i "s/xterm -geometry 80x50+494+51 &/#xterm -geometry 80x50+494+51 &/"
  sudo sed -i "s/exec xterm -geometry 80x66+0+0 -name login/#exec xterm -geometry 80x66+0+0 -name login/"

  echo "exec dbus-run-session -- $SESHNAME" > /home/${USERVARIABLES[USERNAME]}/.xinitrc
  sudo sed -i "s/use_vsock=true/use_vsock=false/" /etc/xrdp/xrdp.ini
}

if [[ $RUNCONFIG ]]; then
    $RUNCONFIG
fi