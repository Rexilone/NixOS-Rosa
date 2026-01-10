{ config, pkgs, ... }: {
	home = {
		username = "rexilone";
		homeDirectory = "/home/rexilone";
		stateVersion = "23.11";
	};

	programs.bash = {
		enable = true;
		shellAliases = {
			rebuild = "sudo nixos-rebuild switch";
		};
	};
}
