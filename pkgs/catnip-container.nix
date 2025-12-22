{
  pkgs,
  self,
  inputs,
}:
import ../catnipContainer.nix {
  inherit self pkgs;
  lib = pkgs.lib;
  claude-code = inputs.llm-agents.packages.${pkgs.stdenv.system}.claude-code;
  determinate-nixd = inputs.determinate.packages.${pkgs.stdenv.system}.default;
  detsys-nix = inputs.nix.packages.${pkgs.stdenv.system}.default;
  nix2container = inputs.nix2container.packages.${pkgs.stdenv.system}.nix2container;
}
