umask 022
export COLUMNS=96
cd etc

diff -u <(git grep -h ^CHOST= origin/$arch make.conf) <(grep ^CHOST= make.conf) || exit 1
rm -f make.conf

branches() {
	git branch -r | cut -d/ -f2 | grep -vxf<(tr , \\n <<<$1)
}

git remote set-head origin -d
git branch -m master _
branches | while read i; do
	git branch $i origin/$i
done
git branch root `git merge-base $arch master`
git branch origin/root root

patches() {
	git reset $1
	[[ Auto-update == `git log -n1 --pretty=format:%f` ]] && git diff HEAD^ --quiet && git reset HEAD^
	git commit -amAuto-update
	git checkout -B $1
	git rebase --onto $1 origin/$1 $2 || exit 1
}
configs() {
	find -name ._cfg\* | while read e; do
		mv "$e" "`sed s/._cfg[0-9]*_// <<<$e`"
	done
}

patches stage3 root
git branch -f _ $arch
git rebase --onto root origin/root _ || exit 1

emerge -e world || exit 1
emerge -c || exit 1

git checkout stage3 || exit 1

configs
git commit -amAuto-update
git rebase stage3 root || exit 1
git rebase root _ || exit 1

groupadd -g 999 vboxusers
. .git/scripts/_programs.sh
emerge -1 media-video/ffmpeg || exit 1
DONT_MOUNT_BOOT=1 emerge -n $(<.git/scripts/world) || exit 1

git diff _ root | git apply
configs
patches root master

branches stage3,master | while read i; do
	git rebase --onto root origin/root $i || exit 1
done

git checkout master || exit 1
git branch -D origin/root root _
git merge $arch || exit 1

env-update

. .git/scripts/_configure.sh
. .git/scripts/_bugs.sh
. .git/scripts/_cleanup.sh
