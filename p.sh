#!/bin/bash

read -p "Enter new username: " username
read -s -p "Enter password for sudo: " sudopassword
echo

read -p "Enter new hostname: " hostname
read -p "Enter path to EFI partition: " efi_path
read -p "Enter path to swap partition (leave empty if none): " swap_path
read -p "Enter path to Linux system partition: " system_path

mkfs.vfat -F32 $efi_path
[ ! -z "$swap_path" ] && { mkswap $swap_path && swapon $swap_path; }
mkfs.btrfs $system_path

mount -o noatime,ssd,space_cache=v2,compress=zstd,discard=async $system_path /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
umount /mnt
mount -o noatime,ssd,space_cache=v2,compress=zstd,discard=async $system_path /mnt
mount -o noatime,ssd,space_cache=v2,compress=zstd,discard=async,subvol=@home $system_path /mnt/home
mkdir -p /mnt/boot/efi
mount $efi_path /mnt/boot/efi

reflector -c Indonesia -a 6 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Sy
pacstrap -K /mnt base linux linux-firmware intel-ucode btrfs-progs git nano grub grub-btrfs efibootmgr networkmanager network-manager-applet wpa_supplicant dialog reflector base-devel linux-headers bluez bluez-utils alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack bash-completion rsync acpi acpi_call tlp acpid nvidia-open-dkms nvidia-utils nvidia-settings man neofetch

genfstab -U /mnt | tee -a /mnt/etc/fstab

arch-chroot /mnt bash -c "ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime; hwclock --systohc; sed -i 's/^#\(en_US.UTF-8 UTF-8\)$/\1/' /etc/locale.gen; locale-gen; echo 'LANG=en_US.UTF-8' >> /etc/locale.conf; echo '$hostname' > /etc/hostname; grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB; grub-mkconfig -o /boot/grub/grub.cfg; systemctl enable NetworkManager; systemctl enable bluetooth; systemctl enable tlp; systemctl enable reflector.timer; systemctl enable fstrim.timer; systemctl enable acpid; useradd -m -G wheel $username; echo '$username:$sudopassword' | chpasswd; echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers.d/$username; usermod -c '$username' $username"

umount -R /mnt
exit
reboot
