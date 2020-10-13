#!/bin/bash

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

  sudo mkinitcpio -p linux
  sudo systemctl enable qemu-ga.service
}

kdePackages-Config(){
  sudo systemctl enable sddm
  
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
  ROOTUUID=$(sudo blkid -s UUID -o value ${USERVARIABLES[ROOTPART]})

  sudo sed -i 's|^#GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/arch-silence/theme.txt"|' /etc/default/grub
  sudo sed -i 's|^GRUB_CMDLINE_LINUX="".*|GRUB_CMDLINE_LINUX="cryptdevice=UUID='${ROOTUUID}':root"|' /etc/default/grub
  sudo sed -i 's|^#GRUB_ENABLE_CRYPTODISK=y.*|GRUB_ENABLE_CRYPTODISK=y|' /etc/default/grub

  sudo grub-mkconfig -o /boot/grub/grub.cfg
}

notready-themePackages-Config(){
##Update sections
~/.config/kdeglobals
##
'[General]
ColorScheme=Qogir
Name=Qogir
XftHintStyle=hintslight
XftSubPixel=rgb
shadeSortColumn=true
toolBarFont=Noto Sans,10,-1,5,50,0,0,0,0,0

[Icons]
Theme=Qogir

[KDE]
AnimationDurationFactor=0.5
LookAndFeelPackage=com.github.vinceliuice.Qogir
ShowDeleteCommand=false
contrast=0
widgetStyle=Breeze'

##update section
~/.config/kwinrc
##
'[org.kde.kdecoration2]
BorderSize=None
BorderSizeAuto=false
ButtonsOnLeft=
ButtonsOnRight=IAX
library=org.kde.kwin.aurorae
theme=__aurorae__svg__Qogir'

##create
~/.config/plasmarc
##
'name=Qogir'

##append
~/.config/kscreenlockerrc
##
'Theme=com.github.vinceliuice.Qogir'

##delete and create file
~/.config/xsettingsd/xsettingsd.conf
##
'Net/ThemeName "Qogir-win"
Gtk/EnableAnimations 1
Gtk/DecorationLayout ":minimize,maximize,close"
Gtk/PrimaryButtonWarpsSlider 0
Gtk/ToolbarStyle 3
Gtk/MenuImages 1
Gtk/ButtonImages 1
Gtk/CursorThemeName "breeze_cursors"
Net/IconThemeName "Numix-Circle"
Gtk/FontName "Noto Sans,  10" '

##delete and create file
~/.config/gtk-3.0/settings.ini
##
'[Settings]
gtk-application-prefer-dark-theme=false
gtk-button-images=true
gtk-cursor-theme-name=breeze_cursors
gtk-decoration-layout=:minimize,maximize,close
gtk-enable-animations=true
gtk-fallback-icon-theme=Adwaita
gtk-font-name=Noto Sans,  10
gtk-icon-theme-name=Numix-Circle
gtk-menu-images=true
gtk-modules=colorreload-gtk-module
gtk-primary-button-warps-slider=false
gtk-theme-name=Qogir-win
gtk-toolbar-style=3'

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
