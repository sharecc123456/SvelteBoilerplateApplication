{ sources ? import ./sources.nix, pkgs ? import sources.nixpkgs { } }:

with pkgs;

let
  elixir = beam.packages.erlangR25.elixir.override {
    version = "1.14.5";
    sha256 = "1yp4mih5kjydm6j74fv08a5sdc6dw97yl1zdrxhns57yaj69683c";
  };
in buildEnv {
  name = "builder";
  paths =
    [ elixir nodejs-18_x postgresql_13 redis doppler which git curl pdftk ];
}
