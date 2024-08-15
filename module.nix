
{lib, pkgs, config, ...}:
let 
  # The actual set values in users configuration
  cfg = config.nix-automatic-windows-vsts;

  # Inpired by writeShellApplication, but with less options and for fish instead of bash
  writeFishApplication = {name, runtimeInputs ? [], text}: pkgs.writeTextFile {
    name = name;
    executable = true;
    destination = "/bin/${name}";
    text = ''
      #!${pkgs.fish}/bin/fish
      '' + lib.optionalString (runtimeInputs != []) ''
      set -px PATH ${lib.strings.concatStringsSep " " (lib.lists.concatMap (pkg: [ "${pkg}/bin" ]) runtimeInputs)}
      '' + ''

      ${text}
    '';
  };

  defaultWine = pkgs.wine.override {
    embedInstallers = true; # Mono (and gecko, although we probably don't need that) will be installed automatically
    wineRelease = "staging"; # Recommended by yabridge
    wineBuild = "wineWow"; # Both 32-bit and 64-bit wine
  };

  # The installation checker.
  # This fish script will check if the correct wineprefix is set up and warn otherwise
  check-installation = writeFishApplication {
    name = "check-windows-vst-installation";
    text = ''
      set WINEPREFIX "${cfg.prefixPath}"
      
      if ! test -d "$WINEPREFIX"
        echo "----------------------------------"
        echo "🎶 You have yet to initialize your Windows VSTs! Run 'windows-vst install' to set them up. 🎶"
        echo "----------------------------------"
      end
    '';
  };

  # The initialization script.
  # This fish script will set up the wineprefix for the user
  init-wineprefix = writeFishApplication {
    name = "init-wineprefix";
    runtimeInputs = [ cfg.winetricks cfg.wine ];
    text = ''
      set WINEPREFIX "${cfg.prefixPath}"
      set VST2_DIR "$WINEPREFIX/drive_c/Program Files/Steinberg/VstPlugins"
      set VST3_DIR "$WINEPREFIX/drive_c/Program Files/Common Files/VST3"
      mkdir -p "$VST2_DIR"
      mkdir -p "$VST3_DIR"

      echo "🍷 Setting up VST Wine Prefix..."
      mkdir -p "$WINEPREFIX"

      winecfg /v 10
      ${cfg.tricks-command}

      echo "🍷 Wine Prefix is done setting up!"
    '';
  };

  # Bash environment for the installation scripts
  install-single-vst = name: install: inputs: (pkgs.writeShellApplication {
    name = "install-single-vst-" + name;
    runtimeInputs = [ cfg.wine ] ++ inputs;
    text = ''
      export WINEPREFIX="${cfg.prefixPath}"
      export VST2_DIR="$WINEPREFIX/drive_c/Program Files/Steinberg/VstPlugins"
      export VST3_DIR="$WINEPREFIX/drive_c/Program Files/Common Files/VST3"

      WORKDIR="$(mktemp -d)"
      export WORKDIR
      mkdir -p "$WORKDIR"
      cd "$WORKDIR"
      
      echo "📦 Installing ${name}..."
      ${install}
      echo "📦 ${name} installed!"

      rm -rf "$WORKDIR"
    '';
  });

  # A list of the plugins that is a little easier to handle: [ {name, install, inputs} {...} ]
  packages = lib.attrsets.mapAttrsToList (name: value: {name = name; install = value.install; inputs = value.inputs; enable = value.enable;}) cfg.plugins;
  # Packages that actually are enabled. See above.
  enabled-packages = lib.lists.concatMap (pkg: if pkg.enable then [ pkg ] else []) packages;
  # The installer packages: [ install-single-vst-${name} ... ]
  installer-packages = lib.lists.concatMap (pkg: [ (install-single-vst pkg.name pkg.install pkg.inputs) ]) enabled-packages;
  # The list of paths to the installer packages: [ /nix/store/...-install-single-vst-${name} ... ]
  installer-packages-list = lib.lists.concatMap (pkg: [ "${pkg}" ]) installer-packages;
  # The package names: [ ${name} ... ]
  package-names = lib.lists.concatMap (pkg: [ "${pkg.name}" ]) enabled-packages;
  # The command strings to run the installers: [ /nix/store/...-install-single-vst-${name}/bin/install-single-vst-${name} ... ]
  install-strings = lib.lists.zipListsWith (a: b: "${a}/bin/install-single-vst-${b}") installer-packages-list package-names;
  # And wrap it all into a single string to run in the fish script
  install-string = lib.strings.concatStringsSep "\n" install-strings;

  # The main function for the windows-vst command
  windows-vst = writeFishApplication {
    name = "windows-vst";
    runtimeInputs = [ cfg.yabridgectl ];
    text = ''
      set WINEPREFIX "${cfg.prefixPath}"
      set VST2_DIR "$WINEPREFIX/drive_c/Program Files/Steinberg/VstPlugins"
      set VST3_DIR "$WINEPREFIX/drive_c/Program Files/Common Files/VST3"

      # Parse the arguments. They are available as $_flag_help, ...
      argparse --name "windows-vst" h/help f/force -- $argv
      or return

      # Couldn't figure out how to join this in a single line, so here we are
      set -l run_help false
      if set -ql _flag_help
        set run_help true
      end
      if test (count $argv) -eq 0
        set run_help true
      end

      # If there is a help flag, or no flag at all, print the help message
      if $run_help
        echo "🎶 Windows VSTs 🎶"
        echo "Usage: windows-vst [install|init|reset|sync|status] [options]"
        echo "Command: install: Install user defined plugins (also runs init)"
        echo "         init: Initialize the wineprefix"
        echo "         reset: Reset and remove the installation"
        echo "         sync: Sync the yabridge database"
        echo "         status: Check the status of the yabridge"
        echo ""
        echo "Options: --help, -h: Show this help message"
        echo "         --force, -f: Force the re-installation of user defined plugins"
        return 0
      end

      if test $argv[1] = "init"
        ${init-wineprefix}/bin/init-wineprefix
        return 0
      end

      if test $argv[1] = "install"
        set -l run_install false
        if set -ql _flag_force
          set run_install true
        end
        if test ! -d "$WINEPREFIX"
          set run_install true
        end
        if $run_install
          ${init-wineprefix}/bin/init-wineprefix

          echo "📦 Installing user defined plugins..."
          ${install-string}
          echo "📦 Done installing user defined plugins!"
          echo ""

          yabridgectl add "$VST2_DIR"
          yabridgectl add "$VST3_DIR"
          yabridgectl sync
          return 0
        else
          echo "🎶 Windows VSTs already set up!"
          echo "🎶 Run with '--force' to rerun installation"
          return 64
        end
      end

      if test $argv[1] = "reset"
        echo "❌ Reset Windows VSTs..."
        echo "Are you sure you want to reset the Windows VSTs?"
        echo "This will remove your user data, plugin-license files and settings,"
        echo "unless they are defined by the installation scripts."

        set res (read --prompt-str "Are you sure you want to continue? (y/N) " --nchars 1)
        if test "$res" = "y"
          echo "❌ Removing Windows VSTs..."
          rm -rf "$WINEPREFIX"
          echo "❌ Windows VSTs removed!"
          return 0
        else
          echo "🎶 Reset cancelled!"
          return 0
        end
      end

      if test $argv[1] = "sync"
        echo "🎶 Running yabridgectl sync for WINEPREFIX $WINEPREFIX..."
        yabridgectl sync
        return $status
      end

      if test $argv[1] = "status"
        echo "🎶 Running yabridgectl status for WINEPREFIX $WINEPREFIX..."
        yabridgectl status
        return $status
      end
    '';
  };

