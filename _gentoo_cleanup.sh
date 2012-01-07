rm -fr ../var/portage/distfiles/* ../var/tmp/* ../tmp/*

for i in . .git/scripts; do
(
	cd $i
	git gc --aggressive
	git update-server-info
	git status
)
done

diff -u ../{etc/.git/scripts,var/lib/portage}/world 1>&2
cat 1>&2 <<EOF
Things that MUST be done:
	* pay attention to the above diff (if any), consider updating $git/scripts/world
	* examine the diff of /var/log/install.{out,err}.xz and previous versions
	* same with /etc/{passwd,group}
	* once it's clear the release is solid, update ${git%.git} with /etc/.git
EOF
[[ `git log -n1 --pretty=format:%H patch` != `git log -n1 --pretty=format:%H origin/patch` ]] && cat 1>&2 <<EOF
	* WARNING /etc/.git changed!
EOF
