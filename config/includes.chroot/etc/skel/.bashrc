# OctagonOS Default Bash Configuration

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend

# Window size
shopt -s checkwinsize

# Glob
shopt -s globstar 2>/dev/null

# Prompt
if [ "$(id -u)" -eq 0 ]; then
    PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# '
else
    PS1='\[\033[38;5;39m\]⬡\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \$ '
fi

# Color support
alias ls='ls --color=auto'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# OctagonOS shortcuts
alias update='sudo apt update && sudo apt upgrade -y'
alias cleanup='sudo apt autoremove -y && sudo apt autoclean'
alias gamemode-on='sudo octagonos-gamemode on'
alias gamemode-off='sudo octagonos-gamemode off'
alias sysinfo='octagonos-info'

# Enable bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Welcome (first terminal of session)
if [ -z "$OCTAGONOS_GREETED" ]; then
    export OCTAGONOS_GREETED=1
    octagonos-info 2>/dev/null
fi
