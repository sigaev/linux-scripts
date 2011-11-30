cp ../usr/share/zoneinfo/America/New_York localtime
ln -sfn /proc/self/mounts mtab
ln -sfn ../boot ../lib/modules
mkdir -m755 ../mnt/crypt
echo -e "ubuntu:x:6666:10::/:/bin/bash\n$user:x:1000:100:$name:/home/$user:/bin/bash" >>passwd
echo -e "ubuntu:!:10770:0:::::\n$user::10770:0:::::" >>shadow
cat <<EOF >>sudoers
Defaults:$user	env_keep=MC_FORMAT
$user	ALL=NOPASSWD:/usr/local/sbin/mount-crypt.sh,/usr/local/sbin/umount-crypt.sh,/sbin/reboot,/sbin/shutdown,/bin/passwd
EOF
cat <<EOF >local.d/90user.start
#!/bin/bash
if [[ ! -e /home/$user ]] && mkdir -m755 /home/$user; then
	cd /home/$user
	chown $user:users .
	su -c '
		for i in \`wget -qO- $cfg/Makefile | grep list= | cut -d= -f2\`; do
			wget -qO- $cfg/\$i.txz | tar xJ
		done
	' - $user
fi
EOF
chmod +x local.d/90user.start
mount -r /opt/VirtualBox/additions/VBoxGuestAdditions.iso /mnt
/mnt/VBoxLinuxAdditions.run
umount /mnt
mv X11/xorg.conf{,~}
for i in wheel audio video cdrom plugdev vboxusers; do gpasswd -a $user $i; done
(cd init.d; ln -sfn net.lo net.eth0)
for i in dbus metalog acpid cryptmount cryptnmount ntpd net.eth0 sshd; do
	rc-update add $i default
done
for i in dmcrypt consolefont alsasound; do
	rc-update add $i boot
done
rc-update add first sysinit
rc-update delete mtab boot
