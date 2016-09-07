#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

kexec-reload() {
  [[ $1 ]] || { echo "Usage: kexec-reload GRUB_ENTRY" >&2; return 1; }
  local e=$(bash <(awk "{if (\$1 == \"menuentry\") a += 1}
                        {if (a == $1 + 1 && \$1 != \"menuentry\" &&
                             \$1 != \"}\") print}" \
         /boot/grub2/grub.cfg | \
         sed 's,^[ \t]*set ,,;s,linux,echo,;s,initrd,true,'))
  local g=/boot`cut -d\  -f1 <<<$e`
  tee /var/tmp/kexec-reload <<EOF
exec /usr/bin/kexec -l $g --initrd=${g%vmlinuz.efi}initrd.lz \\
                    --command-line='`cut -d\  -f2- <<<$e`'
EOF
  systemctl kexec
}

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
