{lib, ...}: {
  perSystem = {pkgs, ...}: let
    beamPkgs = pkgs.beam.packages.erlangR26.extend (_final: prev: {
      rebar3 = prev.rebar3.overrideAttrs (_old: {doCheck = false;});
    });
    buildMixArchive = {
      elixir,
      hex,
      pname,
      rebar,
      rebar3,
      src,
      version,
      DEBUG ? 0,
      MIX_ENV ? "prod",
    }:
      pkgs.stdenv.mkDerivation {
        inherit src version;
        pname = "${pname}-archive";
        nativeBuildInputs = [elixir hex];

        inherit DEBUG;
        HEX_OFFLINE = 1;
        MIX_DEBUG = DEBUG;
        inherit MIX_ENV;
        MIX_REBAR = lib.getExe' rebar "rebar";
        MIX_REBAR3 = lib.getExe' rebar3 "rebar3";

        phases = ["unpackPhase" "buildPhase" "installPhase"];

        postUnpack = ''
          export HEX_HOME="$TEMPDIR/hex"
          export MIX_HOME="$TEMPDIR/mix"
          export REBAR_CACHE_DIR="$TEMPDIR/rebar3.cache"
          export REBAR_GLOBAL_CONFIG_DIR="$TEMPDIR/rebar3"
        '';

        buildPhase = ''
          mix archive.build
        '';

        installPhase = ''
          MIX_HOME="$out" mix archive.install --force
        '';
      };
    wrapMixCommand = {
      archive,
      elixir,
      erlang,
      git ? pkgs.gitMinimal,
      hex,
      meta ? {},
      pname,
      subcommand,
    }:
      pkgs.writeShellApplication {
        inherit meta;
        name = pname;
        runtimeInputs = [erlang elixir git hex];
        text = ''
          TEMPDIR=$(mktemp -d)
          cp -r "${archive}" "$TEMPDIR/mix"
          chmod -R +rwx "$TEMPDIR"
          mkdir "$TEMPDIR/hex"
          mkdir "$TEMPDIR/mix/elixir"
          echo "$TEMPDIR"
          #export MIX_HOME="${archive}"
          #export HEX_OFFLINE=1
          export HEX_HOME="$TEMPDIR/hex"
          export MIX_HOME="$TEMPDIR/mix"

          case $1 in
            help | "--help")
              exec mix help ${subcommand}
              ;;
            *)
              exec mix ${subcommand} "$@"
              ;;
          esac
        '';
      };
  in {
    packages = let
      inherit (beamPkgs) erlang rebar rebar3;
      elixir = beamPkgs.elixir_1_15;
      hex = beamPkgs.hex.override {inherit elixir;};
      pname = "igniter_new";
      subcommand = "igniter.new";
    in {
      igniter_new = let
        version = "0.3.19";
        src = pkgs.fetchFromGitHub {
          owner = "ash-project";
          repo = "igniter";
          rev = "v${version}";
          sha256 = "sha256-ZdlxM1N9aIvf8ZSFj/osSM63M6sGZVSZCGul3PmusPc=";
        };
        phx_src = pkgs.fetchFromGitHub {
          owner = "phoenixframework";
          repo = "phoenix";
          rev = "v${version}";
          sha256 = "sha256-WFUfwny0qYg9xqkW/nUSbNTJ3IAp1a+jzwUi5iQCS8E=";
        };
        hex_archive = pkgs.linkFarm "hex_archive" [ 
          { 
            name = "archives/hex-2.1.1/hex-2.1.1/ebin";
            path = "${hex}/lib/erlang/lib/hex/ebin";
          }
        ];
      in
        wrapMixCommand {
          inherit elixir erlang hex pname subcommand;
          archive = pkgs.symlinkJoin {
            name = "archive";
            paths = [
              (buildMixArchive {
                inherit elixir hex rebar rebar3 version;
                pname = "phx_new";
                src = "${phx_src}/installer";
              })
              (buildMixArchive {
                inherit elixir hex pname rebar rebar3 version;
                src = "${src}/installer";
              })
              hex_archive
            ];
          };
          meta.mainProgram = "igniter_new";
        };
    };
  };
}
