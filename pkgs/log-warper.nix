{ mkDerivation, aeson, ansi-terminal, async, base, containers
, data-default, directory, dlist, errors, exceptions, extra
, fetchgit, filepath, formatting, hashable, hspec, HUnit, lens
, mmorph, monad-control, monad-loops, mtl, network, QuickCheck
, safecopy, stdenv, text, text-format, time, transformers
, transformers-base, universum, unix, unordered-containers, yaml
}:
mkDerivation {
  pname = "log-warper";
  version = "1.1.2";
  src = fetchgit {
    url = "https://github.com/serokell/log-warper.git";
    sha256 = "1la95i7sfc66jrjpm1c9d5w8bajb3wh06xj86s06i5gccaskwml9";
    rev = "cb3288415d40318e04ca920ff81ea4ea8e0380bd";
  };
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson ansi-terminal base containers directory dlist errors
    exceptions extra filepath formatting hashable lens mmorph
    monad-control monad-loops mtl network safecopy text text-format
    time transformers transformers-base universum unix
    unordered-containers yaml
  ];
  executableHaskellDepends = [ base exceptions text universum yaml ];
  testHaskellDepends = [
    async base data-default directory filepath hspec HUnit lens
    QuickCheck universum unordered-containers
  ];
  homepage = "https://github.com/serokell/log-warper";
  description = "Flexible, configurable, monadic and pretty logging";
  license = stdenv.lib.licenses.mit;
}
