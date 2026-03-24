alias gfmain='git fetch origin main:main'
alias gfmaster='git fetch origin master:master'
alias gftrunk='git fetch origin trunk:trunk'
alias gp='git pull'
alias gp-r='git pull --rebase'
alias gps='git push'
alias gps-u='git push -u'
alias gco='git checkout'
alias gco-b='git checkout -b'
alias git-delete-pushed-branches='git branch | grep -Ev "(^\*|^\+|master|main|dev)" | xargs --no-run-if-empty git branch -d'



