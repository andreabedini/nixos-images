{
  description = "NixOS images";

  inputs.nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
  inputs.nixos-2211.url = "github:NixOS/nixpkgs/release-22.11";
  inputs.disko.url = "github:nix-community/disko";

  nixConfig.extra-substituters = [
    "https://cache.garnix.io"
  ];
  nixConfig.extra-trusted-public-keys = [
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
  ];

  outputs = { self, nixos-unstable, nixos-2211, disko }: let
    supportedSystems = [ "aarch64-linux" "x86_64-linux" ];
    forAllSystems = nixos-unstable.lib.genAttrs supportedSystems;
  in {
    packages = forAllSystems (system: let
      netboot = nixpkgs: (import (nixpkgs + "/nixos/release.nix") {}).netboot.${system};
      kexec-installer = nixpkgs: modules: (nixpkgs.legacyPackages.${system}.nixos (modules ++ [self.nixosModules.kexec-installer])).config.system.build.kexecTarball;
      netboot-installer = nixpkgs: (nixpkgs.legacyPackages.${system}.nixos [self.nixosModules.netboot-installer]).config.system.build.netboot;
    in {
      netboot-nixos-unstable = netboot nixos-unstable;
      netboot-nixos-2211 = netboot nixos-2211;
      kexec-installer-nixos-unstable = kexec-installer nixos-unstable [];
      kexec-installer-nixos-2211 = kexec-installer nixos-2211 [];

      kexec-installer-nixos-unstable-noninteractive = kexec-installer nixos-unstable [ 
        { system.kexec-installer.name = "nixos-kexec-installer-noninteractive"; }
        self.nixosModules.noninteractive 
        ({pkgs, ...}: {
          boot.kernelPackages = disko.legacyPackages.${pkgs.hostPlatform.system}.linuxPackages_bcachefs;
        })
      ];
      kexec-installer-nixos-2211-noninteractive = kexec-installer nixos-2211 [ 
        { system.kexec-installer.name = "nixos-kexec-installer-noninteractive"; }
        self.nixosModules.noninteractive 
      ];

      netboot-installer-nixos-unstable = netboot-installer nixos-unstable;
      netboot-installer-nixos-2211 = netboot-installer nixos-2211;
    });
    nixosModules = {
      kexec-installer = ./nix/kexec-installer/module.nix;
      noninteractive = ./nix/noninteractive.nix;
      netboot-installer = ./nix/netboot-installer/module.nix;
    };
    checks.x86_64-linux = let
      pkgs = nixos-unstable.legacyPackages.x86_64-linux;
    in {
      kexec-installer-unstable = pkgs.callPackage ./nix/kexec-installer/test.nix {};
      shellcheck = pkgs.runCommand "shellcheck" {
        nativeBuildInputs = [ pkgs.shellcheck ];
      } ''
        shellcheck ${(pkgs.nixos [self.nixosModules.kexec-installer]).config.system.build.kexecRun}
        touch $out
      '';
      kexec-installer-2211 = nixos-2211.legacyPackages.x86_64-linux.callPackage ./nix/kexec-installer/test.nix {};
    };
  };
}