in
  {

  options.nix-automatic-windows-vsts = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Enable the module";
    };

    # Allow an attribute set for the user defined plugins
    # The set contains and enabled flag and an installation script string
    plugins = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            example = true;
            description = "Enable the plugin";
          };
          # Installation script
          install = lib.mkOption {
            type = lib.types.lines;
            default = '''';
            example = ''
              unzip ''${inputs.nes-vst}
              mv "NES VST 1.2.dll" "$VST2_DIR/NES VST 1.2.dll"
            '';
            description = ''
              The installation script for the plugin
              The variables $WINEPREFIX, $VST2_DIR and $VST3_DIR are available
              A temporary directory is created and the script is run from there
              Wine is available without adding it in inputs
              Uses shellcheck (for bash) by default
            '';
          };
          # Extra nix packages to install
          inputs = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [];
            example = [ pkgs.unzip ];
            description = "Extra nix packages to use during installation. Wine is always available.";
          };
        };
      });
      default = {};
      example = {
        "nes-vst" = {
          enable = true;
          install = ''
            unzip ''${inputs.nes-vst}
            mv "NES VST 1.2.dll" "$VST2_DIR/NES VST 1.2.dll"
          '';
          inputs = [ pkgs.unzip ];
        };
        "grace" = {
          enable = true;
          install = ''
            cp ''${inputs.grace} installer.exe
            wine installer.exe
          '';
        };
      };
      description = ''
        A set of user defined plugins to install
      '';
    };

    check = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = true;
      description = "Check if the installation is done on shell start";
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
      type = lib.types.lines;
      default = "winetricks corefonts";
      example = "winetricks allfonts";
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
      type = lib.types.str;
      default = "$HOME/.local/share/windows-vst";
      example = "$HOME/.local/share/windows-vst";
      description = ''
        The path to the wine prefix to generate and use.
      '';
    };
  };
  
  # Consider this like the users 'configuration.nix'
  # We can set the same options as the user can in there, and they are later merged together
  config = lib.mkIf cfg.enable {
    # Run a command when the users interactive shell is started
    # For some reason fish won't look at environment.interactiveShellInit,
    # so we set that manually.
    # There is likely some other shells that break this, probably all non POSIX shells
    environment.interactiveShellInit = lib.mkIf cfg.check "${pkgs.fish}/bin/fish ${check-installation}/bin/check-windows-vst-installation";
    programs.fish.interactiveShellInit = lib.mkIf cfg.check "${pkgs.fish}/bin/fish ${check-installation}/bin/check-windows-vst-installation";

    # Add the windows-vst command to the users shell
    # Also, we need at minimum yabridge in the users environment, otherwise
    # the generated plugin.so vst-plugins won't find it.
    environment.systemPackages = [ cfg.yabridge cfg.yabridgectl windows-vst];
  };
}
