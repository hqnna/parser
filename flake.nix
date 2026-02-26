{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts/main";
    zig-overlay.url = "github:mitchellh/zig-overlay/main";
    zls-master.url = "github:zigtools/zls/master";

    zls-master.inputs.zig-overlay.follows = "zig-overlay";
    zig-overlay.inputs.nixpkgs.follows = "nixpkgs";
    zls-master.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = ["x86_64-linux"];

      perSystem = { inputs', pkgs, ... }: {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            inputs'.zig-overlay.packages.master
            inputs'.zls-master.packages.default
          ];
        };
      };
    };
}
