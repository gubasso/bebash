{
  description = "bebash dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # The store guard of the canon (exobrain): `exobrain store-guard --daily`
    # in .envrc warns about working-tree copies in the Nix store.
    exobrain-tech = {
      url = "github:gubasso/exobrain-tech/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      exobrain-tech,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        # The bash versions that the pre-push hook `test-bash-versions` runs
        # the bats suite under. nixpkgs ships one bash, so each version builds
        # from its GNU tarball, and the store keeps it after the first build.
        bashMatrix = {
          "4_4" = {
            version = "4.4";
            hash = "sha256-2GszksEgLo/1pCOzAuYoTbf49DXqnzm1sbIP06w238s=";
          };
          "5_0" = {
            version = "5.0";
            hash = "sha256-tKgPKsZhcLKRPvv7nyWU8fdsexr9EfeZ4iA11jB3+00=";
          };
          "5_2" = {
            version = "5.2";
            hash = "sha256-oTnBZt9/9EccXgczBRZC7lVWwcyKSnjxRVg8XIGrMvs=";
          };
        };
        mkBash =
          { version, hash }:
          pkgs.stdenv.mkDerivation {
            pname = "bash";
            inherit version;
            src = pkgs.fetchurl {
              url = "mirror://gnu/bash/bash-${version}.tar.gz";
              inherit hash;
            };
            # Old bash sources predate C23 and the stricter defaults of GCC 14.
            # Without these flags, the configure probes fail and the build
            # breaks on functions that the probes missed.
            env.NIX_CFLAGS_COMPILE = toString [
              "-std=gnu17"
              "-Wno-error=implicit-function-declaration"
              "-Wno-error=implicit-int"
              "-Wno-error=incompatible-pointer-types"
              "-Wno-error=int-conversion"
            ];
            configureFlags = [ "--without-bash-malloc" ];
            enableParallelBuilding = true;
          };
        # bats on one bash of the matrix. The nixpkgs bats pins its shebangs
        # to the bash of nixpkgs, so this copy of the same bats release points
        # every shebang at the bash under test, and carries that bash in bin/.
        mkBatsOn =
          bash:
          pkgs.stdenv.mkDerivation {
            pname = "bats-on-bash";
            version = "${pkgs.bats.version}-bash-${bash.version}";
            src = pkgs.bats.unresholved.src;
            dontBuild = true;
            dontPatchShebangs = true;
            installPhase = ''
              bash ./install.sh "$out"
              grep -rlZ '^#!/usr/bin/env bash$' "$out" \
                | xargs -0 sed -i '1s|^#!/usr/bin/env bash$|#!${bash}/bin/bash|'
              ln -s ${bash}/bin/bash "$out/bin/bash"
            '';
          };
      in
      {
        packages = pkgs.lib.mapAttrs' (
          name: spec: pkgs.lib.nameValuePair "bats-bash-${name}" (mkBatsOn (mkBash spec))
        ) bashMatrix;

        devShells.default = pkgs.mkShell {
          packages = [
            # Bash runtime, the language of the project
            pkgs.bash
            # The shellharden hook keeps language: system: shellharden
            # publishes no pre-commit hook. pre-commit builds shellcheck and
            # shfmt from their upstream hooks.
            pkgs.shellharden

            # Task runner + per-project git hooks
            pkgs.just
            pkgs.pre-commit
            # Test harness + data plumbing
            pkgs.bats
            pkgs.jq
            pkgs.yq-go
            # Man-page / docs generation
            pkgs.scdoc
            pkgs.mandoc
            # The node of the `markdownlint-cli2` hook, which pre-commit
            # builds on it through `default_language_version` in
            # .pre-commit-config.yaml.
            pkgs.nodejs
            # Changelog generation
            pkgs.git-cliff
          ]
          # exobrain, the store guard that .envrc runs once a day.
          ++ pkgs.lib.optionals (system == "x86_64-linux") [
            exobrain-tech.packages.${system}.default
          ];
          shellHook = ''echo "bebash dev shell ready"'';
        };
      }
    );
}
