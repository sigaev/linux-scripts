umask 022
export COLUMNS=80
cd etc

. .git/scripts/_emerge_env.sh

configs() {
	find -name ._cfg\* | while read e; do
		mv "$e" "`sed s/._cfg[0-9]*_// <<<$e`"
	done
}

eselect profile set 1
touch /dev/shm/emerge.patch
patch -p1 -i/dev/shm/emerge.patch || exit 1

if emerge -pv gcc | grep -q NS; then
	old_gcc=$(gcc-config -S $(gcc-config -c) | cut -d\  -f2)
	emerge -1u gcc && gcc-config 2 || exit 1
	env-update && . profile
	emerge -C =sys-devel/gcc-$old_gcc && emerge -1 libtool || exit 1
fi

emerge -1 binutils || exit 1
emerge -e --keep-going git world || exit 1
emerge -c || exit 1
rm -fr ../var/portage/distfiles/*

patch -Rp1 -i/dev/shm/emerge.patch || exit 1

git checkout stage3 || exit 1
configs
git commit -amAuto-update
git rebase stage3 root || exit 1
git rebase root _ || exit 1

patch -p1 -i/dev/shm/emerge.patch || exit 1

groupadd -g 999 vboxusers
. .git/scripts/_programs.sh
DONT_MOUNT_BOOT=1 arch= emerge -N --keep-going $(<.git/scripts/world) || exit 1
emerge -c || exit 1
rm -fr ../var/portage/distfiles/*

patch -Rp1 -i/dev/shm/emerge.patch || exit 1

git diff _ root | git apply
configs
patches root master

branches stage3,master | while read i; do
	git rebase --onto root origin/root $i || exit 1
done

git checkout master || exit 1
git branch -D origin/root root _
branches | while read i; do
	git tag -f base/$i $i
done
git merge $arch || exit 1

cp .git/scripts/world{,~}
patch -p1 -i/dev/shm/emerge.patch || exit 1
rm -f /dev/shm/emerge.patch
mv .git/scripts/world{~,}

env-update

. .git/scripts/_configure.sh
. .git/scripts/_bugs.sh
. .git/scripts/_cleanup.sh

exit 0
