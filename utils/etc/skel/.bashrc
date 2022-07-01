# Just load the system bashrc, it has what we need.
if [ -f "/etc/bashrc" ]; then
  . /etc/bashrc
fi

# Add local bin directories to PATH.
export PATH=$HOME/bin:$HOME/.local/bin:$PATH

# If needed, uncomment to set a personal language and console keymap.
#export LANG=en_US.UTF-8
#export KEYMAP=us
