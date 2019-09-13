cat ~/.vimrc > $AP/editors/vim/.vimrc &&
git -C $AP add $AP/editors/vim/.vimrc &&
git -C $AP commit -m "[AUTOMATIC] update .vimrc"
