{
  config,
  lib,
  ...
}:
{
  config.services.blocky.settings = lib.mkIf config.adblock.enable {
    ports.http = 4000;
  };
}
