{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codingAgent;
  openWebUiPkgs = import inputs.open-webui-nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  openHandsPort = 8000;
  openHandsApiKey = "local-agent-gateway";
  openHandsNetworkCidr = "172.30.0.0/24";
  openHandsProfile = pkgs.writeText "openhands-local-coder-profile.json" (
    builtins.toJSON {
      include_secrets = false;
      llm = {
        model = "openai/${cfg.localModel}";
        api_key = "local-gateway";
        api_mode = "chat";
        base_url = "http://172.30.0.1:4000/v1";
        max_input_tokens = cfg.contextLength;
        max_output_tokens = 4096;
        native_tool_calling = false;
      };
    }
  );
in
{
  options.codingAgent = with lib; {
    enable = mkEnableOption "a private local-model and coding-agent server";

    localModel = mkOption {
      type = types.str;
      # The 7B Q4 model is 4.7 GiB, leaving sufficient P4 VRAM for a useful
      # KV cache at the configured context size.
      default = "qwen2.5-coder:7b";
      description = "Ollama coding model pulled for private, local requests";
    };

    vulkanVisibleDevices = mkOption {
      type = types.str;
      default = "1";
      description = "Vulkan-visible GPU indexes for Ollama; node3's Tesla P4 is GPU 1";
    };

    contextLength = mkOption {
      type = types.ints.positive;
      default = 24576;
      description = "Ollama context window sized to remain in the P4's 8 GiB VRAM";
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
      description = "Persistent workspace directory mounted into the OpenHands sandbox";
    };
  };

  config = lib.mkIf cfg.enable {
    # The Tesla P4 has 8 GiB of VRAM. Qwen2.5-Coder 7B is the strongest
    # code-specialized model that leaves enough room for a 24k-token KV cache;
    # larger models or a full 32k cache would spill into system RAM.
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

    # The local model is served to host processes and the isolated OpenHands
    # network. Hosted-provider secrets remain in a runtime environment file.
    services.litellm = {
      enable = true;
      host = "0.0.0.0";
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

    # Open WebUI presents both the normal LiteLLM model and the OpenHands
    # OpenAI-compatible gateway as selectable models.
    services.open-webui = {
      enable = true;
      # Pin to Open WebUI 0.9.1 from Nixpkgs before Python 3.14/TorchCodec
      # entered its dependency closure.
      package = openWebUiPkgs.open-webui;
      host = "0.0.0.0";
      port = cfg.webUiPort;
      environment = {
        ENABLE_OLLAMA_API = "False";
        ENABLE_OPENAI_API = "True";
        OPENAI_API_BASE_URLS = "http://127.0.0.1:4000/v1;http://127.0.0.1:${toString openHandsPort}/v1";
        OPENAI_API_KEYS = "local-gateway;${openHandsApiKey}";
        ENABLE_PERSISTENT_CONFIG = "False";
        WEBUI_AUTH = "True";
        WEBUI_URL = "http://ai.s";
      };
    };

    # OpenHands Agent Server runs directly in its sandbox container. Deliberately
    # do not mount a Docker/Podman socket: a socket would give agent code
    # effective host-root access. UID/GID 10001 matches the image's `openhands`
    # user, so the persistent workspace remains writable without root.
    virtualisation.docker.enable = true;
    virtualisation.oci-containers = {
      backend = "docker";
      containers.openhands-agent = {
        image = "ghcr.io/openhands/agent-server:1.54.0-python";
        autoStart = true;
        cmd = [ "--host" "0.0.0.0" "--port" (toString openHandsPort) ];
        ports = [ "127.0.0.1:${toString openHandsPort}:${toString openHandsPort}" ];
        volumes = [ "${cfg.openHandsWorkspace}:/workspace" ];
        environment = {
          DO_NOT_TRACK = "1";
          OH_PERSISTENCE_DIR = "/workspace/.openhands";
          OH_SECRET_KEY = "local-agent-state-key";
          OH_SESSION_API_KEYS_0 = openHandsApiKey;
        };
        extraOptions = [
          "--network=coding-agent"
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges"
          "--pids-limit=512"
        ];
      };
    };
    users.groups.coding-agent.gid = 10001;
    users.users.coding-agent = {
      isSystemUser = true;
      group = "coding-agent";
      uid = 10001;
      home = "/var/lib/coding-agent";
      createHome = true;
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.openHandsWorkspace} 0750 coding-agent coding-agent -"
    ];

    # A user-defined network gives the sandbox access only to LiteLLM's model
    # endpoint on the host; it never receives the host Docker socket.
    systemd.services.docker-coding-agent-network = {
      description = "Coding-agent Docker network";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      before = [ "docker-openhands-agent.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        if ! ${config.virtualisation.docker.package}/bin/docker network inspect coding-agent >/dev/null 2>&1; then
          ${config.virtualisation.docker.package}/bin/docker network create --subnet ${openHandsNetworkCidr} coding-agent
        fi
      '';
    };
    systemd.services.docker-openhands-agent = {
      after = [ "docker-coding-agent-network.service" ];
      requires = [ "docker-coding-agent-network.service" ];
    };

    # Seed the local LLM profile before Open WebUI lists the Agent Server's
    # models. The profile points through LiteLLM, preserving one local model
    # path for ordinary chats and agent conversations.
    systemd.services.coding-agent-openhands-profile = {
      description = "Configure the OpenHands local coding-model profile";
      after = [ "docker-openhands-agent.service" ];
      requires = [ "docker-openhands-agent.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        attempts=0
        until ${pkgs.curl}/bin/curl --silent --show-error --fail --max-time 5 \
          http://127.0.0.1:${toString openHandsPort}/health >/dev/null; do
          attempts=$((attempts + 1))
          if [ "$attempts" -ge 150 ]; then
            echo "OpenHands Agent Server did not become ready within five minutes" >&2
            exit 1
          fi
          sleep 2
        done

        ${pkgs.curl}/bin/curl --fail --show-error \
          -H 'Authorization: Bearer ${openHandsApiKey}' \
          -H 'Content-Type: application/json' \
          --data-binary @${openHandsProfile} \
        http://127.0.0.1:${toString openHandsPort}/api/profiles/local-coder
      '';
    };
    systemd.services.open-webui = {
      after = [ "coding-agent-openhands-profile.service" ];
      requires = [ "coding-agent-openhands-profile.service" ];
    };

    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -A nixos-fw -p tcp --dport ${toString cfg.webUiPort} -s ${cfg.lanCidr} -j ACCEPT
      iptables -A nixos-fw -p tcp --dport ${toString cfg.webUiPort} -s ${cfg.wireGuardCidr} -j ACCEPT
      iptables -A nixos-fw -p tcp --dport 4000 -s ${openHandsNetworkCidr} -j ACCEPT
    '';
  };
}
