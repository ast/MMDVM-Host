{
  description = "MMDVM-Host — multi-mode digital voice modem host (fork of g4klx/MMDVM-Host, with Nix packaging)";

  # Single input on purpose. The package needs one C library and a compiler;
  # pulling in flake-utils to save a four-line genAttrs helper would add a
  # dependency to every consumer of this flake for no benefit.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      # aarch64 is the target -- a Raspberry Pi 4 hotspot. x86_64 is here so
      # the package can be built and checked on a workstation without
      # emulation.
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # `rev` exists only for a clean checkout; `dirtyRev` appears once the
      # tree has uncommitted changes. Either beats the 40 zeroes the Makefile
      # falls back to, and passing it in keeps the build itself pure.
      gitVersion = self.rev or self.dirtyRev or null;
    in
    {
      # The form most consumers want: add this to nixpkgs.overlays and
      # pkgs.mmdvm-host exists everywhere, built for whatever platform the
      # consuming system targets.
      overlays.default = final: _prev: {
        mmdvm-host = final.callPackage ./nix/package.nix { inherit gitVersion; };
      };

      packages = forAllSystems (pkgs: rec {
        mmdvm-host = pkgs.callPackage ./nix/package.nix { inherit gitVersion; };
        default = mmdvm-host;
      });

      # `nix develop` gives the upstream Makefile a working environment --
      # mosquitto headers and a compiler -- so an in-tree `make` behaves the
      # way the upstream README says it does.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ self.packages.${pkgs.stdenv.hostPlatform.system}.mmdvm-host ];
          packages = [ pkgs.clang-tools ];
        };
      });

      # `nix flake check` builds the package, which runs its installCheck.
      checks = forAllSystems (pkgs: {
        mmdvm-host = self.packages.${pkgs.stdenv.hostPlatform.system}.mmdvm-host;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
