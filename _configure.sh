cp ../usr/share/zoneinfo/America/New_York localtime
ln -sfn /proc/self/mounts mtab
ln -sfn ../{boot,lib}/firmware
ln -sfn ../boot ../lib/modules
ln -s ../../boot/secret/etc/wpa_supplicant/wpa_supplicant.conf wpa_supplicant/
mkdir ../mnt/crypt
echo -e "ubuntu:x:6666:10::/:/bin/bash\n$user:x:1000:100:$name:/home/$user:/bin/bash" >>passwd
echo -e "ubuntu:!:10770:0:::::\n$user::10770:0:::::" >>shadow
cat <<EOF >>sudoers
Defaults:$user	env_keep=MC_FORMAT
$user	ALL=NOPASSWD:/usr/local/sbin/mount-crypt.sh,/usr/local/sbin/umount-crypt.sh,/sbin/reboot,/sbin/shutdown,/bin/passwd
EOF
cat <<EOF >init.d/last
#!/sbin/runscript

depend() {
	need net
	use dns
}

start() {
	if [[ ! -e /home/$user ]] && mkdir -m755 /home/$user; then
		ebegin "Downloading settings from the web"
		chown $user:users /home/$user
		su -c '
			wget -T9 -t3 -qO- $cfg/Makefile | grep list= | cut -d= -f2 | tr \\  \\\n \
				| sed s,$,.txz, | wget -T9 -t3 -qO- -B$cfg/ -i- | tar xiJ
		' - $user
		rmdir /home/$user 2>/dev/null
		eend \$((! \$?)) "Failed to download settings from the web"
	fi
}
EOF
chmod +x init.d/last
mount -r /opt/VirtualBox/additions/VBoxGuestAdditions.iso /mnt
bits=`file /bin/bash | grep -v 64`
${bits:+i386} /mnt/VBoxLinuxAdditions.run
umount /mnt
mv X11/xorg.conf{,~}
for i in wheel audio video cdrom plugdev vboxusers; do gpasswd -a $user $i; done
(cd init.d; ln -sfn net.lo net.eth0; ln -sfn net.lo net.wlan0)
for i in dbus metalog acpid cryptmount cryptnmount last ntpd net.eth0 net.wlan0 allnet sshd; do
	rc-update add $i default
done
for i in dmcrypt consolefont alsasound; do
	rc-update add $i boot
done
rc-update add first sysinit
rc-update delete mtab boot
