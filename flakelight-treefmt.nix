# from: https://github.com/m15a/flakelight-treefmt/blob/c58734af2cfab7285259919ba6ba0add799600db/flakelight-treefmt.nix
# BSD 3-Clause License
#
# Copyright (c) 2025, NACAMURA Mitsuhiro
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
{
  lib,
  config,
  inputs,
  ...
}:

let
  inherit (builtins) attrValues;
  inherit (lib)
    mkForce
    mkIf
    mkMerge
    mkOption
    ;
  inherit (lib.types)
    bool
    deferredModule
    ;
  inherit (inputs.treefmt-nix.lib) evalModule;

  build = pkgs: (evalModule pkgs config.treefmtConfig).config.build;
  wrapper = pkgs: (build pkgs).wrapper;
in

{
  options = {
    treefmtConfig = mkOption {
      description = "Treefmt configuration module.";
      type = deferredModule;
      default = { };
    };

    treefmtWrapperInDevShell = mkOption {
      description = "Whether to add treefmt wrapper to `devShell.packages`.";
      type = bool;
      default = true;
    };

    treefmtProgramsInDevShell = mkOption {
      description = "Whether to add treefmt programs to `devShell.packages`.";
      type = bool;
      default = true;
    };
  };

  config = mkMerge [
    (mkIf config.treefmtWrapperInDevShell {
      devShell.packages = pkgs: [ (wrapper pkgs) ];
    })
    (mkIf config.treefmtProgramsInDevShell {
      devShell.packages = pkgs: attrValues (build pkgs).programs;
    })
    {
      formatter = mkForce wrapper;
      checks.formatting = mkForce (pkgs: (build pkgs).check inputs.self);
    }
  ];
}
