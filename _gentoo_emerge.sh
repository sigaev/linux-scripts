umask 022
cd etc

branches() {
	git branch -r | egrep -v 'origin/(HEAD|master)' | cut -d/ -f2 | grep -vxf<(tr , \\n <<<$1)
}

branches | while read i; do
	git branch $i origin/$i
done
git branch root `git merge-base $arch emerge`
git branch origin-root root

patches() {
	git reset $1
	[[ Auto-update == `git log -n1 --pretty=format:%f` ]] && git diff HEAD^ --quiet && git reset HEAD^
	git commit -amAuto-update
	git checkout -B $1
	git rebase --onto $1 origin/$1 $2 || exit 1
}

patches stage3 root
git rebase --onto root origin-root $arch || exit 1

emerge -e world || exit 1

git checkout stage3 || exit 1
git branch -f $arch origin/$arch

find -name ._cfg\* | while read e; do
	mv "$e" "`sed s/._cfg[0-9]*_// <<<$e`"
done

git commit -amAuto-update
git rebase stage3 root || exit 1
branches stage3,patch | while read i; do
	git rebase --onto root origin-root $i || exit 1
done
git checkout -B master $arch

groupadd -g 999 vboxusers

emerge -n $(<.git/scripts/world) || exit 1

git diff master root | git apply
git branch -D origin-root root

patches emerge patch

git checkout -B master
git merge $arch || exit 1
for i in . .git/scripts; do
(
	cd $i
	git gc --aggressive --prune=2020
	git update-server-info
	git status
)
done

. .git/scripts/_gentoo_programs.sh
. .git/scripts/_gentoo_configure.sh
. .git/scripts/_gentoo_bugs.sh

rm -fr ../var/portage/distfiles/* ../var/tmp/* ../tmp/*

if [[ `git log -n1 --pretty=format:%H` != `git log -n1 --pretty=format:%H origin/master` ]]; then
(
	mkdir ../tmp/a
	cd ../tmp/a || exit 1
	cp -a "$OLDPWD/.git" .
	git reset --hard
	tar cJf ../a.txz --owner=$user --group=users .
	cd .. && rm -fr a && chown $user:users a.txz
)
fi
diff -u ../{etc/.git/scripts,var/lib/portage}/world 1>&2
cat 1>&2 <<EOF
Things that MUST be done:
	* pay attention to the above diff (if any), consider updating $git/scripts/world
	* examine the diff of /var/log/install.{out,err}.xz and previous versions
	* same with /etc/{passwd,group}
EOF
[[ -e ../tmp/a.txz ]] && cat 1>&2 <<EOF
	* update ${git%.git} with /tmp/a.txz
EOF
