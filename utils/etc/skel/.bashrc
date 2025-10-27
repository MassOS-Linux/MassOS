# Just load the system bashrc, it has what we need.
if [ -f "/etc/bashrc" ]; then
  . /etc/bashrc
fi

# Add local bin directories to PATH.
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# Uncomment this to use nano as your default editor instead of vim.
#export EDITOR=nano

# If needed, uncomment to set a personal language and console keymap.
#export LANG=en_US.UTF-8
#export KEYMAP=us
