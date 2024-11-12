{ config, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix <home-manager/nixos> ];

  # Permitir paquetes unfree
  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add any missing dynamic libraries for unpackaged programs
    # here, NOT in environment.systemPackages
  ];

  # Hardware optimizado
  hardware = {
    enableAllFirmware = true;
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      open = false;
      nvidiaSettings = true;
      forceFullCompositionPipeline = true; # Mejora tearing
    };
    pulseaudio = {
      enable = true;
      support32Bit = true;
      package = pkgs.pulseaudioFull;
      daemon.config = {
        default-sample-rate = 48000;
        alternate-sample-rate = 44100;
        default-sample-format = "float32le";
        default-fragments = 2;
        default-fragment-size-msec = 125;
      };
    };
  };

  # Variables de entorno optimizadas
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_SYNC_TO_VBLANK = "1";
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "vespino";
    networkmanager.enable = true;
    firewall = {
      enable = false;
      allowedTCPPorts = [ 80 443 ];
    };
  };

  # Timezone y locale
  time.timeZone = "Europe/Madrid";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "es_ES.UTF-8";
      LC_IDENTIFICATION = "es_ES.UTF-8";
      LC_MEASUREMENT = "es_ES.UTF-8";
      LC_MONETARY = "es_ES.UTF-8";
      LC_NAME = "es_ES.UTF-8";
      LC_NUMERIC = "es_ES.UTF-8";
      LC_PAPER = "es_ES.UTF-8";
      LC_TELEPHONE = "es_ES.UTF-8";
      LC_TIME = "es_ES.UTF-8";
    };
  };

  # Audio
  sound.enable = true;

  # Las nerd fonts
  fonts.packages = with pkgs; [ nerdfonts ];

  # Usuario
  users.users.passh = {
    isNormalUser = true;
    description = "passh";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "docker" "input" ];
    shell = pkgs.bash;
  };

  # Servicios básicos optimizados
  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];

      xkb = {
        layout = "us,es";
        variant = "";
      };

      windowManager.xmonad = {
        enable = true;
        enableContribAndExtras = true;
        #config = pkgs.writeText "xmonad.hs"
          #(builtins.readFile "/home/passh/.config/xmonad/xmonad.hs");
      };

      desktopManager.xfce.enable = true;

      displayManager = {
        setupCommands = ''
          ${pkgs.xorg.xrandr}/bin/xrandr --output DP-0 --mode 5120x1440 --rate 120 --primary --dpi 96
          ${pkgs.xorg.xset}/bin/xset r rate 350 50
        '';
      };
    };

    displayManager = { defaultSession = "none+xmonad"; };

    # SSH básico
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };

  # Docker básico
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };

  virtualisation = {
    libvirtd = {
      enable = true;
      qemuOvmf = true;  # Para soporte UEFI si lo necesitas
      onBoot = "ignore";
      onShutdown = "shutdown";
    };
  programs.virt-manager.enable = true;  # GUI para gestionar VMs

  };

  # Paquetes básicos
  environment.systemPackages = with pkgs; [

    #virtualizacion
    virt-manager
    virt-viewer
    spice-gtk    # Para acceso remoto a la VM
    qemu
    OVMF         # Para soporte UEFI
    # Basics
    home-manager
    wget
    git
    curl
    vim
    ripgrep
    fd
    tree
    unzip
    zip

    # NVIDIA
    nvidia-vaapi-driver
    nvtopPackages.full
    vulkan-tools
    glxinfo

    # System
    xorg.setxkbmap
    xorg.xmodmap
    xorg.xinput
    xorg.xset
    dunst
    libnotify
    pciutils
    usbutils
    htop
    neofetch

    # Development
    emacs
    nodePackages.intelephense
    tree-sitter

    # Others
    xclip
    firefox
    google-chrome
    alsa-utils
    pavucontrol
  ];

  # Security básica
  security = {
    rtkit.enable = true;
    polkit.enable = true;
    sudo.wheelNeedsPassword = true;
  };

  # Nix settings básicos
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 8d";
    };
  };

  # System version
  system.stateVersion = "24.05";
}
