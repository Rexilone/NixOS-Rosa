{
	description = "123";
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		zen-browser.url = "github:youwen5/zen-browser-flake";

		home-manager = {
			url = "github:nix-community/home-manager/release-25.11";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};
	outputs = { self, nixpkgs, zen-browser, ... }@inputs:
		let
			system = "x86_64-linux";
		in{
		nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
			inherit system;
			specialArgs = { inherit inputs system; };
			modules = [
			./configuration.nix
			];
		};
	};
}
