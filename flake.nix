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
    yabridgectl = pkgs.yabridgectl.override {inherit wine;};

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
        ${wine}/bin/wine ${poise}/Setup_Poise_64bit_1-1-55-6_Windows_Full.exe 
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
