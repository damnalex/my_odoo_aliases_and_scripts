cat ~/Library/Application\ Support/Code/User/settings.json >$AP/editors/vscode/settings.json &&
    git -C $AP add $AP/editors/vscode/settings.json &&
    git -C $AP commit -m "[AUTOMATIC] update vscode settings.json"
