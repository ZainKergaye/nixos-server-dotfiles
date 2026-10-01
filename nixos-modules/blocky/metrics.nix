{
  config,
  lib,
  ...
}:
{
  config.services.blocky = lib.mkIf config.adblock.enable {
    ports.http = 4000;
  };
}
