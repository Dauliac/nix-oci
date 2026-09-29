# BDD test specs for the CST coherence generator (mkCoherenceCst).
#
# The generator builds a metadataTest JSON from the declared module
# config so container-structure-test can round-trip user intent against
# the built image. Each declared field lands in the emitted JSON only
# when the module option has a non-default value; empty fields are
# omitted rather than emitted as null / [] entries.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * Declared port appears in coherence output
#   * Declared entrypoint appears
#   * Declared user labels appear
#   * Declared workingDir appears
#   * Empty fields are omitted, not null
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-cst-coherence = {
        eval-defaults = {
          given = "a container with coherence disabled";
          "when" = "the container config is evaluated";
          "then" = "no coherence JSON is added to the CST config list";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-ports-round-trip = {
          given = "a container declaring ports [\"8080:80\"]";
          "when" = "mkCoherenceCst renders the metadataTest JSON";
          "then" = "the emitted JSON contains exposedPorts including \"80\"";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            ports = [ "8080:80" ];
            test.containerStructureTest = {
              enabled = true;
              coherence = true;
            };
          };
        };

        build-entrypoint-round-trip = {
          given = "a container declaring a multi-arg entrypoint";
          "when" = "mkCoherenceCst renders the metadataTest JSON";
          "then" = "the emitted entrypoint list matches the declared value exactly";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            entrypoint = [
              "/bin/myapp"
              "--flag"
            ];
            test.containerStructureTest = {
              enabled = true;
              coherence = true;
            };
          };
        };

        build-user-labels-round-trip = {
          given = "a container declaring user-defined OCI labels";
          "when" = "mkCoherenceCst renders the metadataTest JSON";
          "then" = "the emitted labels list contains the user-declared key/value pairs";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            labels = {
              "org.example.owner" = "team-x";
              "org.example.tier" = "prod";
            };
            test.containerStructureTest = {
              enabled = true;
              coherence = true;
            };
          };
        };

        build-workdir-round-trip = {
          given = "a container declaring workingDir = \"/srv\"";
          "when" = "mkCoherenceCst renders the metadataTest JSON";
          "then" = "the emitted workdir field equals \"/srv\"";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            workingDir = "/srv";
            test.containerStructureTest = {
              enabled = true;
              coherence = true;
            };
          };
        };

        build-volumes-round-trip = {
          given = "a container declaring declaredVolumes";
          "when" = "mkCoherenceCst renders the metadataTest JSON";
          "then" = "the emitted volumes list matches the declared entries";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            declaredVolumes = [
              "/var/lib/data"
              "/tmp"
            ];
            test.containerStructureTest = {
              enabled = true;
              coherence = true;
            };
          };
        };

        build-empty-fields-omitted = {
          given = "a container with no explicit ports, labels, volumes, or workingDir";
          "when" = "mkCoherenceCst renders the metadataTest JSON";
          "then" = "the emitted JSON omits those keys entirely rather than emitting null / []";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            test.containerStructureTest = {
              enabled = true;
              coherence = true;
            };
          };
        };
      };
    };
}
