{ lib, ... }:
{
  options = {
    networkPreset = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "web-server"
          "high-throughput"
          "low-latency"
        ]
      );
      default = null;
      description = ''
        Curated network sysctl preset. Expands to concrete `sysctls`
        entries via `mkDefault` -- explicit `sysctls` always take precedence.

        - `"web-server"` -- optimized for HTTP servers:
          `somaxconn=65535, tcp_fastopen=3, tcp_tw_reuse=1,
           tcp_fin_timeout=15, tcp_slow_start_after_idle=0,
           ip_local_port_range=1024 65535`

        - `"high-throughput"` -- maximizes network throughput:
          web-server settings plus increased buffer sizes
          (`rmem_max=67108864, wmem_max=67108864,
           netdev_max_backlog=65535`)

        - `"low-latency"` -- optimized for latency-sensitive workloads:
          web-server settings plus BBR congestion control
          (`tcp_congestion_control=bbr, default_qdisc=fq`)

        - `null` -- no preset (only explicit `sysctls` apply).
      '';
      example = "web-server";
    };

    sysctls = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Per-container sysctl overrides. Keys are sysctl names, values
        are strings. Only namespaced (network) sysctls are allowed
        without host privileges.

        Translated to `--sysctl key=value` container runtime flags.

        Common performance tunables:
        - `"net.core.somaxconn"` = `"65535"` -- listen backlog
        - `"net.ipv4.tcp_fastopen"` = `"3"` -- TCP Fast Open
        - `"net.ipv4.tcp_tw_reuse"` = `"1"` -- TIME_WAIT reuse
        - `"net.ipv4.ip_local_port_range"` = `"1024 65535"` -- ephemeral ports
      '';
      example = {
        "net.core.somaxconn" = "65535";
        "net.ipv4.tcp_fastopen" = "3";
      };
    };
  };
}
