import ./make-test.nix ({ pkgs, ... }: {
  name = "boot";
  nodes = {
    machine = { config, pkgs, ... }: {
      imports = [ ../../modules/cardano-node.nix ];
      services.cardano-node = {
        enable = true;
        testIndex = 0;
        initialPeers = [];
        genesisN = 6;
        autoStart = true;
        productionMode = true;
      };
    };
  };
  testScript = ''
    startAll
    $machine->waitForUnit("cardano-node.service");
    # TODO, implement sd_notify?
    $machine->waitForOpenPort(3000);
  '';
})