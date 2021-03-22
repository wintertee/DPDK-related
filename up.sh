# update dev to master
git checkout master
git rebase dev
git push origin dev --force
git push origin master --force