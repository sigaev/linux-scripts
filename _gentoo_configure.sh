cp ../usr/share/zoneinfo/America/New_York localtime
ln -sfn /proc/self/mounts mtab
mkdir -m755 ../mnt/crypt
echo 'sigaev:x:1000:100:Dmitry Sigaev:/home/sigaev:/bin/bash' >>passwd
echo 'sigaev::10770:0:::::' >>shadow
cat <<EOF >>sudoers
Defaults:sigaev	env_keep=MC_FORMAT
sigaev	ALL=NOPASSWD:/usr/local/sbin/mount-crypt.sh,/usr/local/sbin/umount-crypt.sh,/sbin/reboot,/bin/passwd
EOF
for i in wheel audio video plugdev; do gpasswd -a sigaev $i; done
(cd init.d; ln -sfn net.lo net.eth0)
for i in dbus metalog acpid cryptmount cryptnmount ntpd net.eth0; do
	rc-update add $i default
done
for i in dmcrypt consolefont alsasound; do
	rc-update add $i boot
done
rc-update delete mtab boot
