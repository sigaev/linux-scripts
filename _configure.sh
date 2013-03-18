ln -sfn /proc/self/mounts mtab
ln -sfn ../{boot,lib}/firmware
ln -sfn ../boot ../lib/modules
ln -s ../../boot/secret/etc/wpa_supplicant/wpa_supplicant.conf wpa_supplicant/
ln -s /home/$user/sandbox/doom3/base/{game00,pak00{0..4}}.pk4 /opt/doom3/base/
groupadd -g 5000 eng
echo -e "ubuntu:x:6666:10::/:/bin/bash\n$user:x:172504:5000:$name:/home/$user:/bin/bash" >>passwd
echo -e "ubuntu:!:10770:0:::::\n$user::10770:0:::::" >>shadow
cat <<EOF >>sudoers
Cmnd_Alias	NOTTY=/etc/local.d/pm-suspend,/etc/init.d/cryptnmount
Defaults	requiretty
Defaults!NOTTY	!requiretty
Defaults:$user	env_keep=MC_FORMAT
$user	ALL=NOPASSWD:ALL
EOF
cat <<EOF >conf.d/hostname
hostname="$arch"
EOF
cat <<EOF >init.d/last
#!/sbin/runscript

depend() {
	need net
	use dns
}

start() {
	if [[ ! -e /home/$user ]]; then
		ebegin "Downloading settings from the web"
		for i in {1..40}; do
			if service_started net.eth0 || service_started net.wlan0; then
				break
			fi
			sleep 1
		done
		mkdir -m755 /home/$user
		chown $user:eng /home/$user
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
bits=`file /bin/bash | grep -v x86-64`
${bits:+i386} /mnt/VBoxLinuxAdditions.run
umount /mnt
for i in wheel audio video cdrom plugdev games vboxusers; do gpasswd -a $user $i; done
(cd init.d; ln -sfn net.lo net.eth0; ln -sfn net.lo net.wlan0)
for i in dbus metalog acpid cryptmount cryptnmount last net.eth0 net.wlan0 vboxservice ntpd sshd; do
	rc-update add $i default
done
for i in dmcrypt consolefont alsasound; do
	rc-update add $i boot
done
for i in first; do
	rc-update add $i sysinit
done
rc-update delete mtab boot
