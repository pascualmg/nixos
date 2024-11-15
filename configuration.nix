{ config, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix <home-manager/nixos> ];

  # Permitir paquetes unfree
  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add any missing dynamic libraries for unpackaged programs here
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
      forceFullCompositionPipeline = true;
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
    # Añadimos variables para QEMU
    LIBVIRT_DEFAULT_URI = "qemu:///system";
  };

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # Añadimos módulos necesarios para VM
    kernelModules = [ "kvm-amd" "kvm-intel" "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" ];
    # Kernel parameters para mejor rendimiento VM
    kernelParams = [ "intel_iommu=on" "amd_iommu=on" "iommu=pt" ];
  };

networking = {
    hostName = "vespino";
    useHostResolvConf = false;
    useDHCP = false;
    
    # DNS configuración - solo usar VM
    nameservers = [ "192.168.53.12" ];
    search = [ "grupo.vocento" ];
    
    # Deshabilitar resolv.conf automático
    resolvconf.enable = false;

    # Configuración de interfaces
    interfaces = {
      enp10s0 = {
        useDHCP = false;
        ipv4.addresses = [ {
          address = "192.168.2.125";
          prefixLength = 24;
        } ];
      };
      
      br0 = {
        useDHCP = false;
        ipv4 = {
          addresses = [ {
            address = "192.168.53.10";
            prefixLength = 24;
          } ];
          # Añadimos las rutas VPN que funcionan
          routes = [
            {
              address = "10.180.0.0";
              prefixLength = 16;
              via = "192.168.53.12";
            }
            {
              address = "192.168.196.0";
              prefixLength = 24;
              via = "192.168.53.12";
            }
          ];
        };
      };
    };

    # Bridge configuración
    bridges = {
      br0.interfaces = [ ];
    };

    # Ruta por defecto
    defaultGateway = {
      address = "192.168.2.1";
      interface = "enp10s0";
    };

    # NetworkManager configuración
    networkmanager = {
      enable = true;
      dns = "none";  # Desactivar DNS de NetworkManager
      unmanaged = [ "interface-name:enp10s0" "interface-name:br0" "interface-name:vnet*" ];
    };

    # NAT y firewall
    nat = {
      enable = true;
      internalInterfaces = [ "br0" ];
      externalInterface = "enp10s0";
      # Reglas específicas para VPN
      extraCommands = ''
        iptables -t nat -A POSTROUTING -s 192.168.53.0/24 -j MASQUERADE
      '';
    };

    firewall = {
      enable = true;
      allowedTCPPorts = [ 53 80 443 22 ];
      allowedUDPPorts = [ 53 ];
      checkReversePath = false;
    };
  };

  # Asegurar IP forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv4.conf.default.forwarding" = 1;
  };

  # Desactivar servicios que pueden interferir
  services = {
    resolved.enable = false;
  };

  # Virtualización
 virtualisation = {
  libvirtd = {
    enable = true;
    qemu = {
      ovmf.enable = true;
      runAsRoot = true;
    };
    onBoot = "ignore";
    onShutdown = "shutdown";
    allowedBridges = [ "br0" "virbr0" ];
  };
  docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };

  # El resto de tu configuración existente...
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

  sound.enable = true;
  fonts.packages = with pkgs; [ nerdfonts ];

  users.users.passh = {
    isNormalUser = true;
    description = "passh";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "docker" "input" "libvirtd" "kvm" ];  # Añadidos grupos VM
    shell = pkgs.bash;
  };

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
      };
      desktopManager.xfce.enable = true;
      displayManager = {
        setupCommands = ''
          ${pkgs.xorg.xrandr}/bin/xrandr --output DP-0 --mode 5120x1440 --rate 120 --primary --dpi 96
          ${pkgs.xorg.xset}/bin/xset r rate 350 50
        '';
      };
    };

    displayManager.defaultSession = "none+xmonad";

    # Servicios adicionales para VM
    spice-vdagentd.enable = true;  # Para mejor integración con SPICE
    qemuGuest.enable = true;      # Soporte para guest

    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };

  # Paquetes básicos + VM
  environment.systemPackages = with pkgs; [
    # Tus paquetes existentes
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
    nvidia-vaapi-driver
    nvtopPackages.full
    vulkan-tools
    glxinfo
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
    emacs
    nodePackages.intelephense
    tree-sitter
    xclip
    firefox
    google-chrome
    alsa-utils
    pavucontrol

    # Paquetes para virtualización
    virt-manager
    virt-viewer
    qemu
    OVMF
    spice-gtk
    spice-protocol
    win-virtio  # Por si necesitas drivers Windows
    swtpm       # Para TPM si lo necesitas
    bridge-utils
    dnsmasq     # Para networking
    iptables
  ];

  security = {
    rtkit.enable = true;
    polkit.enable = true;
    sudo.wheelNeedsPassword = true;
  };

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

  system.stateVersion = "24.05";
}
