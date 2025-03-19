{
  description = "A flake for interacting with bunny-dev platform";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};


        # Basic dependencies needed for the environment
        common-app-buildInputs = with pkgs; [
          bash
          curl
          jq
          age
          ssh-to-age
          sops
        ];


        renew-tailscale-token-buildInputs = with pkgs; [
          bash
          curl
          jq
          sops
        ];

        # Script name
        renew-tailscale-token-name = "renew-tailscale-token";

        renew-tailscale-token-version ="0.1.0";

        # Create the script
        renew-tailscale-token-script = (pkgs.writeScriptBin renew-tailscale-token-name (builtins.readFile ./scripts/renew-tailscale-token.sh)).overrideAttrs (old: {
          buildCommand = "${old.buildCommand}\n patchShebangs $out";
        });


      in rec {
        defaultPackage = packages.app-script;

        packages = {
          renew-tailscale-token-script = pkgs.symlinkJoin {
            name = renew-tailscale-token-name;
            paths = [renew-tailscale-token-script] ++ renew-tailscale-token-buildInputs;
            buildInputs = [pkgs.makeWrapper];
            postBuild = ''
              wrapProgram $out/bin/${renew-tailscale-token-name} \
                --set VERSION "${renew-tailscale-token-version}"
            '';
          };

          renew-tailscale-token-docker = pkgs.dockerTools.buildLayeredImage {
            name = "bunny-dev/tailscale-token-renewer";
            tag = "latest";
            contents = [renew-tailscale-token-script] ++ renew-tailscale-token-buildInputs;
            config = {
              Env = [ ];
              Entrypoint = ["${defaultPackage}/bin/${renew-tailscale-token-name}"];
            };
          };
        };

        devShell = pkgs.mkShell {
          buildInputs = common-app-buildInputs ++ [
            renew-tailscale-token-script
          ];

          shellHook = ''
            echo "Bunny Dev Platform Environment Ready!"
          '';
        };
      }
    );
}