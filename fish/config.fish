if status is-interactive
# Commands to run in interactive sessions can go here
end

starship init fish | source

export PATH="$HOME/.local/bin:$PATH"
set -x EDITOR "zeditor"

# lets gpg prompt for the passphrase in the terminal when signing commits
set -gx GPG_TTY (tty)
