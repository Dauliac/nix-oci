# BDD spec for network label coherence (z83.7.14).
#
# Covers spec `Requirement: Network label coherence`:
#   network.tcp-ports and network.udp-ports must reflect the
#   declared `ports` list.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-label-network = {
        inspect-tcp-port-label = {
          given = "a container with a TCP port declared";
          "when" = "the OCI image is inspected";
          "then" = "the network.tcp-ports label matches the container-side port";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            ports = [ "8080:80/tcp" ];
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.network.tcp-ports" = "80";
          };
        };

        inspect-udp-port-label = {
          given = "a container with a UDP port declared";
          "when" = "the OCI image is inspected";
          "then" = "the network.udp-ports label matches the container-side port";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            ports = [ "53:53/udp" ];
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.network.udp-ports" = "53";
          };
        };
      };
    };
}
