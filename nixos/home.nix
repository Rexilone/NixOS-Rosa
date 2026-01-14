{ config, pkgs, ... }: {
	home.packages = with pkgs; [
		prismlauncher
		telegram-desktop
		vesktop
		onlyoffice-desktopeditors
		yandex-music
		scrcpy
		android-tools
		github-desktop
		lact
	];
	home = {
		enableNixpkgsReleaseCheck = false;
		stateVersion = "25.11";
	};

}
