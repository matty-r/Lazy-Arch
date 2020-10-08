#!/bin/bash

vboxGuestPackages-Config(){
  sudo systemctl enable vboxservice.service
  echo "\"FS0:\EFI\refind\refind_x64.efi\"" | sudo tee -a /boot/startup.nsh
}

qemuGuestPackages-Config(){
  sudo sed -i "s/MODULES=()/MODULES=(virtio virtio_blk virtio_pci virtio_net)/" /etc/mkinitcpio.conf
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

#TODO
rdpPackages-Config(){
  SESHNAME=""

  sudo systemctl enable xrdp xrdp-sesman

  echo "allowed_users=anybody" | sudo tee /etc/X11/Xwrapper.config
  case ${USERVARIABLES[DESKTOP]} in
    "kde" ) SESHNAME="startkde"
      ;;
    "xfce" ) SESHNAME="startxfce4"
      ;;
    "gnome" ) SESHNAME="gnome-session"
      ;;
  esac

  echo "exec dbus-run-session -- $SESHNAME" > /home/${USERVARIABLES[USERNAME]}/.xinitrc
  sudo sed -i "s/use_vsock=true/use_vsock=false/" /etc/xrdp/xrdp.ini
}
