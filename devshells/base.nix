{ withCategory, ... }:
{ pkgs, ... }:
{
  commands = map (withCategory "base") [
    {
      package = pkgs.spdx;
      name = "spdx";
    }
  ];
  packages = [
  ];
}
