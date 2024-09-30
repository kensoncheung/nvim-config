#!/usr/bin/env bash

# if node --version | head -n1 | grep -vq v18; then
#   echo "expected nodejs v18, aborting..."
#   exit 1
# fi

if nvim --version | head -n1 | grep -vq 0.10; then
  echo "expected nvim 0.10, aborting..."
  exit 1
fi

if pip3 list | grep pynvim | grep -vq pynvim; then
  echo "expected pynvim, aborting..."
  exit 1
fi

if [[ $(uname) == "Darwin" ]]; then
  if tmux -V | grep -vq 3.5; then
    echo "expected tmux 3.5, aborting..."
    exit 1
  fi
else
  if tmux -V | grep -vq 3.4; then
    echo "expected tmux 3.4, aborting..."
    exit 1
  fi
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

[ ! -d ~/nvim-cofig ] && ln -s ${base_dir}/nvim-config ~/nvim-config
[ -f ~/.bash_aliases ] && rm ~/.bash_aliases
[ -f ~/.bash_aliases_shared ] && rm ~/.bash_aliases_shared
[ -f ~/.ssh/config ] && rm ~/.ssh/config
[ -f ~/.gitconfig ] && rm ~/.gitconfig
[ -f ~/.zshrc ] && rm ~/.zshrc
if [[ $(uname) == "Darwin" ]]; then
  base_dir="/Users/kensoncheung/kensoncheung/dev-tools/env"
else
  base_dir="/home/kensoncheung/kensoncheung/dev-tools/env"
fi
ln -s ${base_dir}/bash_aliases ~/.bash_aliases
ln -s ${base_dir}/bash_aliases_shared ~/.bash_aliases_shared
ln -s ${base_dir}/ssh/config ~/.ssh/config
ln -s ${base_dir}/gitconfig ~/.gitconfig
ln -s ${base_dir}/zshrc ~/.zshrc
echo "bash_aliases and git config Symlinks done"

