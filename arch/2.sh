#pacman -U google-chrome-52.0.2743.116-1-x86_64.pkg.tar.xz
curl -s https://aur.archlinux.org/cgit/aur.git/snapshot/google-chrome.tar.gz | tar xz
cd google-chrome
makepkg -s


#xfconf-query -c xfce4-session -p /sessions/Failsafe/Client0_Command -sa compiz
