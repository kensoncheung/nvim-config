#!/usr/bin/env bash

# version_ge A B -> true when A >= B (dotted numeric; non-numeric junk ignored)
version_ge() {
  local IFS=.
  local p1=${1#"${1%%[0-9]*}"} p2=${2#"${2%%[0-9]*}"}
  local -a a=($p1) b=($p2)
  local i x y
  for i in 0 1 2 3; do
    x=${a[i]:-0}; x=${x%%[!0-9]*}; x=${x:-0}
    y=${b[i]:-0}; y=${y%%[!0-9]*}; y=${y:-0}
    if ((x > y)); then return 0; fi
    if ((x < y)); then return 1; fi
  done
  return 0
}

if nvim --version | head -n1 | grep -vq 0.12; then
  echo "expected nvim 0.12, aborting..."
  exit 1
fi

# tmux lowest version this config needs (popup windows: 3.2+)
tmux_version=$(tmux -V | awk '{print $2}')
if ! version_ge "$tmux_version" 3.4; then
  echo "expected tmux >= 3.4, found $tmux_version, aborting..."
  exit 1
fi

if ! which rg > /dev/null; then
  echo "rg not found, aborting..."
  exit 1
fi

if [[ $(uname) == "Darwin" ]]; then
  if ! which fd > /dev/null; then
    echo "fd not found, aborting..."
    exit 1
  fi
else
  if ! which fdfind > /dev/null; then
    echo "fdfind not found, aborting..."
    exit 1
  fi
fi

if ! which fzf > /dev/null; then
  echo "fzf not found, aborting..."
  exit 1
fi

mkdir -p ~/.config/nvim

rm -rf \
  ~/.config/nvim/init.lua \
  ~/.config/nvim/lua \
  ~/.config/nvim/snippets \
  ~/.tmux.conf \
  ~/.config/kitty/kitty.conf \
  ~/.config/wezterm/wezterm.lua \
  ~/.config/nvim/ftdetect \
  ~/.config/nvim/ftplugin \
  ~/.config/nvim/syntax

ln -s `pwd`/vimrc.lua ~/.config/nvim/init.lua
ln -s `pwd`/nvim.d ~/.config/nvim/lua
ln -s `pwd`/ftdetect ~/.config/nvim/ftdetect
ln -s `pwd`/ftplugin ~/.config/nvim/ftplugin
ln -s `pwd`/syntax ~/.config/nvim/syntax
ln -s `pwd`/snippets ~/.config/nvim/snippets
ln -s `pwd`/tmux.conf ~/.tmux.conf
[ -d ~/.config/kitty ] && ln -s `pwd`/kitty.conf ~/.config/kitty/kitty.conf
[ -d ~/.config/wezterm ] && ln -s `pwd`/wezterm.lua ~/.config/wezterm/wezterm.lua

echo "Symlinks done"

if ! which open-project 1>/dev/null 2>&1; then
  sourceLine="export PATH=\"\$PATH:`pwd`/bin\""
  [ -f ~/.bashrc ] && echo $sourceLine >> ~/.bashrc
  [ -f ~/.zshrc ] && echo $sourceLine >> ~/.zshrc
  echo "RC files Done"
fi

tmux source-file ~/.tmux.conf
echo "Reload tmux done"

[ -f ~/.bash_aliases ] && rm ~/.bash_aliases
[ -f ~/.bash_aliases_shared ] && rm ~/.bash_aliases_shared
[ -f ~/.ssh/config ] && rm ~/.ssh/config
[ -f ~/.gitconfig ] && rm ~/.gitconfig
[ -f ~/.zshrc ] && rm ~/.zshrc
if [[ $(uname) == "Darwin" ]]; then
  homedir="/Users/kensoncheung"
else
  homedir="/home/kensoncheung"
fi
[ ! -d ~/nvim-config ] && ln -s ${homedir}/kensoncheung/nvim-config ~/nvim-config
basedir="${homedir}/kensoncheung/dev-tools/env"
ln -s ${basedir}/bash_aliases ~/.bash_aliases
ln -s ${basedir}/bash_aliases_shared ~/.bash_aliases_shared
ln -s ${basedir}/ssh/config ~/.ssh/config
ln -s ${basedir}/gitconfig ~/.gitconfig
ln -s ${basedir}/zshrc ~/.zshrc
echo "bash_aliases and git config Symlinks done"

