{lib, pkgs, config, ...}:
let 
  cfg = config.services.windows-vsts;
in
  {

  options.services.windows-vsts = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Enable the module";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [];
  };
}
