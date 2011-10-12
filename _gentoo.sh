cd etc
git diff origin/stage3...origin/patch-stage3 | git apply || exit 1
emerge -e world || exit 1
emerge $(<.git/info/world) || exit 1
git diff origin/emerged...origin/master | git apply || exit 1
echo Ok.
