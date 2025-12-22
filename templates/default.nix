let
  mkTemplate =
    {
      name,
      description,
      path,
      buildTools ? null,
      additionalSetupInfo ? null,
    }:
    {
      inherit path;
      description = ''nix flake new my-project -t "github:ramblurr/nix-devenv#${name}"'';
      welcomeText = ''
        # ${name}
        ${description}

        ${
          if buildTools != null then
            ''
              Comes bundled with:
              ${builtins.concatStringsSep ", " buildTools}
            ''
          else
            ""
        }
        ${
          if additionalSetupInfo != null then
            ''
              ## Additional Setup
              To set up the project run:
              ```sh
              flutter create .
              ```
            ''
          else
            ""
        }
        ## Other tips
        Enable the devshell

        ```
            direnv allow
        ```

        For a quick license setup use:

        ```
            spdx init
        ```

        ## More info
        - [flake-utils Github Page](https://github.com/numtide/flake-utils)
      '';
    };
in
{
  clojure = mkTemplate {
    name = "clojure";
    description = ''
      A minmimal clojure application template with a deps.edn, bb.edn and kaocha setup.
    '';
    path = ./clojure;
  };

  generic = mkTemplate {
    name = "generic";
    description = ''
      A minmimal generic nix flake template
    '';
    path = ./generic;
  };
}
