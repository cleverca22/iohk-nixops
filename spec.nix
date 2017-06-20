with import <nixpkgs> {};
let
  nixpkgs = builtins.fromJSON (builtins.readFile ./nixpkgs-src.json);
  mkFetchGit = url: { type = "git"; value = url; emailresponsible = false; };
  mkJobSet = obj: {
    enabled = 1;
    hidden = false;
    description = "a test";
    nixexprinput = "iohk-nixops";
    nixexprpath = "jobsets/cardano.nix";
    checkinterval = 60;
    schedulingshares = 100;
    enableemail = false;
    emailoverride = "";
    keepnr = 10;
    inputs = {
      iohk-nixops = mkFetchGit "https://github.com/cleverca22/iohk-nixops hydra-test2";
      nixpkgs = mkFetchGit "https://github.com/nixos/nixpkgs ${nixpkgs.rev}";
      nixops = mkFetchGit "https://github.com/nixos/nixops";
    };
  };
  jobsets = {
    cardano = mkJobSet { url = "https://github.com/cleverca22/iohk-nixops/"; };
  };
in {
  jobsets = writeText "jobsets.json" (builtins.toJSON jobsets);
}
