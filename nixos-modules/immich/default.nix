{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.immich;
in
{
  options.immich = with lib; {
    enable = mkEnableOption "an authenticated Immich service with Borg backups";

    lanCidr = mkOption {
      type = types.str;
      default = "10.10.10.0/24";
      description = "LAN subnet permitted to access Immich";
    };

    wireGuardCidr = mkOption {
      type = types.str;
      default = "10.100.0.0/24";
      description = "WireGuard client subnet permitted to access Immich";
    };

    backup = {
      enable = mkEnableOption "daily Borg backups of the Immich data directory" // {
        default = true;
      };

      nfsServer = mkOption {
        type = types.str;
        default = "10.10.10.39";
        description = "NFSv4 server hosting the Borg repository";
      };

      nfsExport = mkOption {
        type = types.str;
        default = "/Docker";
        description = "NFSv4 Docker export on the NAS containing the Immich Borg repository";
      };

      mountPoint = mkOption {
        type = types.str;
        default = "/mnt/immich-backup";
        description = "Local mount point for the NFSv4 backup export";
      };

      repositoryName = mkOption {
        type = types.str;
        default = "immich-node3-backup";
        description = "Directory, within the NFS export, used as the Immich Borg repository";
      };

      borgEncryptionMode = mkOption {
        type = types.enum [
          "repokey"
          "keyfile"
          "repokey-blake2"
          "keyfile-blake2"
          "authenticated"
          "authenticated-blake2"
          "none"
        ];
        default = "none";
        description = "Borg repository encryption mode; use a pass command for encrypted modes";
      };

      borgPassCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command that prints the Borg passphrase without storing it in the Nix store";
      };
    };

    metrics.enable = mkEnableOption "Immich Prometheus metrics" // {
      default = true;
    };

    metrics.target = mkOption {
      type = types.str;
      default = "10.10.10.15";
      description = "Address of the Immich host scraped by the central Prometheus server";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Immich requires an account by default; this module deliberately does
      # not disable the upstream authentication flow.
      services.immich = {
        enable = true;
        host = "0.0.0.0";
        port = 2283;
        openFirewall = false;
        # GPU0 is the GTX 1050 Ti.  The coding agent remains pinned to GPU1.
        accelerationDevices = [
          "/dev/nvidia0"
          "/dev/nvidiactl"
          "/dev/nvidia-uvm"
          "/dev/nvidia-uvm-tools"
        ];
        # The official CUDA image retains Pascal support; Nixpkgs' current
        # native cuDNN package requires compute capability 7.5 or newer.
        machine-learning.enable = false;
        environment = {
          IMMICH_LOG_LEVEL = "warn";
          IMMICH_TELEMETRY_INCLUDE = "all";
          IMMICH_API_METRICS_PORT = "8081";
          IMMICH_MICROSERVICES_METRICS_PORT = "8082";
        };
      };

      networking.firewall.extraCommands = lib.mkAfter ''
        iptables -A nixos-fw -p tcp --dport 2283 -s ${cfg.lanCidr} -j ACCEPT
        iptables -A nixos-fw -p tcp --dport 2283 -s ${cfg.wireGuardCidr} -j ACCEPT
      '';

      # The services are sandboxed with PrivateUsers, so grant their account
      # the NVIDIA device groups explicitly for CUDA inference and NVENC.
      users.users.immich.extraGroups = [
        "render"
        "video"
        "immich"
        "postgres"
      ];

      # Run ML separately because GPU0 is Pascal (compute capability 6.1).
      # CDI exposes only that GPU to the official CUDA image; GPU1 remains
      # reserved for the coding agent.
      virtualisation.oci-containers = {
        backend = "docker";
        containers.immich-machine-learning = {
          image = "ghcr.io/immich-app/immich-machine-learning:v${pkgs.immich.version}-cuda";
          autoStart = true;
          extraOptions = [
            "--network=host"
            "--device=nvidia.com/gpu=0"
          ];
          environment = {
            IMMICH_HOST = "127.0.0.1";
            IMMICH_PORT = "3003";
            MACHINE_LEARNING_DEVICE_IDS = "0";
            NVIDIA_VISIBLE_DEVICES = "0";
          };
          volumes = [ "/var/lib/immich/ml-cache:/cache" ];
        };
      };
      systemd.services.immich-server = {
        after = [ "docker-immich-machine-learning.service" ];
        wants = [ "docker-immich-machine-learning.service" ];
        environment.IMMICH_MACHINE_LEARNING_URL = lib.mkForce "http://127.0.0.1:3003";
      };
      # Used to solve dumb permission issues
      systemd.tmpfiles.settings.immich = {
        "/var/lib/immich".d = {
          user = "immich";
          group = "immich";
          mode = "0700";
        };
        "/var/lib/immich/thumbs".d = {
          user = "immich";
          group = "immich";
          mode = "0700";
        };
        "/var/lib/immich/upload".d = {
          user = "immich";
          group = "immich";
          mode = "0700";
        };
        "/var/lib/immich/encoded-video".d = {
          user = "immich";
          group = "immich";
          mode = "0700";
        };
        "/var/lib/immich/profile".d = {
          user = "immich";
          group = "immich";
          mode = "0700";
        };
        "/var/lib/immich/backups".d = {
          user = "immich";
          group = "immich";
          mode = "0700";
        };
        "/var/lib/immich/library".d = {
          user = "immich";
          group = "immich";
          mode = "0700";
        };

        # Create marker files
        "/var/lib/immich/thumbs/.immich".f = {
          user = "immich";
          group = "immich";
          mode = "0644";
        };
        "/var/lib/immich/upload/.immich".f = {
          user = "immich";
          group = "immich";
          mode = "0644";
        };
        "/var/lib/immich/encoded-video/.immich".f = {
          user = "immich";
          group = "immich";
          mode = "0644";
        };
        "/var/lib/immich/profile/.immich".f = {
          user = "immich";
          group = "immich";
          mode = "0644";
        };
        "/var/lib/immich/backups/.immich".f = {
          user = "immich";
          group = "immich";
          mode = "0644";
        };
        "/var/lib/immich/library/.immich".f = {
          user = "immich";
          group = "immich";
          mode = "0644";
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.metrics.enable) {
      # Immich provides a separate endpoint for its API and microservices.
      # Prometheus runs only on main, so neither endpoint is LAN-public.
      networking.firewall.extraCommands = lib.mkAfter ''
        iptables -A nixos-fw -p tcp --dport 8081 -s ${config.prometheus.collectorAddress} -j ACCEPT
        iptables -A nixos-fw -p tcp --dport 8082 -s ${config.prometheus.collectorAddress} -j ACCEPT
      '';
    })

    # The central collector is configured on main, while Immich itself runs
    # on node3.  Keep the target and its scrape jobs with the service they
    # monitor rather than making the generic Prometheus module know about it.
    (lib.mkIf (cfg.metrics.enable && config.prometheus.server.enable) {
      services.prometheus.scrapeConfigs = [
        {
          job_name = "immich-api";
          static_configs = [
            {
              targets = [ "${cfg.metrics.target}:8081" ];
              labels.host = "node3";
            }
          ];
        }
        {
          job_name = "immich-microservices";
          static_configs = [
            {
              targets = [ "${cfg.metrics.target}:8082" ];
              labels.host = "node3";
            }
          ];
        }
      ];

      grafana.dashboards."immich.json" = lib.mkIf config.grafana.enable ./dashboard.json;
    })

    (lib.mkIf cfg.backup.enable {
      boot.supportedFilesystems = [ "nfs" ];
      fileSystems.${cfg.backup.mountPoint} = {
        device = "${cfg.backup.nfsServer}:${cfg.backup.nfsExport}";
        fsType = "nfs4";
        options = [
          "_netdev"
          "noatime"
          "x-systemd.automount"
          "x-systemd.idle-timeout=300"
        ];
      };

      # Materialize the Borg repository directory on the NAS at boot.  The
      # mount requirement activates the NFS automount before mkdir runs.
      systemd.services.immich-backup-directory = {
        description = "Create the Immich Borg repository directory on the NAS";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RequiresMountsFor = cfg.backup.mountPoint;
        };
        script = ''
          ${pkgs.coreutils}/bin/mkdir -p ${cfg.backup.mountPoint}/${cfg.backup.repositoryName}
        '';
      };

      services.borgbackup.jobs.immich = {
        paths = [ config.services.immich.mediaLocation ];
        repo = "${cfg.backup.mountPoint}/${cfg.backup.repositoryName}";
        doInit = true;
        # This accesses the NFS automount and creates the NAS-side repository
        # directory before Borg attempts its initialisation.
        preHook = ''
          ${pkgs.coreutils}/bin/mkdir -p ${cfg.backup.mountPoint}/${cfg.backup.repositoryName}
        '';
        compression = "zstd,6";
        startAt = "*-*-* 03:30:00";
        persistentTimer = true;
        encryption = {
          mode = cfg.backup.borgEncryptionMode;
          passCommand = cfg.backup.borgPassCommand;
        };
        prune.keep = {
          daily = 7;
          weekly = 4;
          monthly = 12;
        };
      };

      systemd.services.borgbackup-job-immich = {
        after = [ "immich-backup-directory.service" ];
        requires = [ "immich-backup-directory.service" ];
      };

      assertions = [
        {
          assertion = cfg.backup.borgEncryptionMode == "none" || cfg.backup.borgPassCommand != null;
          message = "immich.backup.borgPassCommand must be set when Borg encryption is enabled";
        }
      ];
    })
  ];
}
