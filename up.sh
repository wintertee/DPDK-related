# update dev to master

git pull origin dev
git pull origin master

git checkout dev
git rebase master
git push origin dev --force
git push origin master --force