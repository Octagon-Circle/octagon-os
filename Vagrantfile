# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = 4
  end

  config.vm.synced_folder ".", "/vagrant"

  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y live-build debootstrap squashfs-tools xorriso \
      grub-efi-amd64-bin grub-pc-bin syslinux syslinux-common isolinux mtools dosfstools
    echo "Ready! To build the ISO run: cd /vagrant && sudo ./build.sh"
  SHELL
end
