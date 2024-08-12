{
  description = "Automatically wrap your Windows VSTs with yabridge";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nes-vst = {
      url = "file+https://www.mattmontag.com/nesvst/NES-VST-1.2.zip";
      flake = false;
    };
    poise = {
      url = "file+https://osc.sfo2.digitaloceanspaces.com/Setup_Poise_64bit_1-1-55-6_Windows_Full.exe";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let 
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    
    poise-configuration = pkgs.stdenv.mkDerivation {
      name = "poise-configuration";
      src = ./.;
      installPhase = ''
        mkdir -p $out
        cp poise.inf $out/poise.inf
      '';
    };

    nes-vst = pkgs.stdenv.mkDerivation {
      name = "nes-vst-unwrapped";
      buildInputs = [ pkgs.unzip ];
      unpackPhase = "true";
      installPhase = ''
        unzip ${inputs.nes-vst}
        # ls -la ${inputs.nes-vst}
        # echo break 1
        # ls -la .
        # echo break 2
        mkdir -p $out
        mv "NES VST 1.2.dll" $out
        # ls -la $out
      '';
    };
    poise = pkgs.stdenv.mkDerivation {
      name = "poise-unwrapped";
      unpackPhase = "true";
      installPhase = ''
        mkdir -p $out
        cp ${inputs.poise} $out/Setup_Poise_64bit_1-1-55-6_Windows_Full.exe
        ls $out
      '';
    };

    # Wine staging with mono
    wine = pkgs.wine.override {
      embedInstallers = true; # Mono (and gecko, although we probably don't need that) will be installed automatically
      wineRelease = "staging"; # Recommended by yabridge
      wineBuild = "wineWow"; # Both 32-bit and 64-bit wine
    };

    winetricks = pkgs.winetricks;
    yabridge = pkgs.yabridge.override {inherit wine;} ;
    yabridgectl = pkgs.yabridgectl.overrideAttrs {
      inherit wine yabridge;
      postPatch = ''
        # Add the yabridge path to the search path
        substituteInPlace src/config.rs --replace '.chain(iter::once(user_path.clone()));' '.chain(iter::once(user_path.clone())).chain(iter::once(Path::new("${pkgs.yabridge}/lib").to_path_buf()));'
        # Add the yabridge path to the test paths
        substituteInPlace src/config.rs --replace 'pub const YABRIDGE_HOST_EXE_NAME: &str = "yabridge-host.exe";' 'pub const YABRIDGE_HOST_EXE_NAME: &str = "${pkgs.yabridge}/bin/yabridge-host.exe";'
        substituteInPlace src/config.rs --replace 'pub const YABRIDGE_HOST_32_EXE_NAME: &str = "yabridge-host-32.exe";' 'pub const YABRIDGE_HOST_32_EXE_NAME: &str = "${pkgs.yabridge}/bin/yabridge-host-32.exe";'
      '';
    };

    setup-vsts-script = pkgs.writeShellScriptBin "setup-windows-vsts" ''
        # This script is run the first time the package is installed
        # It should install the VSTs
        
        # Setting up the wine prefix
        export WINEPREFIX="$HOME/.wine-nix/setup-windows-vsts"
        mkdir -p "$WINEPREFIX"

        # Configuring the wine prefix
        ${wine}/bin/winecfg /v win10
        ${winetricks}/bin/winetricks corefonts

        # Prepare file structure
        export VST_PATH="$WINEPREFIX/drive_c/Program Files/Steinberg/VstPlugins"
        mkdir -p "$VST_PATH"
        
        # Installing the VSTs
        cp "${nes-vst}/NES VST 1.2.dll" "$VST_PATH"
        ${wine}/bin/wine ${poise}/Setup_Poise_64bit_1-1-55-6_Windows_Full.exe /LOADINF="${poise-configuration}/poise.inf" #/SAVEINF="$WINEPREFIX/poise.inf"
        # Make sure that yabridge chanloaders are in the right place
        cp -r ${yabridge}/lib/ $HOME/.local/share/yabridge/

        # Let yabridge know where the VSTs are
        ${yabridgectl}/bin/yabridgectl add "$VST_PATH"
        ${yabridgectl}/bin/yabridgectl sync --force
    '';
    setup-vsts = pkgs.symlinkJoin {
      name = "setup-windows-vsts";
      paths = [ yabridge yabridgectl setup-vsts-script winetricks ];
    };
  in {
    packages.x86_64-linux.setup-vsts = setup-vsts;
  };
}
