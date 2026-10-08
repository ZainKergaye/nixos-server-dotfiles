{
  config,
  lib,
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
        default = "10.10.10.12";
        description = "NFSv4 server hosting the Borg repository";
      };

      nfsExport = mkOption {
        type = types.str;
        default = "/srv/backups/immich";
        description = "NFSv4 export containing the Immich Borg repository";
      };

      mountPoint = mkOption {
        type = types.str;
        default = "/mnt/immich-backup";
        description = "Local mount point for the NFSv4 backup export";
      };

      borgEncryptionMode = mkOption {
        type = types.enum [ "repokey" "keyfile" "repokey-blake2" "keyfile-blake2" "authenticated" "authenticated-blake2" "none" ];
        default = "none";
        description = "Borg repository encryption mode; use a pass command for encrypted modes";
      };

      borgPassCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command that prints the Borg passphrase without storing it in the Nix store";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Immich requires an account by default; this module deliberately does
      # not disable the upstream authentication flow.
      services.immich = {
        enable = true;
        host = "0.0.0.0";
        port = 2283;
        openFirewall = false;
        environment.IMMICH_LOG_LEVEL = "warn";
      };

      networking.firewall.extraCommands = lib.mkAfter ''
        iptables -A nixos-fw -p tcp --dport 2283 -s ${cfg.lanCidr} -j ACCEPT
        iptables -A nixos-fw -p tcp --dport 2283 -s ${cfg.wireGuardCidr} -j ACCEPT
      '';
    }

    (lib.mkIf cfg.backup.enable {
      boot.supportedFilesystems = [ "nfs" ];
      fileSystems.${cfg.backup.mountPoint} = {
        device = "${cfg.backup.nfsServer}:${cfg.backup.nfsExport}";
        fsType = "nfs4";
        options = [ "_netdev" "noatime" "x-systemd.automount" "x-systemd.idle-timeout=300" ];
      };

      services.borgbackup.jobs.immich = {
        paths = [ config.services.immich.mediaLocation ];
        repo = "${cfg.backup.mountPoint}/borg";
        doInit = true;
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

      assertions = [
        {
          assertion = cfg.backup.borgEncryptionMode == "none" || cfg.backup.borgPassCommand != null;
          message = "immich.backup.borgPassCommand must be set when Borg encryption is enabled";
        }
      ];
    })
  ]);
}
