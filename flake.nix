{
  description = "bebash dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            # Bash runtime + shell lint/format
            pkgs.bash
            pkgs.shellcheck
            pkgs.shfmt
            # Task runner + per-project git hooks
            pkgs.just
            pkgs.pre-commit
            # Test harness + data plumbing
            pkgs.bats
            pkgs.jq
            pkgs.git
            # Man-page / docs generation
            pkgs.scdoc
            pkgs.mandoc
            # Markdown lint/format
            pkgs.markdownlint-cli2
            # Changelog generation
            pkgs.git-cliff
          ];
          shellHook = ''echo "bebash dev shell ready"'';
        };
      }
    );
}
