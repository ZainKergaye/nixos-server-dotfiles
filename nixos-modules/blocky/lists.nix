{
  lib,
  config,
  ...
}:
{
  config.services.blocky.settings.blocking = lib.mkIf config.adblock.enable {
    denylists = {
      ads = [
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
        "https://v.firebog.net/hosts/AdguardDNS.txt"
        "https://adaway.org/hosts.txt"
      ];
      suspicious = [ " https://v.firebog.net/hosts/static/w3kbl.txt" ];
      tracking = [
        "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-blocklist.txt"
        "https://v.firebog.net/hosts/Easyprivacy.txt"
        "https://v.firebog.net/hosts/Prigent-Ads.txt"
      ];
      malicious = [
        "http://phishing.mailscanner.info/phishing.bad.sites.conf"
        "https://v.firebog.net/hosts/Prigent-Crypto.txt"
      ];
      adult = [ "https://blocklistproject.github.io/Lists/porn.txt" ];
    };
    clientGroupsBlock.default = [
      "ads"
      "suspicious"
      "tracking"
      "malicious"
      "adult"
    ];
  };
}
