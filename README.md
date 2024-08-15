
# Nix automatic Windows VSTs

Want to define your Windows VSTs in your Nix configuration? Of course you want to!

That is exactly what this tool allows you to do. Define installation steps for each plugin and Nix-automatic-Windows-VSTs will handle the rest.


## Usage/Examples

### With Flakes
Demonstration with the two plugins, [NES-VST](https://www.mattmontag.com/projects-page/nintendo-vst) and [Grace](https://www.onesmallclue.com/index.html).

```nix
### flake.nix ###
{
    inputs = {
        nix-automatic-windows-vsts.url = "github:yaanae/nix-automatic-windows-vsts";
        plugin-name = {
            url = "file+https://url-to-plugin-installation-media";
            flake = false;
        };
        # For example:
        nes-vst = {
            url = "file+https://www.mattmontag.com/nesvst/NES-VST-1.2.zip";
            flake = false;
        };
        grace = {
            url = "file+https://osc.sfo2.digitaloceanspaces.com/Setup_Grace_64bit_Full_1-0-4-9_Windows.exe";
            flake = false;
        };
    };
    
    # Outputs with @inputs or @attrs or whatever else
    outputs = {nixpkgs, ...}@inputs: {
        nixosConfiguration."username" = nixpkgs.lib.nixosSystem {
            # ... #
            modules = [
                inputs.nix-automatic-windows-vsts.nixosModules.nix-automatic-windows-vsts
            ]; 
        };
    };
}

### configuration.nix ###
{ pkgs, ... }@inputs:
{
    nix-automatic-windows-vsts = {
        enable = true;
        # With example plugins
        plugins."nes-vst" = {
            enable = true;
            install = ''
                unzip ${inputs.nes-vst}
                mv "NES VST 1.2.dll" "$VST2_DIR/NES VST 1.2.dll"
            '';
            inputs = [ pkgs.unzip ];
        };
        plugins."grace" = {
            enable = true;
            install = ''
                cp ${inputs.grace} installer.exe
                wine installer.exe
            '';
        };
    };
}
```


## Documentation/Reference
Below is the reference for your configuration. You likely don't have to touch any of them unless they are in the  Usage/Example section.
```nix
# Enable or disable the entire plugin
enabled = true; 

# Plugin configuration
plugins."plugin" = {
    enable = true; # Should the plugin be enabled?
    install = ''
        # Installation steps.
        # Variables $WINEPREFIX $VST2_DIR and $VST3_DIR are available
        # Script checked by *shellcheck*
    '';
    inputs = []; # List of packages to include during installation. Wine is always provided.
}

# Checks on shell startup if installation step has been completed.
# No need to set to false unless you want to shave milliseconds off your config.
check = true; 

# Path to the wine prefix created
prefixPath = "$HOME/.local/share/windows-vst"; 

# Winetricks command to run during setup. corefonts or allfonts recommended.
tricks-command = "winetricks corefonts"; 

# Winetricks package to use
winetricks = pkgs.winetricks;

# Wine package to use
# Please use embedInstallers to have mono available
wine = pkgs.wine.override { embedInstallers = true; wineRelease = "staging"; wineBuild = "wineWow"; };

# Yabridge package.
yabridge = pkgs.yabridge.override { inherit wine; };

# Yabridgectl package;
yabridgectl = pkgs.yabridgectl.override { inherit wine; };
```



## Contributing

Thanks for trying the project out!

Issues and pull requests alike are all welcome if you find the project good enough to continue! Whatever you think the the project can improve on, and especially if you think you can make that improvement yourself, please do tell me!

Small recommendation, write an issue before you make a pull-request. If I know what you're up to it's more likely I'll approve of it!

Naturally, this project offers no guarantees of quality or function, just read the license, but I'll try to help you as much as I can in the time that I have!
