export NIX_PATH=nixpkgs=https://github.com/NixOS/nixpkgs/archive/$(jq .rev < nixpkgs-src.json -r).tar.gz
