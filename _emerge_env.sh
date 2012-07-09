branches() {
	git branch -r | cut -d/ -f2 | grep -vxf<(tr , \\n <<<$1)
}

patches() {
	git reset $1
	[[ Auto-update == `git log -n1 --pretty=format:%f` ]] && git diff HEAD^ --quiet && git reset HEAD^
	git commit -amAuto-update
	git checkout -B $1
	git rebase --onto $1 origin/$1 $2 || exit 1
}
