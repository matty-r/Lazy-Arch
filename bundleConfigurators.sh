#!/bin/bash
# bundleConfigurators

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

  #enable SDDM and set autologin, also set theme to breeze
  sudo systemctl enable sddm
  sudo mkdir /etc/sddm.conf.d

  cat << EOF | sudo tee -a /etc/sddm.conf.d/kde_settings.conf
[Autologin]
Relogin=false
Session=plasma
User=

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
EOF

  sudo sed -i 's|^User=.*|User='${USERVARIABLES[USERNAME]}'|' /etc/sddm.conf.d/kde_settings.conf

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

  ##temporary fix for the dark theme colours being incorrect
  sudo cp /usr/share/color-schemes/Qogirdark.colors /usr/share/plasma/desktoptheme/Qogir-dark/colors

##Apply the themes to qogir and icons set to numix
cat << EOF | tee ~/.config/kdeglobals
[General]
ColorScheme=Qogir
Name=Qogir
XftHintStyle=hintslight
XftSubPixel=rgb
shadeSortColumn=true
toolBarFont=Noto Sans,10,-1,5,50,0,0,0,0,0

[Icons]
Theme=Numix-Circle

[KDE]
AnimationDurationFactor=0.5
LookAndFeelPackage=com.github.vinceliuice.Qogir
ShowDeleteCommand=false
contrast=0
widgetStyle=Breeze
EOF

cat << EOF | tee ~/.kde4/share/config/kdeglobals
[General]
ColorScheme=Qogir
Name=Qogir
font=Noto Sans,10,-1,5,50,0,0,0,0,0
menuFont=Noto Sans,10,-1,5,50,0,0,0,0,0
shadeSortColumn=true
smallestReadableFont=Noto Sans,8,-1,5,50,0,0,0,0,0
toolBarFont=Noto Sans,10,-1,5,50,0,0,0,0,0
widgetStyle=Breeze

[Icons]
Theme=Numix-Circle
EOF

cat << EOF | tee ~/.config/kwinrc
[Compositing]
OpenGLIsUnsafe=false

[Effect-Cube]
BorderActivateCylinder=9
BorderActivateSphere=9

[Effect-DesktopGrid]
BorderActivate=7

[Effect-PresentWindows]
BorderActivate=3
BorderActivateAll=9
BorderActivateClass=9

[ElectricBorders]
Bottom=None
BottomRight=None
Right=None
Top=None
TopLeft=None
TopRight=None

[Plugins]
kwin4_effect_squashEnabled=false
magiclampEnabled=true

[TabBox]
BorderActivate=9
DesktopLayout=org.kde.breeze.desktop
DesktopListLayout=org.kde.breeze.desktop
LayoutName=org.kde.breeze.desktop

[Windows]
ElectricBorderCooldown=350
ElectricBorderCornerRatio=0.25
ElectricBorderDelay=150
ElectricBorderMaximize=true
ElectricBorderTiling=true
ElectricBorders=0

[org.kde.kdecoration2]
BorderSize=None
BorderSizeAuto=false
ButtonsOnLeft=
ButtonsOnRight=IAX
library=org.kde.kwin.aurorae
theme=__aurorae__svg__Qogir
EOF

##create
cat << EOF | tee ~/.config/plasmarc
name=Qogir
EOF

##append
cat << EOF | tee -a ~/.config/kscreenlockerrc
Theme=com.github.vinceliuice.Qogir
EOF

##delete and create file
cat << EOF | tee ~/.config/xsettingsd/xsettingsd.conf
Net/ThemeName "Qogir-win"
Gtk/EnableAnimations 1
Gtk/DecorationLayout ":minimize,maximize,close"
Gtk/PrimaryButtonWarpsSlider 0
Gtk/ToolbarStyle 3
Gtk/MenuImages 1
Gtk/ButtonImages 1
Gtk/CursorThemeName "breeze_cursors"
Net/IconThemeName "Numix-Circle"
Gtk/FontName "Noto Sans,  10"
EOF

##delete and create file
cat << EOF | tee ~/.config/gtk-3.0/settings.ini
[Settings]
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
gtk-toolbar-style=3
EOF

cat << EOF | tee ~/.gtkrc-2.0
gtk-enable-animations=1

gtk-cursor-theme-name="breeze_cursors"

gtk-primary-button-warps-slider=0
gtk-cursor-theme-neme="breeze_cursors"
gtk-font-name="Noto Sans,  10"
gtk-theme-name="Qogir-win"
gtk-icon-theme-name="Numix-Circle"
gtk-fallback-icon-theme="Adwaita"
gtk-toolbar-style=3
gtk-menu-images=1
gtk-button-images=1
EOF

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
