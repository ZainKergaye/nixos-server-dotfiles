{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codingAgent;
in
{
  options.codingAgent = with lib; {
    enable = mkEnableOption "a private local-model and coding-agent server";

    localModel = mkOption {
      type = types.str;
      default = "qwen3:8b";
      description = "Ollama model pulled for private, everyday requests";
    };

    vulkanVisibleDevices = mkOption {
      type = types.str;
      default = "1";
      description = "Vulkan-visible GPU indexes for Ollama; node3's Tesla P4 is GPU 1";
    };

    contextLength = mkOption {
      type = types.ints.positive;
      default = 4096;
      description = "Ollama context window; deliberately modest for the P4's 8 GiB VRAM";
    };

    webUiPort = mkOption {
      type = types.port;
      default = 8081;
      description = "LAN-facing Open WebUI port";
    };

    lanCidr = mkOption {
      type = types.str;
      default = "10.10.10.0/24";
      description = "Physical LAN permitted to reach Open WebUI";
    };

    wireGuardCidr = mkOption {
      type = types.str;
      default = "10.100.0.0/24";
      description = "WireGuard clients permitted to reach Open WebUI";
    };

    litellmEnvironmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Environment file containing hosted-provider credentials, for example
        OPENAI_API_KEY. It is deliberately separate from the Nix store.
      '';
    };

    additionalModels = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      example = [
        {
          model_name = "frontier-coding";
          litellm_params = {
            model = "openai/gpt-5.6";
            api_key = "os.environ/OPENAI_API_KEY";
          };
        }
      ];
      description = ''
        Additional LiteLLM model entries. Use `os.environ/NAME` for a provider
        key supplied by `litellmEnvironmentFile`.
      '';
    };

    openHandsWorkspace = mkOption {
      type = types.str;
      default = "/var/lib/coding-agent/workspaces";
      description = "Rootless Podman workspace directory for OpenHands jobs";
    };
  };

  config = lib.mkIf cfg.enable {
    # The Tesla P4 is Pascal and has 8 GiB of VRAM. Keep the local model and
    # the context budget small enough that the host's 16 GiB RAM is not used as
    # an accidental extension of GPU memory.
    services.ollama = {
      enable = true;
      # CUDA 12.9 currently fails to build in this Nixpkgs revision because
      # cuda_nvrtc passes an invalid multi-output name to multiple-outputs.sh.
      # Vulkan uses the installed proprietary NVIDIA driver directly and keeps
      # the P4 GPU path free of that broken CUDA build closure.
      package = pkgs.ollama-vulkan;
      host = "127.0.0.1";
      loadModels = [ cfg.localModel ];
      environmentVariables = {
        GGML_VK_VISIBLE_DEVICES = cfg.vulkanVisibleDevices;
        OLLAMA_CONTEXT_LENGTH = toString cfg.contextLength;
        OLLAMA_NUM_PARALLEL = "1";
      };
    };

    # Every local or hosted model is reached through this loopback-only,
    # OpenAI-compatible endpoint. Hosted-provider secrets come from a runtime
    # environment file rather than becoming world-readable Nix store paths.
    services.litellm = {
      enable = true;
      host = "127.0.0.1";
      port = 4000;
      environmentFile = cfg.litellmEnvironmentFile;
      settings = {
        model_list = [
          {
            model_name = cfg.localModel;
            litellm_params = {
              model = "ollama/${cfg.localModel}";
              api_base = "http://127.0.0.1:11434";
            };
          }
        ] ++ cfg.additionalModels;
      };
    };

    # Open WebUI is the only agent-stack listener exposed beyond loopback. Keep
    # its backend connection declarative so it cannot be redirected to an
    # arbitrary provider from the web UI.
    services.open-webui = {
      enable = true;
      # The default package set currently selects Python 3.14, where
      # torchcodec 0.16.0 fails its MP3 encoder tests. Open WebUI's embedding
      # dependency pulls that package in, so use the supported Python 3.13
      # dependency set until the Python 3.14 failure is fixed upstream.
      package = pkgs.open-webui.override {
        python3Packages = pkgs.python313Packages;
      };
      host = "0.0.0.0";
      port = cfg.webUiPort;
      environment = {
        ENABLE_OLLAMA_API = "False";
        ENABLE_OPENAI_API = "True";
        OPENAI_API_BASE_URL = "http://127.0.0.1:4000/v1";
        OPENAI_API_KEY = "local-gateway";
        ENABLE_PERSISTENT_CONFIG = "False";
        WEBUI_AUTH = "True";
        WEBUI_URL = "http://ai.s";
      };
    };

    # OpenHands needs an execution runtime. Provide a dedicated rootless
    # workspace, but intentionally do not mount a Docker/Podman socket into an
    # agent container: such a socket is effectively host-root access.
    virtualisation.podman.enable = true;
    users.groups.coding-agent = { };
    users.users.coding-agent = {
      isSystemUser = true;
      group = "coding-agent";
      home = "/var/lib/coding-agent";
      createHome = true;
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.openHandsWorkspace} 0750 coding-agent coding-agent -"
    ];

    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -A nixos-fw -p tcp --dport ${toString cfg.webUiPort} -s ${cfg.lanCidr} -j ACCEPT
      iptables -A nixos-fw -p tcp --dport ${toString cfg.webUiPort} -s ${cfg.wireGuardCidr} -j ACCEPT
    '';
  };
}
