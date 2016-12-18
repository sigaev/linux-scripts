# This installs Arch into a newly created temporary directory.
#
# How to use:
# 1. Run.
# 2. Run "mount". There should be exactly one new mount (let's call it $MNT).
# 3. passwd; passwd sigaev
# 4. Copy $MNT to a new Btrfs snapshot.
# 5. Add the new boot option. Example kernel command line:
#    BOOT_IMAGE=/boot/vmlinuz.efi audit=0 \
#    modprobe.blacklist=evbug,nouveau,nvidiafb root=LABEL=root \
#    rootflags=noatime,ssd,discard,compress=zlib,subvol=2016-09-03-arch-rw \
#    systemd.setenv=SUBVOL_BOOT=64-16.04
# 6. Think about how to eliminate step (3).
#
# To use compiz:
# xfconf-query -c xfce4-session -p /sessions/Failsafe/Client0_Command -sa compiz

install_log=`mktemp`
(
  set -x
  host=mirrors.lug.mtu.edu
  url=$host/archlinux/iso/latest
  sha1name=`curl -Ls $url/sha1sums.txt | grep -m1 x86_64`
  name=`awk '{print $2}' <<<$sha1name`
  mounts="proc dev sys etc/resolv.conf"
  wifi=wlp3s0

  kill-chroot-processes() {
    while true; do
      kills=`find /proc -maxdepth 2 -name root | xargs ls -Udo 2>/dev/null | grep tmp | cut -d/ -f3`
      if [[ -z $kills ]]; then break; fi
      kill $kills
    done
  }

  umask 022
  old_dir=`mktemp -d`
  mount -omode=755 {-t,}tmpfs $old_dir
  mount --make-private $old_dir
  cd $old_dir
  curl {-Lso,$url/}$name
  sha1sum -c - <<<$sha1name
  tar xzf $name
  rm -f $name
  cd *
  dir=`mktemp -dp tmp`
  mount -omode=755 {-t,}tmpfs $dir
  keys_exist=false
  if [[ -e /etc/pacman.d/gnupg ]]; then
    keys_exist=true
    cp -a /etc/pacman.d/gnupg etc/pacman.d/
  fi
  sed -i /$host/s,^.,, etc/pacman.d/mirrorlist
  $keys_exist || sed -i 's,^SigLevel.*,SigLevel = Optional TrustAll,' etc/pacman.conf
  for i in $mounts; do mount -B {/,}$i; done
  chroot . bash -c "$keys_exist || pacman-key --init
                    pacstrap $dir base"
  kill-chroot-processes
  mkdir /$dir
  mount -M {,/}$dir
  umount $mounts && cd ../.. && umount $old_dir && rmdir $old_dir

  cd /$dir
  $keys_exist && cp -a /etc/pacman.d/gnupg etc/pacman.d/
  cat >etc/systemd/system/boot.mount <<EOF
[Unit]
Description=Boot Directory
DefaultDependencies=no
ConditionVirtualization=!container
Conflicts=umount.target
After=swap.target

[Mount]
What=LABEL=root
Where=/boot
Type=auto
Options=ro,noatime,ssd,discard,compress=zlib

[Install]
RequiredBy=usr-lib-modules.mount
EOF
  cat >etc/systemd/system/usr-lib-modules.mount <<EOF
[Unit]
Description=Modules Directory
DefaultDependencies=no
ConditionVirtualization=!container
Conflicts=umount.target
Before=local-fs.target umount.target kexec.target systemd-udev-trigger.service systemd-udevd.service
After=boot.mount

[Mount]
What=/boot/\${SUBVOL_BOOT}
Where=/usr/lib/modules
Options=bind

[Install]
RequiredBy=systemd-udevd.service
EOF
  cat >etc/systemd/system/kexec-reload.service <<EOF
[Unit]
Description=restart the current kernel
Documentation=man:kexec(8)
DefaultDependencies=no
Before=shutdown.target umount.target final.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash /var/tmp/kexec-reload

[Install]
WantedBy=kexec.target
EOF
  cat >etc/systemd/system/pkg.service <<EOF
[Unit]
Description=packages that come with the kernel
Documentation=man:makepkg(8)
ConditionVirtualization=!container
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'yes | pacman -U --needed --confirm /usr/lib/modules/pkg/*'

[Install]
WantedBy=multi-user.target
EOF
  for i in $mounts; do mount -B {/,}$i; done
  pipe=`mktemp -up tmp`
  mkfifo $pipe
  chroot . bash <(cat <<EOF
    set -x
    $keys_exist || pacman-key --populate archlinux
    echo en_US.UTF-8 UTF-8 >etc/locale.gen
    echo LANG=en_US.UTF-8 >etc/locale.conf
    locale-gen
    pacman --noconfirm -Syu iw wpa_supplicant ntp alsa-utils base-devel vim \
                            xfce4 xorg-server kexec-tools git cpio wget \
                            xf86-input-libinput btrfs-progs graphviz xorg-xhost \
                            squashfs-tools rsync noto-fonts-cjk tk unrar eog \
                            evince libvdpau
    for i in linux; do
      pacman --noconfirm -Rs \$i --assume-installed \`pacman -Q \$i | tr \\  =\`
    done
    systemctl enable ntpd "wpa_supplicant@$wifi" systemd-networkd {boot,usr-lib-modules}.mount kexec-reload pkg
    groupadd -g 5000 eng
    useradd -g eng -u 172504 sigaev
    echo 'sigaev ALL=(ALL) NOPASSWD: ALL' >etc/sudoers.d/tmp
    echo 'set -x
          cd var/tmp
          for i in compiz google-chrome; do
            curl -Ls https://aur.archlinux.org/cgit/aur.git/snapshot/\$i.tar.gz | tar xz
            (cd \$i && makepkg --noconfirm -s)
          done' >$pipe &
    su sigaev -c 'bash $pipe'
    wait
    find var/tmp -name '*.pkg.tar.xz' | xargs -r pacman --noconfirm -U
    rm -fr $pipe etc/sudoers.d/tmp var/{tmp,cache/pacman/pkg}/*
    pacman -Qtdq | xargs -r pacman --noconfirm -Rns
    for i in fonts-windows aws cryptmount; do
    (
      cd /tmp
      curl -Ls https://github.com/sigaev/\$i/tarball/HEAD | tar xz
      cd sigaev-\$i-* && make && rm -fr \`pwd\`
    )
    done
EOF
  )
  kill-chroot-processes
  umount $mounts
  ln -sfn /mnt/secret/etc/wpa_supplicant/wpa_supplicant.conf \
                      etc/wpa_supplicant/wpa_supplicant-$wifi.conf
  ln -sfn ../usr/share/zoneinfo/America/New_York etc/localtime
  mkdir usr/lib/modules
  ln -sfn modules/firmware usr/lib/firmware
  cat >>etc/fstab <<EOF
none       /     auto  noatime,ssd,discard,compress=zlib              0 0
LABEL=home /home auto  noatime,ssd,discard,compress=zlib,subvol=arch  0 2
LABEL=home /mnt  auto  noatime,ssd,discard,compress=zlib              0 2
EOF
  cat >etc/systemd/network/wireless.network <<EOF
[Match]
Name=$wifi

[Network]
DHCP=ipv4
EOF
  cp usr/lib/systemd/system/getty\@.service \
         etc/systemd/system/autologin\@.service
  ln -sfn /etc/systemd/system/autologin\@.service \
           etc/systemd/system/getty.target.wants/getty\@tty1.service
  patch -p1 <<'EOF'
diff --git a/etc/systemd/system/autologin@.service b/etc/systemd/system/autologin@.service
index 9b99f95..2c90aa5 100644
--- a/etc/systemd/system/autologin@.service
+++ b/etc/systemd/system/autologin@.service
@@ -30,7 +30,7 @@ ConditionPathExists=/dev/tty0
 
 [Service]
 # the VT is cleared by TTYVTDisallocate
-ExecStart=-/sbin/agetty --noclear %I $TERM
+ExecStart=-/sbin/agetty -a sigaev --noclear %I $TERM
 Type=idle
 Restart=always
 RestartSec=0
EOF
  cat >etc/X11/xorg.conf <<'EOF'
Section "ServerLayout"
    Identifier     "Default Layout"
    Screen         "Screen[0]" 0 0
    InputDevice    "Keyboard0" "CoreKeyboard"
    InputDevice    "Mouse0" "CorePointer"
EndSection

Section "InputDevice"
    Identifier     "Keyboard0"
    Driver         "keyboard"
EndSection

Section "InputDevice"
    Identifier     "Mouse0"
    Driver         "mouse"
    Option         "Protocol" "auto"
    Option         "Device" "/dev/psaux"
    Option         "Emulate3Buttons" "no"
    Option         "ZAxisMapping" "4 5"
EndSection

Section "Monitor"
    Identifier     "Monitor[0]"
    VendorName     "Oracle Corporation"
    ModelName      "VirtualBox Virtual Output"
EndSection

Section "Device"
    Identifier     "Device0"
    Driver         "nvidia"
    Option         "RegistryDwords" "EnableBrightnessControl=1"
    VendorName     "NVIDIA Corporation"
EndSection

Section "Screen"
    Identifier     "Screen[0]"
    Device         "Device[0]"
    Monitor        "Monitor[0]"
    SubSection     "Display"
    EndSubSection
EndSection
EOF
  cat >etc/X11/xorg.conf.d/30-keyboard.conf <<'EOF'
Section "InputClass"
  Identifier "Keyboard0"
  Option "XkbModel" "pc104"
  Option "XkbLayout" "us,ru"
  Option "XkbVariant" "winkeys"
  Option "XkbOptions" "grp:caps_toggle"
  MatchIsKeyboard "on"
EndSection
EOF
  (umask 077; echo '%eng ALL=(ALL) ALL' >etc/sudoers.d/eng)
  echo nameserver 8.8.8.8 >etc/resolv.conf

  echo /$dir
) 2>&1 | tee $install_log
(
  umask 022
  install_log_xz=`tail -n1 $install_log`/var/log/install.log.xz
  xz -c $install_log >$install_log_xz
  rm -f $install_log
)
