{ config, pkgs, lib, ... }:

with lib;

let
  commonBuildMachineOpt = {
    speedFactor = 1;
    sshKey = "/etc/nix/id_buildfarm";
    sshUser = "root";
    system = "x86_64-linux";
    supportedFeatures = [ "kvm" "nixos-test" ];
  };
in {
  environment.etc = lib.singleton {
    target = "nix/id_buildfarm";
    source = ../static/id_buildfarm;
    uid = config.ids.uids.hydra;
    gid = config.ids.gids.hydra;
    mode = "0440";
  };

  nix = {
    distributedBuilds = true;
    buildMachines = [
      (commonBuildMachineOpt // {
        hostName = "localhost";
        maxJobs = 4;
      })
    ];
    extraOptions = "auto-optimise-store = true";
  };

  # let's auto-accept fingerprints on first connection
  programs.ssh.extraConfig = ''
    StrictHostKeyChecking no
  '';

  services.hydra = {
    enable = true;
    hydraURL = "http://hydra.serokell.io";
    port = 8080;
    useSubstitutes = true;
    notificationSender = "hi@serokell.io";
    # max output is 4GB because of amis
    extraConfig = ''
      binary_cache_secret_key_file = /etc/nix/hydra.serokell.io-1/secret
      max_output_size = 4294967296
    '';
    logo = (pkgs.fetchurl {
      url    = "https://serokell.io/Serokell.png";
      sha256 = "0fldiw4x0qz4k7pscaxswlw6yjn1pswzy4rdi7hibzsvn1ij8k7m";
    });
  };

  services.postgresql = {
    package = pkgs.postgresql96;
    dataDir = "/var/db/postgresql-${config.services.postgresql.package.psqlSchema}";
  };

  systemd.services.hydra-manual-setup = {
    description = "Create Keys for Hydra";
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    wantedBy = [ "multi-user.target" ];
    requires = [ "hydra-init.service" ];
    after = [ "hydra-init.service" ];
    environment = config.systemd.services.hydra-init.environment;
    script = ''
      if [ ! -e ~hydra/.setup-is-complete ]; then
        # create signing keys
        /run/current-system/sw/bin/install -d -m 551 /etc/nix/hydra.serokell.io-1
        /run/current-system/sw/bin/nix-store --generate-binary-cache-key hydra.serokell.io-1 /etc/nix/hydra.serokell.io-1/secret /etc/nix/hydra.serokell.io-1/public
        /run/current-system/sw/bin/chown -R hydra:hydra /etc/nix/hydra.serokell.io-1
        /run/current-system/sw/bin/chmod 440 /etc/nix/hydra.serokell.io-1/secret
        /run/current-system/sw/bin/chmod 444 /etc/nix/hydra.serokell.io-1/public
        # done
        touch ~hydra/.setup-is-complete
      fi
    '';
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme.certs = {
    "hydra.serokell.io" = {
      email = "info@serokell.io";
      user = "nginx";
      group = "nginx";
      webroot = "/var/www/challenges";
      postRun = "systemctl reload nginx.service";
    };
  };

  services.nginx = {
    enable = true;
    httpConfig = ''
      server_names_hash_bucket_size 64;

      keepalive_timeout   70;
      gzip            on;
      gzip_min_length 1000;
      gzip_proxied    expired no-cache no-store private auth;
      gzip_types      text/plain application/xml application/javascript application/x-javascript text/javascript text/xml text/css;

      server {
        server_name _;
        listen 80;
        listen [::]:80;
        location /.well-known/acme-challenge {
          root /var/www/challenges;
        }
        location / {
          return 301 https://$host$request_uri;
        }
      }

      server {
        listen 443 ssl spdy;
        server_name hydra.serokell.io;

        ssl_certificate /var/lib/acme/hydra.serokell.io/fullchain.pem;
        ssl_certificate_key /var/lib/acme/hydra.serokell.io/key.pem;

        location / {
          proxy_pass http://127.0.0.1:8080;
          proxy_set_header Host $http_host;
          proxy_set_header REMOTE_ADDR $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
        }
      }
    '';
  };
}
