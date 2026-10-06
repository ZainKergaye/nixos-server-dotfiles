{
  description = "Server dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixvim-custom.url = "github:ZainKergaye/nixvim_dotfiles";
    disko.url = "github:nix-community/disko/latest";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://nixpkgs-wayland.cachix.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://zain-system-cache.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "zain-system-cache.cachix.org-1:SeD9jt2CDJdXCMIejMDlpSrs8pgZJM7Q0vDBrATDQpk="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      userName = "server";
      mkHost =
        hostName:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              lib
              hostName
              userName
              ;
          };
          modules = [
            ./hosts/${hostName}/configuration.nix
            ./hosts/common
            ./nixos-modules
            home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = { inherit inputs hostName userName; };
              networking.hostName = hostName;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${userName} = import ./homemanager-modules;
            }
          ];
        };
      hostNames = [
        "main"
        "node1"
        "node2"
        "node3"
        "node4"
      ];
    in
    {
      nixosConfigurations = lib.genAttrs hostNames mkHost;

      packages.${system} = lib.genAttrs hostNames (
        hostName: self.nixosConfigurations.${hostName}.config.virtualisation.vmVariant.system.build.vm
      );

      apps.${system} = lib.genAttrs hostNames (hostName: {
        meta.description = "Virtual machine for ${hostName}";
        type = "app";
        program = "${self.packages.${system}.${hostName}}/bin/run-${hostName}-vm";
      });
    };
}
