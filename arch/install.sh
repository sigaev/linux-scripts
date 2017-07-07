# This installs Arch into a newly created temporary directory.
#
# How to use:
# 1. Run.
# 2. Run "mount". There should be exactly one new mount (let's call it $MNT).
# 3. passwd; passwd sigaev
# 4. Copy $MNT to a new Btrfs snapshot.
# 5. Add the new boot option to /boot/grub2/grub.cfg.
# 6. k=4.14.39; u=2018-05-03; efibootmgr -d /dev/nvme0n1 -c -L "arch $k $u" -l $k-vmlinuz.efi -u "audit=0 modprobe.blacklist=evbug,nouveau,nvidiafb,intel_ish_ipc root=LABEL=root rootflags=noatime,ssd,subvol=$u-arch-rw systemd.setenv=SUBVOL_BOOT=64-$k-rw initrd=$k-initrd.lz"
# 7. Think about how to eliminate step (3).
#
# To use compiz:
# xfconf-query -c xfce4-session -p /sessions/Failsafe/Client0_Command -sa compiz

install_log=`mktemp`
(
  set -x
  host=arch.mirror.constant.com
  url=https://$host/iso/latest
  sha1name=`curl -Ls $url/sha256sums.txt | grep -m1 tar`
  name=`awk '{print $2}' <<<$sha1name`
  mounts="proc dev sys etc/resolv.conf"
  wifi=wlp1s0

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
  sha256sum -c - <<<$sha1name
  tar xaf $name
  rm -f $name
  cd *
  dir=`mktemp -dp tmp`
  mount -omode=755,size=70% {-t,}tmpfs $dir
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
  for i in $mounts; do mount -B {/,}$i; done
  pipe=`mktemp -up tmp`
  mkfifo $pipe
  chroot . bash <(cat <<EOF
    set -x
    $keys_exist || pacman-key --populate archlinux
    echo en_US.UTF-8 UTF-8 >etc/locale.gen
    echo LANG=en_US.UTF-8 >etc/locale.conf
    locale-gen
    pacman --noconfirm -Syu iw wpa_supplicant ntp alsa-utils base-devel vim cscope zsh \
                            xfce4 xorg-{server,xset,xrandr} kexec-tools git cpio wget \
                            xf86-input-libinput btrfs-progs graphviz xorg-xhost sudo \
                            squashfs-tools rsync noto-fonts-cjk tk unrar unzip eog \
                            evince libvdpau mplayer python ipython jansson efibootmgr \
                            openssh bazel cmake go clang gdb dosfstools tensorflow \
                            python-tensorflow libxslt
    for i in linux; do
      pacman --noconfirm -Rs \$i --assume-installed \`pacman -Q \$i | tr \\  =\`
    done
    systemctl enable ntpd "wpa_supplicant@$wifi" systemd-networkd {boot,usr-lib-modules}.mount kexec-reload
    groupadd -g 5000 eng
    useradd -g eng -u 172504 sigaev
    echo 'sigaev ALL=(ALL) NOPASSWD: ALL' >etc/sudoers.d/tmp
    echo 'set -x
          cd var/tmp
          wget s3.amazonaws.com/sigaev/linux/icaclient-99.9-1-x86_64.pkg.tar.xz
          for i in compiz google-chrome; do
            curl -Ls https://aur.archlinux.org/cgit/aur.git/snapshot/\$i.tar.gz | tar xz
            (cd \$i && sed -i "s,^ *make$,make -j$(grep -c ^processor /proc/cpuinfo)," PKGBUILD && makepkg --noconfirm -s)
          done' >$pipe &
    su sigaev -c 'bash $pipe'
    wait
    find var/tmp -name '*.pkg.tar.zst' | xargs -r pacman --noconfirm -U
    rm -fr $pipe etc/sudoers.d/tmp var/{tmp,cache/pacman/pkg}/*
    pacman -Qtdq | xargs -r pacman --noconfirm -Rns
    for i in fonts-windows aws cryptmount; do
    (
      cd /tmp
      curl -Ls https://github.com/sigaev/\$i/tarball/HEAD | tar xz
      cd sigaev-\$i-* && make && rm -fr \`pwd\`
    )
    done
    bash <(curl https://sdk.cloud.google.com) --disable-prompts --install-dir=opt/google
    opt/google/google-cloud-sdk/bin/gcloud components install --quiet app-engine-go kubectl
    mkdir -p var/cache/fontconfig/sigaev
    chown sigaev:eng var/cache/fontconfig/sigaev
EOF
  )
  kill-chroot-processes
  umount $mounts
  ln -sfn /home/secret/etc/wpa_supplicant/wpa_supplicant.conf \
                       etc/wpa_supplicant/wpa_supplicant-$wifi.conf
  ln -sfn ../usr/share/zoneinfo/America/Los_Angeles etc/localtime
  mkdir efi usr/lib/modules
  ln -sfn modules/firmware usr/lib/firmware
  cat >>etc/fstab <<EOF
none       /     auto  noatime,ssd              0 0
PARTLABEL=EFI\\040system\\040partition /efi auto ro,noatime 0 2
LABEL=root /home auto  noatime,ssd,subvol=home  0 2
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
  sed -i 's,^ExecStart.*$,ExecStart=-/sbin/agetty -a sigaev --noclear %I $TERM,' etc/systemd/system/autologin\@.service
  sed -i s,Restart=always,Restart=no, etc/systemd/system/autologin\@.service
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
