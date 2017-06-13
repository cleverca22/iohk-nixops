import ./make-test.nix ({ pkgs, ... }: {
  name = "boot";
  nodes = {
    one = { config, pkgs, ... }: {
    };
  };
  testScript = ''
    startAll
    $one->waitForUnit("network.target");
  '';
})
