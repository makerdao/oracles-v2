{ pkgs ? import <nixpkgs> { }, nixos ? import <nixpkgs/nixos> { } }:
let
  generateSystemd = type: name: config:
    pkgs.writeText "${name}.${type}" (nixos.system {
      system = "x86_64-linux";
      configuration = ({ ... }: { config.systemd."${type}s".${name} = config; });
    }).config.systemd.units."${name}.${type}".text;
  mkService = generateSystemd "service";
  mkUserService = name: config:
    pkgs.writeShellScriptBin "activate" ''
      set -euo pipefail
      export XDG_RUNTIME_DIR="/run/user/$UID"
      loginctl enable-linger "$USER"
      mkdir -p "$HOME/.config/systemd/user" "$HOME/.config/systemd/user/default.target.wants"
      rm -f -- "$HOME/.config/systemd/user/${name}.service" "$HOME/.config/systemd/user/default.target.wants/${name}.service"
      ln -s ${mkService name config} "$HOME/.config/systemd/user/${name}.service"
      ln -s "$HOME/.config/systemd/user/${name}.service" "$HOME/.config/systemd/user/default.target.wants"
      systemctl --user daemon-reload
      systemctl --user restart ${name}
    '';

  ccc = (nixos.system {
    system = "x86_64-linux";
    configuration = import ../nixos { };
  }).config.systemd.units."gofer.services";
in pkgs.mkShell { buildInputs = [ (mkUserService "test" ccc) ]; }
