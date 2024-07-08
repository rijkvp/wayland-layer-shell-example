{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };
  outputs = { self, nixpkgs, flake-utils, crane, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system; 
          overlays = [ (import rust-overlay) ];
        };
        craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.stable.latest.default.override {});

        commonArgs = {
          src = craneLib.cleanCargoSource ./.;
          strictDeps = true;

          buildInputs = with pkgs; [
            wayland
            libxkbcommon
          ];
          nativeBuildInputs = with pkgs; [ pkg-config ];
        };

        rpath = with pkgs; lib.makeLibraryPath [
         wayland
         libxkbcommon
        ];

        crate = craneLib.buildPackage (commonArgs // {
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
          postFixup = ''
            patchelf $out/bin/shell --add-rpath ${rpath}
          '';
        });
      in
      {
        checks = { launcher = crate; };

        packages.default = crate;

        apps.default = flake-utils.lib.mkApp {
          drv = crate;
        };

        devShells.default = craneLib.devShell {
          checks = self.checks.${system};

          LD_LIBRARY_PATH = rpath;
        };
      });
}
