rm -fr ../var/tmp/* ../tmp/*
true >resolv.conf

git remote set-url origin $git_root_ssh
git gc --aggressive --prune=2020
git update-server-info
git status

diff -u ../{etc/.git/scripts,var/lib/portage}/world >&2
cat >&2 <<EOF
Things that MUST be done:
	* pay attention to the above diff (if any), consider updating github.com/sigaev/linux-scripts/blob/HEAD/world
	* examine the diff of /var/log/install.{out,err}.xz and previous versions
	* same with /etc/{passwd,group}
	* run github.com/sigaev/linux/blob/HEAD/test/pycuda and github.com/sigaev/linux/blob/HEAD/test/tex
	* on deployments that load both virtually and physically:
		- rename eth1 to eth0 in /etc/udev/rules.d/70-persistent-net.rules
	* once it's clear the release is solid, git push --tags from /etc and bump the base/master
		tags in github.com/sigaev/linux-config and github.com/sigaev/linux-scripts
EOF
[[ `git rev-list -n1 master^` != `git rev-list -n1 origin/master` ]] && cat >&2 <<EOF
	* WARNING /etc/.git changed! git push from /etc
EOF
