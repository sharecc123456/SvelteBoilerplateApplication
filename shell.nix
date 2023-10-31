{ sources ? import ./nix/sources.nix, pkgs ? import <nixpkgs> { } }:

with pkgs;
let
  inherit (lib) optional optionals;
  iacpython =
    python39.withPackages (p: with p; [ pip pdfrw pypdf2 reportlab pillow ]);

in mkShell {
  buildInputs = [ (import ./nix/default.nix { inherit pkgs; }) iacpython niv ]
    ++ optional stdenv.isLinux inotify-tools
    ++ optional stdenv.isDarwin terminal-notifier ++ optionals stdenv.isDarwin
    (with darwin.apple_sdk.frameworks; [ CoreFoundation CoreServices ]);
  shellHook = ''
    export PYTHONPATH=${iacpython}/${iacpython.sitePackages}
    export IAC_PYTHON_RUNCMD=$(which python3)
    export IAC_NODE_RUNCMD=$(which node)
    export HTTP_PORT=50080
    export HTTPS_PORT=50443
    export S3_BUCKET=bp-aws-docs-dev
    # NodeJS + openssl3 fix
    export NODE_OPTIONS=--openssl-legacy-provider
    alias blpt_setup='[[ -z $DOPPLER_TOKEN ]] && echo Please execute "export DOPPLER_TOKEN=yourdopplertoken" || doppler secrets'

    alias blpt_deps_get='doppler run --preserve-env -- mix deps.get'
    alias blpt_deps_clean='doppler run --preserve-env -- mix deps.clean'
    alias blpt_deps_compile='doppler run --preserve-env -- mix deps.compile'

    alias blpt_run_backend='doppler run --preserve-env -- mix phx.server'
    alias blpt_run_backend_interactive='doppler run --preserve-env -- iex -S mix'
    alias blpt_run_frontend='npm --prefix assets run watch'

    alias blpt_ff_seed='doppler run --preserve-env -- mix seed.feature_flags'

    alias blpt_db_migrate='doppler run --preserve-env -- mix ecto.migrate'
    alias blpt_db_reset='doppler run --preserve-env -- mix ecto.reset'
    alias blpt_db_rollback='doppler run --preserve-env -- mix ecto.rollback'

    alias blpt_prettier='git --no-pager diff --name-only $(git merge-base --fork-point master) HEAD | egrep '\.svelte$' | xargs npx --prefix assets prettier --write'
  '';
}
