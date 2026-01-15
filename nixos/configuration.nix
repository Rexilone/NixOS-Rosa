# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, inputs, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./modules/nixvim.nix
#      ./hardware.nix
      inputs.home-manager.nixosModules.home-manager
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.rexilone = {
      imports = [ ./home.nix ];
    };
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = false;
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
    };
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      useOSProber = true;
    };
  };

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Yakutsk";

  # Select internationalisation properties.
  i18n.defaultLocale = "ru_RU.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "ru";
    variant = "";
  };
  
  virtualisation.virtualbox.host.enable = true;
  boot.kernelParams = [ "kvm.enable_virt_at_load=0" ];
  # Define a user account. Don't forget to set a password with ‘passwd’.
  services.getty.autologinUser = "rexilone";
  users.users.rexilone = {
    shell = pkgs.fish;
    isNormalUser = true;
    description = "Rexilone";
    extraGroups = [ "networkmanager" "wheel" "vboxusers" ];
    packages = with pkgs; [];
  };
  
  environment.loginShellInit = ''
    if [ "$(tty)" = "/dev/tty1" ]; then
      exec hyprland
    fi
  '';

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    inputs.zen-browser.packages.${stdenv.hostPlatform.system}.default
    brightnessctl
    home-manager
    hyprshot
    hyprpicker
    hyprlock
    fastfetch
    pavucontrol
    nwg-look
    waybar
    viewnior
    kitty
    btop
    swww
    rofi
    nemo
    p7zip
    ntfs3g
    udiskie
    mpv
    git
    cava
    # bluetooth
    bluez
    bluez-tools
    bzmenu
  ];

  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    font-awesome
    font-awesome_5
    jetbrains-mono
    liberation_ttf
    dejavu_fonts
    corefonts
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  services.gvfs.enable = true;
  services.udisks2.enable = true;

  programs.fish.enable = true;
  
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/desktop/interface".gtk-theme = "Space";
  }];

  environment.sessionVariables = {
    GTK_THEME = "Space";
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  #networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
