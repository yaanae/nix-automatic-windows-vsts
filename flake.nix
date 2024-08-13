{
  description = "Automatically wrap your Windows VSTs with yabridge";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    lib = pkgs.lib;
  in
  {
    nixosModules.nix-automatic-windows-vsts = {config, ...}: import ./module.nix { inherit pkgs config lib; };
  };
}
