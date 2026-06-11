# NixOS container test -- validates containers with nixosConfig/homeConfig.
#
# Replaces CST tests for: crossBuildJq, devShell, nixosPostgres.
# These containers require NixOS eval (nixosConfig) or home-manager
# (homeConfig), so they use the deploy module's full build pipeline.
#
# Validates:
#   - jq: binary runs (simple package, no cross-build in VM)
#   - devShell: zsh/starship/neovim/git/ripgrep available, dev user,
#     /home/dev exists, /etc/passwd has dev entry
#   - nixosPostgres: postgres binary runs, pg_hba.conf exists
#
# Run: nix build .#checks.x86_64-linux.vm-nixos-containers -L
{
  inputs,
  config,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
in
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      testHelpers = import ../lib.nix { inherit pkgs lib; };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-nixos-containers = testHelpers.mkVMTest {
          name = "nix-oci-nixos-containers";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [ nixosModule ];

              virtualisation.podman.enable = true;

              # Thread home-manager flake for devShell homeConfig.
              _module.args.home-manager-flake = inputs.home-manager;

              oci = {
                enable = true;
                backend = "podman";
                containers = {
                  # jq -- simple package (CST tested: jq binary, USER=jq)
                  # Cross-build aspects are tested by e2e multi-arch tests.
                  jq-test = {
                    package = pkgs.jq;
                    user = "jq";
                  };

                  # devShell -- nixosConfig + homeConfig
                  # CST tested: zsh, starship, neovim, git, ripgrep, dev user
                  dev-shell-test = {
                    package = pkgs.zsh;
                    isRoot = false;
                    user = "dev";
                    dependencies = with pkgs; [
                      bashInteractive
                      coreutils
                      git
                      ripgrep
                      starship
                      neovim
                    ];
                    entrypoint = [
                      "${pkgs.zsh}/bin/zsh"
                    ];
                    nixosConfig.modules = [ { } ];
                    homeConfig = {
                      homeManagerFlake = inputs.home-manager;
                      modules = [
                        (
                          { lib, ... }:
                          {
                            programs.zsh.enable = true;
                            programs.starship.enable = true;
                            programs.git = {
                              enable = true;
                              userName = "dev";
                              userEmail = "dev@container";
                            };
                            fonts.fontconfig.enable = lib.mkForce false;
                          }
                        )
                      ];
                    };
                  };

                  # nixosPostgres -- nixosConfig.mainService
                  # CST tested: postgres binary, pg_hba.conf exists
                  nixos-postgres = {
                    nixosConfig = {
                      mainService = "postgresql";
                      modules = [
                        (
                          { pkgs, ... }:
                          {
                            services.postgresql = {
                              enable = true;
                              package = pkgs.postgresql_16;
                              enableTCPIP = true;
                              settings = {
                                listen_addresses = "*";
                              };
                              authentication = ''
                                local all all trust
                                host  all all 0.0.0.0/0 md5
                              '';
                            };
                          }
                        )
                      ];
                    };
                    isRoot = true;
                  };
                };
              };
            };

          testScript = ''
            import json

            machine.wait_for_unit("multi-user.target")


            def wait_for_load(name):
                machine.wait_for_unit(f"oci-load-{name}.service")


            def image_inspect(image_ref):
                raw = machine.succeed(f"podman image inspect {image_ref}")
                return json.loads(raw)[0]


            def assert_user(image_ref, expected_user):
                info = image_inspect(image_ref)
                user = info.get("Config", {}).get("User", "")
                assert user == expected_user, \
                    f"Expected User={expected_user} in {image_ref}, got: {user}"


            def run_ep(image_ref, binary, args=""):
                cmd = "podman run --rm --entrypoint " + repr(binary) + " " + image_ref
                if args:
                    cmd += " " + args
                return machine.succeed(cmd)


            def assert_ep_output(image_ref, binary, args, expected):
                result = run_ep(image_ref, binary, args)
                assert expected in result, \
                    f"Expected '{expected}' in '{binary} {args}' output, got: {result[:200]}"


            _cp_counter = [0]

            def read_image_file(image_ref, path):
                """Read a file from the image filesystem (bypasses runtime mounts)."""
                _cp_counter[0] += 1
                cname = f"img-cp-{_cp_counter[0]}"
                machine.succeed(f"podman create --name {cname} {image_ref} true")
                content = machine.succeed(f"podman cp {cname}:{path} -")
                machine.succeed(f"podman rm {cname}")
                return content


            # ===================================================================
            # Load all images
            # ===================================================================

            with subtest("load all images"):
                for name in [
                    "jq-test",
                    "dev-shell-test",
                    "nixos-postgres",
                ]:
                    wait_for_load(name)

            # ===================================================================
            # jq-test (simple package -- replaces crossBuildJq CST)
            # ===================================================================

            with subtest("jq: User is jq"):
                assert_user("jq-test:latest", "jq")

            with subtest("jq: jq binary runs"):
                run_ep("jq-test:latest", "/bin/jq", "--version")

            # ===================================================================
            # dev-shell-test (nixosConfig + homeConfig -- replaces devShell CST)
            # ===================================================================

            with subtest("devShell: User is dev"):
                assert_user("dev-shell-test:latest", "dev")

            with subtest("devShell: zsh runs"):
                assert_ep_output(
                    "dev-shell-test:latest", "/bin/zsh", "--version", "zsh"
                )

            with subtest("devShell: starship runs"):
                assert_ep_output(
                    "dev-shell-test:latest", "/bin/starship", "--version", "starship"
                )

            with subtest("devShell: neovim runs"):
                assert_ep_output(
                    "dev-shell-test:latest", "/bin/nvim", "--version", "NVIM"
                )

            with subtest("devShell: git runs"):
                assert_ep_output(
                    "dev-shell-test:latest", "/bin/git", "--version", "git version"
                )

            with subtest("devShell: ripgrep runs"):
                assert_ep_output(
                    "dev-shell-test:latest", "/bin/rg", "--version", "ripgrep"
                )

            with subtest("devShell: /etc/passwd has dev user"):
                content = read_image_file("dev-shell-test:latest", "/etc/passwd")
                assert "dev" in content, \
                    f"passwd should contain dev user, got: {content[:200]}"

            with subtest("devShell: /home/dev exists"):
                # Use entrypoint to test directory existence
                run_ep("dev-shell-test:latest", "/bin/ls", "-d /home/dev")

            # ===================================================================
            # nixos-postgres (nixosConfig.mainService -- replaces nixosPostgres CST)
            # ===================================================================

            with subtest("postgres: postgres binary runs"):
                assert_ep_output(
                    "nixos-postgres:latest", "/bin/postgres", "--version", "postgres"
                )

            with subtest("postgres: pg_hba.conf exists"):
                content = read_image_file("nixos-postgres:latest", "/etc/postgresql/pg_hba.conf")
                assert len(content) > 0, "pg_hba.conf should exist and have content"
          '';
        };
      };
    };
}
