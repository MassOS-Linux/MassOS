# Personal environment variables and startup programs.

if [ -d "$HOME/bin" ] ; then
  pathprepend $HOME/bin
fi

if [ -d "$HOME/.local/bin" ] ; then
  pathprepend $HOME/.local/bin
fi

# Set up user specific i18n variables
#export LANG=en_US.UTF-8
