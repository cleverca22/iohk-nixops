{ prsJSON ? null, nixpkgs ? <nixpkgs>, declInput ? {} }:

# Followed by https://github.com/NixOS/hydra/pull/418/files

let
  prs = builtins.fromJSON (builtins.readFile prsJSON);
  iohkNixopsUri = "https://github.com/input-output-hk/iohk-nixops.git";
  pkgs = import nixpkgs {};
  mkFetchGithub = value: {
    inherit value;
    type = "git";
    emailresponsible = false;
  };
  nixpkgs-src = builtins.fromJSON (builtins.readFile ./../nixpkgs-src.json);
  defaultSettings = {
    enabled = 1;
    hidden = false;
    nixexprinput = "jobsets";
    keepnr = 5;
    schedulingshares = 42;
    checkinterval = 60;
    inputs = {
      nixpkgs = mkFetchGithub "https://github.com/NixOS/nixpkgs.git ${nixpkgs-src.rev}";
      jobsets = mkFetchGithub "${iohkNixopsUri} master";
    };
    enableemail = false;
    emailoverride = "";
  };
  mkCardano = nixopsBranch: nixpkgsRev: {
    nixexprpath = "jobsets/cardano.nix";
    inputs = {
      nixpkgs = mkFetchGithub "https://github.com/NixOS/nixpkgs.git ${nixpkgsRev}";
      jobsets = mkFetchGithub "${iohkNixopsUri} ${nixopsBranch}";
    };
  };
  jobsetsAttrs = with pkgs.lib; mapAttrs (name: settings: defaultSettings // settings) (rec {
    cardano-sl = mkCardano "master" "b9628313300b7c9e4cc88b91b7c98dfe3cfd9fc4";
    cardano-sl-staging = mkCardano "staging" nixpkgs-src.rev;
    cardano-devops-123 = mkCardano "devops-123-unification-nixpkgs" nixpkgs-src.rev;
    cardano-devops-169 = mkCardano "devops-169-initial-nixos-tests" nixpkgs-src.rev;
    deployments = {
      nixexprpath = "jobsets/deployments.nix";
      description = "Builds for deployments";
    };
  });
  jobsetJson = pkgs.writeText "spec.json" (builtins.toJSON jobsetsAttrs);
in {
  jobsets = with pkgs.lib; pkgs.runCommand "spec.json" {} ''
    cat <<EOF
    ${builtins.toJSON declInput}
    EOF
    cp ${jobsetJson} $out
  '';
}
