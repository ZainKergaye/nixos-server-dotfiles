{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codingAgent;
  agentCanvasPort = 8000;
  openHandsApiKey = "local-agent-gateway";
  openHandsNetworkCidr = "172.30.0.0/24";
  openHandsProfile = pkgs.writeText "openhands-local-coder-profile.json" (
    builtins.toJSON {
      # Canvas otherwise deliberately omits `api_key` when it saves the
      # profile.  After its session expires or the container restarts it then
      # asks the user for a key again.  This is only the fixed, internal
      # LiteLLM gateway credential; it is not a hosted-provider secret.
      include_secrets = true;
      llm = {
        model = "openai/${cfg.localModel}";
        api_key = "local-gateway";
        api_mode = "chat";
        base_url = "http://172.30.0.1:4000/v1";
        max_input_tokens = cfg.contextLength;
        max_output_tokens = 4096;
        # Qwen3 supports Ollama's native tool-call interface, which is more
        # reliable for an agent than parsing tool calls from plain text.
        native_tool_calling = true;
      };
    }
  );
in
{
  options.codingAgent = with lib; {
    enable = mkEnableOption "a private local-model and coding-agent server";

    localModel = mkOption {
      type = types.str;
      # Qwen3 8B is a newer tool-capable model and its 5.2 GiB Q4
      # quantization leaves sufficient Tesla P4 VRAM for the configured
      # 24k-token KV cache.  Larger current coding models are 19 GiB or more
      # and would run mostly from system RAM on this host.
      default = "qwen3:8b";
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

    canvasPort = mkOption {
      type = types.port;
      default = 8081;
      description = "LAN-facing OpenHands Agent Canvas port";
    };

    lanCidr = mkOption {
      type = types.str;
      default = "10.10.10.0/24";
      description = "Physical LAN permitted to reach OpenHands Agent Canvas";
    };

    wireGuardCidr = mkOption {
      type = types.str;
      default = "10.100.0.0/24";
      description = "WireGuard clients permitted to reach OpenHands Agent Canvas";
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
    # The Tesla P4 has 8 GiB of VRAM. Qwen3 8B leaves enough room for a
    # 24k-token KV cache; larger current coding models would spill heavily
    # into system RAM.
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

    # Agent Canvas combines its browser UI, Agent Server, and automation API in
    # one container. Deliberately do not mount a Docker/Podman socket: a socket
    # would give agent code effective host-root access. UID/GID 10001 matches
    # Canvas's `openhands` user, so persistent state remains writable without
    # running the container as root.
    virtualisation.docker.enable = true;
    virtualisation.oci-containers = {
      backend = "docker";
      containers.openhands-agent = {
        image = "ghcr.io/openhands/agent-canvas:1.26.0";
        autoStart = true;
        ports = [ "0.0.0.0:${toString cfg.canvasPort}:${toString agentCanvasPort}" ];
        # Canvas persists conversations, profiles, encrypted secrets, and its
        # automation database below ~/.openhands.  It starts its own Agent
        # Server inside this container; users can only reach it through Canvas.
        volumes = [ "${cfg.openHandsWorkspace}:/home/openhands/.openhands" ];
        environment = {
          DO_NOT_TRACK = "1";
          OH_SECRET_KEY = "local-agent-state-key";
          LOCAL_BACKEND_API_KEY = openHandsApiKey;
        };
        extraOptions = [
          "--network=coding-agent"
          # Do not rely on the image's default USER: it must match the owner
          # of the host bind mount configured below.
          "--user=10001:10001"
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
      # Docker creates a missing bind-mount source as root.  tmpfiles' `d`
      # action intentionally leaves an already existing directory untouched,
      # so a deployment where Docker won that race would leave the image's
      # UID 10001 unable to traverse /workspace.  Repair the directory before
      # every container start, including after an out-of-band removal.
      preStart = ''
        ${pkgs.coreutils}/bin/install -d -m 0750 -o coding-agent -g coding-agent \
          ${lib.escapeShellArg cfg.openHandsWorkspace}
      '';
    };

    # Seed Canvas's bundled Agent Server with the local LiteLLM profile. Its
    # ingress proxies /api to the server, so the UI and this setup request use
    # the same authenticated endpoint.
    systemd.services.coding-agent-openhands-profile = {
      description = "Configure the OpenHands Canvas local coding-model profile";
      after = [ "docker-openhands-agent.service" ];
      requires = [ "docker-openhands-agent.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        attempts=0
        until ${pkgs.curl}/bin/curl --silent --show-error --fail --max-time 5 \
          http://127.0.0.1:${toString cfg.canvasPort}/health >/dev/null; do
          attempts=$((attempts + 1))
          if [ "$attempts" -ge 150 ]; then
            echo "OpenHands Canvas did not become ready within five minutes" >&2
            exit 1
          fi
          sleep 2
        done

        ${pkgs.curl}/bin/curl --fail --show-error \
          -H 'X-Session-API-Key: ${openHandsApiKey}' \
          -H 'Content-Type: application/json' \
          --data-binary @${openHandsProfile} \
        http://127.0.0.1:${toString cfg.canvasPort}/api/profiles/local-coder
      '';
    };

    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -A nixos-fw -p tcp --dport ${toString cfg.canvasPort} -s ${cfg.lanCidr} -j ACCEPT
      iptables -A nixos-fw -p tcp --dport ${toString cfg.canvasPort} -s ${cfg.wireGuardCidr} -j ACCEPT
      iptables -A nixos-fw -p tcp --dport 4000 -s ${openHandsNetworkCidr} -j ACCEPT
    '';
  };
}
