cd etc

git reset origin/stage3
git commit -amAuto-update
git branch stage3

git rebase --onto {,origin/{,patch-}}stage3 || exit 1
git branch patch-stage3

git rebase --onto {,origin/}patch-stage3 origin/emerged || exit 1
git branch -f master
git checkout -b emerged patch-stage3

emerge -e world || exit 1
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
