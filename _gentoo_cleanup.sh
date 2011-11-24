rm -fr ../var/portage/distfiles/* ../var/tmp/* ../tmp/*

for i in . .git/scripts; do
(
	cd $i
	git gc --aggressive --prune=2020
	git update-server-info
	git status
)
done

if [[ `git log -n1 --pretty=format:%H patch` != `git log -n1 --pretty=format:%H origin/patch` ]]; then
(
	mkdir ../tmp/a
	cd ../tmp/a || exit 1
	cp -a "$OLDPWD/.git" .
	git reset --hard patch
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
