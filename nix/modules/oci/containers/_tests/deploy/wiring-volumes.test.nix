# BDD test specs for volumes wiring at deploy level.
#
# Covers requirement `Volumes wiring` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# Two independent surfaces converge on the running container:
#  1. `declaredVolumes = [ "/data" ]` -> baked into the OCI image
#     config's Volumes attrset (image-level metadata).
#  2. `volumes = [ "/host-path:/container-path" ]` -> passed through
#     virtualisation.oci-containers.containers.<n>.volumes to the
#     runner as a bind mount at deploy time; the probe file placed
#     on the host must be readable inside the container.
#
# Both are asserted in one scenario via the runtime escape hatch.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-wiring-volumes = {
        deploy-wiring-volumes-both-surfaces = {
          given = "a Caddy deploy container with declaredVolumes = [ /data ] and volumes = [ /run/wiring-probe:/probe ]";
          "when" = "the loader + runner boot as daemon";
          "then" = "the image Volumes attrset lists /data and the host probe file is readable at /probe inside the container";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "8084:80/tcp" ];
            declaredVolumes = [ "/data" ];
            # Host directory is created by the runner (podman/docker
            # auto-creates missing bind sources as directories). We
            # then drop a probe file inside it and read it back from
            # the container. Using a directory (not a file) avoids
            # the "podman creates an empty dir instead of the file"
            # foot-gun.
            volumes = [ "/run/wiring-probe:/probe:ro" ];
            nixosConfig = {
              mainService = "caddy";
              modules = [
                (
                  { ... }:
                  {
                    services.caddy = {
                      enable = true;
                      virtualHosts.":80".extraConfig = ''
                        respond "wiring-volumes-ok"
                      '';
                    };
                  }
                )
              ];
            };
          };
          assertions.runtime = ''
            import subprocess

            _cid = "deploy-wiring-volumes--deploy-wiring-volumes-both-surfaces"

            # (1) OCI image Volumes attrset lists /data.
            _img = client.images.get(_cid + ":latest")
            _vols = (_img.attrs.get("Config") or {}).get("Volumes") or {}
            assert "/data" in _vols, (
                f"Expected /data in image Volumes, got: {list(_vols)}"
            )

            # (2) Populate the bind source (a directory) with a
            # probe file and read it back from inside the running
            # container at /probe/token. The runner already
            # bind-mounts /run/wiring-probe -> /probe ro.
            _probe_body = "volumes-wiring-probe-token"
            subprocess.run(
                ["mkdir", "-p", "/run/wiring-probe"], check=True,
            )
            subprocess.run(
                ["sh", "-c", f"printf %s '{_probe_body}' > /run/wiring-probe/token"],
                check=True,
            )

            _c = client.containers.get(_cid)
            _rc, _out = _c.exec_run(["cat", "/probe/token"])
            _text = _out.decode("utf-8", errors="replace") if isinstance(_out, bytes) else str(_out)
            assert _probe_body in _text, (
                f"Expected {_probe_body!r} readable at container /probe/token, got: {_text[:500]}"
            )
          '';
        };
      };
    };
}
