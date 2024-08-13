
{lib, pkgs, config, ...}:
let 
  cfg = config.services.windows-vsts;

  defaultWine = pkgs.wine.override {
    embedInstallers = true; # Mono (and gecko, although we probably don't need that) will be installed automatically
    wineRelease = "staging"; # Recommended by yabridge
    wineBuild = "wineWow"; # Both 32-bit and 64-bit wine
  };
  wine = cfg.wine;
  winetricks = cfg.winetricks;
  tricks-command = cfg.tricks-command;

  # The installation checker.
  # This fish script will check if the correct wineprefix is set up and warn otherwise
  check-installation = pkgs.writeShellApplication {
    name = "check-windows-vst-installation";
    runtimeInputs = [ pkgs.fish ];
    text = ''
      #!/usr/bin/env fish

      if test -z $XDG_DATA_HOME/vstplugins
        echo "You have yet to initialize your Windows VSTs! Run 'init-windows-vst' to set them up."
      end
    '';
  };

  # The initialization script.
  # This fish script will set up the wineprefix for the user
  init-wineprefix = pkgs.writeShellApplication {
    name = "init-wineprefix";
    runtimeInputs = [ pkgs.fish winetricks wine ];
    text = ''
      #!/usr/bin/env fish

      if test -z $XDG_DATA_HOME/vstplugins
        echo "Setting up VST Wine Prefix..."
        mkdir -p $XDG_DATA_HOME/vstplugins

        wincfg /v 10
        exec "${tricks-command}"

        echo "Wine Prefix is done setting up!"
      else
        echo "Windows VSTs already set up!"
      end
    '';

    init-windows-vst = pkgs.writeShellApplication {
      name = "init-windows-vst";
      runtimeInputs = [ pkgs.fish ];
      text = ''
        #!/usr/bin/env fish

        '';
    };
  };
in
  {

  options.services.windows-vsts = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Enable the module";
    };

    # Allow an attribute set for the user defined plugins
    # The set contains and enabled flag and an installation script string
    plugins = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.types.bool;
          # Installation script
          install = lib.types.str;
          # Extra nix packages to install
          inputs = lib.types.listOf lib.types.package;
        };
      };
      default = {};
      example = {
        "nes-vst" = {
          enable = true;
          install = ''
            unzip ''${inputs.nes-vst}
            mv "NES VST 1.2.dll" $VST2_DIR
          '';
          inputs = [ pkgs.unzip ];
        };
      };
      description = ''
        A set of user defined plugins to install
      '';
    };

    # Allow the user to use custom wine version
    wine = lib.mkOption {
      type = lib.types.package;
      default = defaultWine;
      example = pkgs.wine.override { embedInstallers = true; };
      description = ''
        The wine version to use.
        "embedInstallers" override in wine is recommended to be set to true
      '';
    };

    # Allow the user to use custom winetricks version
    winetricks = lib.mkOption {
      type = lib.types.package;
      default = pkgs.winetricks;
      example = pkgs.winetricks;
      description = ''
        The winetricks version to use.
      '';
    };

    tricks-command = lib.mkOption {
      type = lib.types.str;
      default = "winetricks allfonts";
      example = "winetricks corefonts";
      description = ''
        The winetricks command to run when setting up the wineprefix
      '';
    };

    yabridge = lib.mkOption {
      type = lib.types.package;
      default = pkgs.yabridge.override { wine = cfg.wine; };
      example = pkgs.yabridge.override { wine = cfg.wine; };
      description = ''
        The yabridge version to use.
        "wine" should probably be the same as the "wine" option
        if you want to use your own yabridge version
      '';
    };

    yabridgectl = lib.mkOption {
      type = lib.types.package;
      default = pkgs.yabridgectl.override { wine = cfg.wine; };
      example = pkgs.yabridgectl.override { wine = cfg.wine; };
      description = ''
        The yabridgectl version to use.
        "wine" should probably be the same as the "wine" option
        if you want to use your own yabridgectl version
      '';
    };

    # Allow the user to create a custom wine prefix location
    prefixPath = lib.mkOption {
      type = lib.types.path;
      default = "$HOME/.local/share/nix-vsts";
      example = "$HOME/.local/share/nix-vsts";
      description = ''
        The path to the wine prefix to generate and use
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Run a command when the users interactive shell is started
    environment.interactiveShellInit = "${check-installation}";
    environment.systemPackages = [];
      
  };
}
