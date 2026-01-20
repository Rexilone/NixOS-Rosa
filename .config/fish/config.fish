if status is-interactive
    set -g fish_greeting ""
    abbr -a rebuild 'sudo nixos-rebuild switch --flake /etc/nixos'
    alias ff="fastfetch"
    alias n="nvim"
end
