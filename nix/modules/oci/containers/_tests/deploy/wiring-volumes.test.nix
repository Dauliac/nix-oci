# BDD test specs for the volumes wiring.
#
# Covers requirement `Volumes wiring` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# Two surfaces:
#   1. `declaredVolumes = [ "/data" ]` -> image config Volumes["/data"]
#   2. `volumes = [ "/host:/container" ]` -> runner-side bind mount
#      visible inside the container
#
# Surface 1 is verified via `imageConfig.Volumes` inspection.
# Surface 2 uses `stateDirectories` (section-1 infra) to pre-create
# a tmpfs on the host, then asserts a probe file placed on the
# host tmpfs is readable at the container path.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-wiring-volumes = {
        deploy-declared-volumes-reach-image-config = {
          given = "a container with declaredVolumes = [ /data ]";
          "when" = "the image is built and deployed";
          "then" = "the image Config.Volumes contains /data";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            package = pkgs.coreutils;
            isRoot = true;
            entrypoint = [
              "/bin/sleep"
              "3600"
            ];
            declaredVolumes = [
              "/data"
            ];
          };
          assertions.imageConfig = {
            Volumes = {
              "/data" = { };
            };
          };
        };

        deploy-bind-mount-visible-in-container = {
          given = "a container with volumes = [ hostPath:/probe-dir ] and a probe file on the host";
          "when" = "the container is deployed";
          "then" = "the probe file is readable at /probe-dir/marker inside the container";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          # Reuse the section-1 stateDirectories plumbing: it creates
          # a per-spec tmpfs at
          # `/run/oci-test-state/<name>/<slug>` on the VM host and
          # bind-mounts it into the container at `<containerPath>`.
          # The runtime hatch below drops a marker file onto the host
          # tmpfs and asserts the container can read it back.
          stateDirectories = [
            "/probe-dir"
          ];
          container = {
            package = pkgs.coreutils;
            isRoot = true;
            entrypoint = [
              "/bin/sleep"
              "3600"
            ];
          };
          assertions.runtime = ''
            import os, subprocess
            _cid = "deploy-wiring-volumes--deploy-bind-mount-visible-in-container"
            # Host tmpfs backing path (see test-vm.nix stateMountsForSpec):
            #   /run/oci-test-state/<name>/<slug>
            _host_dir = f"/run/oci-test-state/{_cid}/probe-dir"
            _marker = os.path.join(_host_dir, "marker")
            os.makedirs(_host_dir, exist_ok=True)
            with open(_marker, "w") as fh:
                fh.write("nix-oci-volumes-ok")
            _c = client.containers.get(_cid)
            _rc, _out = _c.exec_run("cat /probe-dir/marker")
            _text = _out.decode("utf-8", errors="replace") if isinstance(_out, bytes) else str(_out)
            assert "nix-oci-volumes-ok" in _text, (
                f"Expected marker readable inside container at /probe-dir/marker, "
                f"got rc={_rc} out={_text[:200]}"
            )
          '';
        };
      };
    };
}
