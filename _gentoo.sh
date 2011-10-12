cd etc

git reset origin/stage3
git commit -amAuto-update
git branch prev-stage3

git rebase --onto {prev-,origin/{,patch-}}stage3 || exit 1
git branch patch-stage3

emerge -e world || exit 1

git checkout -b {,prev-}stage3

find -name ._cfg\* | while read e; do
	mv "$e" "`sed s/^._cfg[0-9]*_// <<<$e`"
done

git commit -amAuto-update
git rebase --onto {,prev-,patch-}stage3 || exit 1
git branch -f patch-stage3
git branch -d prev-stage3

git rebase --onto {,origin/}patch-stage3 origin/emerged || exit 1
git branch -f master
git checkout -b emerged patch-stage3

emerge $(<.git/info/world) || exit 1

git reset master
git commit -amAuto-update

git rebase --onto {,origin/{,patch-}}emerged || exit 1
git branch patch-emerged
git checkout -B master

for i in . .git/scripts; do
(
	cd $i
	git gc --aggressive --prune=2020
	git update-server-info
)
done

echo Ok.
