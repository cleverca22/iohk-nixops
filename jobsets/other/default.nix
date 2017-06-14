{}:

let
  systems = [ "x86_64-linux" "x86_64-darwin" ];
  makeJob = f: system: { ${system} = f (import <nixpkgs> { config = {}; inherit system; }); };
  merge = a: b: a // b;
  mergeList = builtins.foldl' merge {};
  makeJobs = f: mergeList (map (makeJob f) systems);
in {
  purescript = makeJobs (pkgs: pkgs.purescript);
  pandoc = makeJobs (pkgs: pkgs.pandoc);
  hlint = makeJobs (pkgs: pkgs.hlint);
}
