if status is-interactive
# Commands to run in interactive sessions can go here
end

starship init fish | source

export PATH="$HOME/.local/bin:$PATH"
set -x EDITOR "zeditor"
