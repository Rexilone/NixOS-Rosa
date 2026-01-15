{
	description = "123";
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		zen-browser.url = "github:youwen5/zen-browser-flake";
                nixvim.url = "github:nix-community/nixvim";
		zapret-discord-youtube.url = "github:kartavkun/zapret-discord-youtube";
		home-manager = {
			url = "github:nix-community/home-manager/release-25.11";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};
	outputs = { self, nixpkgs, zen-browser, zapret-discord-youtube, nixvim, ... }@inputs:
		let
			system = "x86_64-linux";
		in{
		nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
			inherit system;
			specialArgs = { inherit inputs system; };
			modules = [
			./configuration.nix
			
                        nixvim.nixosModules.nixvim 
			zapret-discord-youtube.nixosModules.default
        		{
        			services.zapret-discord-youtube = {
        			enable = true;
        			config = "general(ALT11)";  # Или любой конфиг из папки configs (general, general(ALT), general (SIMPLE FAKE) и т.д.)
        			};
        		}
			];
		};
	};
}
