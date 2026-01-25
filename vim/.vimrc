set packpath^=~/.config/vim
set packpath+=~/.config/vim/after

if filereadable(expand("~/.config/vim/vimrc"))
  source ~/.config/vim/vimrc
endif
