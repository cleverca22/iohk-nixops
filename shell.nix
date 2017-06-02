{ ghcVer   ? "ghc802"
, intero   ? false
}: let

nixpkgs       = (import <nixpkgs> {}).fetchFromGitHub (builtins.fromJSON (builtins.readFile ./nixpkgs-src.json));
pkgs          = import nixpkgs {};
compiler      = pkgs.haskell.packages."${ghcVer}";

ghcOrig       = import ./default.nix { inherit pkgs compiler; };

githubSrc     =      repo: rev: sha256:       pkgs.fetchgit  { url = "https://github.com/" + repo; rev = rev; sha256 = sha256; };
overC         =                               pkgs.haskell.lib.overrideCabal;
overCabal     = old:                    args: overC old (oldAttrs: (oldAttrs // args));
overGithub    = old: repo: rev: sha256: args: overC old ({ src = githubSrc repo rev sha256; }     // args);
overHackage   = old: version:   sha256: args: overC old ({ version = version; sha256 = sha256; } // args);

ghc       = ghcOrig.override (oldArgs: {
  overrides = with pkgs.haskell.lib; new: old:
  let parent = (oldArgs.overrides or (_: _: {})) new old;
  in with new; parent // {
      intero         = overGithub  old.intero "commercialhaskell/intero"
                       "e546ea086d72b5bf8556727e2983930621c3cb3c" "1qv7l5ri3nysrpmnzfssw8wvdvz0f6bmymnz1agr66fplazid4pn" { doCheck = false; };
      cabal2nix      = overGithub compiler.cabal2nix "NixOS/cabal2nix"
                       "b6834fd420e0223d0d57f8f98caeeb6ac088be88" "1ia2iw137sza655b0hf4hghpmjbsg3gz3galpvr5pbbsljp26m6p" {};
      stack2nix      = dontCheck
                       (pkgs.haskellPackages.callCabal2nix "stack2nix"
                        (githubSrc "input-output-hk/stack2nix" "c27a9faa9ba2a7ffd162a38953a36caad15e6839" "1cmw7zq0sf5fr9sc4daf1jwlnjll9wjxqnww36dl9cbbj9ak0m77") {});
    };
  });

###
###
###
drvf =
{ mkDerivation, stdenv, src ? ./.
, base, turtle, cassava, vector, safe, aeson, yaml, lens-aeson
, stack2nix, cabal2nix, cabal-install
}:
mkDerivation {
  pname = "iohk-nixops";
  version = "0.0.1";
  src = src;
  isLibrary = false;
  isExecutable = true;
  doHaddock = false;
  executableHaskellDepends = [
   base turtle cassava vector safe aeson yaml lens-aeson
  ];
  shellHook =
  ''
    export NIX_PATH=nixpkgs=${nixpkgs}
    echo   NIX_PATH set to $NIX_PATH
  '';
  license      = stdenv.lib.licenses.mit;
};

drv = (pkgs.haskell.lib.addBuildTools
(ghc.callPackage drvf { })
([ ghc.stack2nix ghc.cabal2nix pkgs.cabal-install
 ] ++
 (if intero
  then [ pkgs.cabal-install
         pkgs.stack
         ghc.intero ]
  else [])));

in drv.env
