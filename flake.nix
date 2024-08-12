{
  description = "Automatically wrap your Windows VSTs with yabridge";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nes-vst = {
      url = "https://www.mattmontag.com/nesvst/NES-VST-1.2.zip";
      flake = false;
    };
    poise = {
      url = "https://osc.sfo2.digitaloceanspaces.com/Setup_Poise_64bit_1-1-55-6_Windows_Full.exe";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let 
    pkgs = nixpkgs.legacyPackages.x86_64-linux;

    # Wine staging with mono
    wine = pkgs.wine.override {
      embedInstallers = true; # Mono (and gecko, although we probably don't need that) will be installed automatically
      wineRelease = "staging"; # Recommended by yabridge
      wineBuild = "wineWow"; # Both 32-bit and 64-bit wine
    };

    winetricks = pkgs.winetricks;
    yabridge = pkgs.yabridge;
    yabridgectl = pkgs.yabridgectl;
    poise = inputs.poise;
    nes-vst = inputs.nes-vst;

    setup-vsts-script = pkgs.writeShellScriptBin "setup-windows-vsts" ''
        # This script is run the first time the package is installed
        # It should install the VSTs

        # Setting up the wine prefix
        export WINEPREFIX="$HOME/.wine-nix/setup-windows-vsts"
        mkdir -p "$WINEPREFIX"

        # Prepare file structure
        export VST_PATH="$WINEPREFIX/drive_c/Program Files/Steinberg/VstPlugins"
        mkdir -p "$VST_PATH"
        
        cp "${nes-vst}/NES VST 1.2.dll" "$VST_PATH"
        wine ${poise}/Setup_Poise_64bit_1-1-55-6_Windows_Full.exe 

        # Let yabridge know where the VSTs are
        yabridgectl add "$VST_PATH"
    '';
    setup-vsts = pkgs.symlinkJoin {
      name = "setup-windows-vsts";
      paths = [ yabridge yabridgectl setup-vsts-script winetricks ];
    };
  in {
    packages.x86_64-linux.setup-vsts = setup-vsts;
  };
}
