#!/usr/bin/env zsh

fpath=($DOTFILES/zsh/plugins $fpath)

# +---------+
# | HISTORY |
# +---------+

setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
setopt HIST_VERIFY               # Do not execute immediately upon history expansion.

# +--------+
# | COLORS |
# +--------+

# Override colors
eval "$(gdircolors -b $ZDOTDIR/dircolors)"

# +--------+
# | PROMPT |
# +--------+

fpath=($DOTFILES/zsh/prompt $fpath)
source $DOTFILES/zsh/prompt/prompt_purification_setup

# +------------+
# | COMPLETION |
# +------------+

source $DOTFILES/zsh/completion.zsh

# +-----+
# | FZF |
# +-----+

if [ $(command -v "fzf") ]; then
    source $DOTFILES/zsh/fzf.zsh
fi

# +---------------------+
# | zoxide |
# +---------------------+

eval "$(zoxide init --cmd cd zsh)"

# +---------------------+
# | SYNTAX HIGHLIGHTING |
# +---------------------+

source $DOTFILES/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
