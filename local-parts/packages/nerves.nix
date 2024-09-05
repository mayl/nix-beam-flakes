{lib, ...}: {
  perSystem = {pkgs, ...}: let
    beamPkgs = pkgs.beam.packages.erlang_26.extend (_final: prev: {
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
          export MIX_HOME="${archive}"

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
      pname = "nerves";
      subcommand = "nerves.new";
    in {
      nerves_new = let
        version = "1.13.0";
        # https://github.com/phoenixframework/phoenix/tags
        src = pkgs.fetchFromGitHub {
          owner = "nerves-project";
          repo = "nerves_bootstrap";
          rev = "v${version}";
          sha256 = "sha256-9kOhn9il5UDz4hLwaMQ4X/AXtKqMjhqga2VBTfetYNY=";
        };
      in
        wrapMixCommand {
          inherit elixir erlang hex pname subcommand;
          archive = buildMixArchive {
            inherit elixir hex pname rebar rebar3 version;
            src = "${src}";
          };

          meta.mainProgram = "nerves";
        };
    };
  };
}
