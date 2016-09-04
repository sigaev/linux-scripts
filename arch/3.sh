(
  mounts="proc dev sys etc/resolv.conf"

  cd /tmp/mnt
  for i in $mounts; do mount -B {/,}$i; done
  chroot . bash <(cat <<EOF
EOF
  )
  while true; do
    kills=`find /proc -maxdepth 2 -name root | xargs ls -Udo 2>/dev/null | grep tmp | cut -d/ -f3`
	if [[ -z $kills ]]; then break; fi
	kill $kills
  done
  umount $mounts
)
