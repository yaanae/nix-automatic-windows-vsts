{lib, pkgs, config, ...}:
let 
  cfg = config.services.windows-vsts;
  
  defaultWine = pkgs.wine.override {
    embedInstallers = true; # Mono (and gecko, although we probably don't need that) will be installed automatically
    wineRelease = "staging"; # Recommended by yabridge
    wineBuild = "wineWow"; # Both 32-bit and 64-bit wine
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
          inputs = lib.types.listOf lib.types.str;
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
    environment.systemPackages = [];
  };
}
