. .git/scripts/_emerge_env.sh

diff -u <(git grep -h ^CHOST= origin/$arch make.conf) <(grep ^CHOST= make.conf) || exit 1
rm -f make.conf

git remote set-head origin -d
git branch -m master _
branches | while read i; do
	git branch $i origin/$i
done
git branch root `git merge-base $arch master`
git branch origin/root root

patches stage3 root
git branch -f _ $arch
git rebase --onto root origin/root _ || exit 1
