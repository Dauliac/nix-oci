# Example: Nginx serving a Nix-built static site
#
# Demonstrates the full nix-oci pipeline: a static website is built as a
# pure Nix derivation, then served by an nginx container configured via
# NixOS modules. The entire build -- site generation, nginx config, container
# image -- is a single reproducible Nix expression.
#
# What this shows:
# - Building a static site as a Nix derivation (pkgs.runCommand)
# - Injecting build artifacts into NixOS module config
# - Cache-control headers for static assets
# - Gzip + precompressed static files
# - SPA (single-page app) fallback routing
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosNginxStaticSite = {
            mainService = "nginx";
            nixosConfig.modules = [
                (
                  { pkgs, ... }:
                  let
                    # Build the static site as a pure Nix derivation.
                    # In a real project this could be:
                    #   - pkgs.buildNpmPackage for a React/Vue/Svelte app
                    #   - pkgs.stdenv.mkDerivation for a Hugo/Zola/mdBook site
                    #   - An input from another flake
                    staticSite =
                      pkgs.runCommand "my-static-site"
                        {
                          nativeBuildInputs = [ pkgs.gzip ];
                        }
                        ''
                          mkdir -p $out/{css,js,img}

                          cat > $out/index.html <<'HTML'
                          <!DOCTYPE html>
                          <html lang="en">
                          <head>
                            <meta charset="utf-8">
                            <meta name="viewport" content="width=device-width, initial-scale=1">
                            <title>nix-oci Static Site</title>
                            <link rel="stylesheet" href="/css/style.css">
                          </head>
                          <body>
                            <main>
                              <h1>Built with nix-oci</h1>
                              <p>This entire site -- HTML, CSS, nginx config, and container image --
                                 is a single reproducible Nix expression.</p>
                              <p>Build hash: <code>@buildHash@</code></p>
                            </main>
                            <script src="/js/app.js"></script>
                          </body>
                          </html>
                          HTML

                          cat > $out/css/style.css <<'CSS'
                          :root { --bg: #0a0a0a; --fg: #e0e0e0; --accent: #7c3aed; }
                          body { font-family: system-ui, sans-serif; background: var(--bg); color: var(--fg); margin: 0; padding: 2rem; }
                          main { max-width: 48rem; margin: 0 auto; }
                          h1 { color: var(--accent); }
                          code { background: #1a1a2e; padding: 0.2em 0.4em; border-radius: 4px; }
                          CSS

                          cat > $out/js/app.js <<'JS'
                          console.log("nix-oci static site loaded");
                          JS

                          # Pre-compress static files for nginx gzip_static
                          find $out -name '*.html' -o -name '*.css' -o -name '*.js' | while read f; do
                            gzip -9 -k "$f"
                          done
                        '';
                  in
                  {
                    services.nginx = {
                      enable = true;

                      recommendedGzipSettings = true;
                      recommendedOptimisation = true;

                      virtualHosts."localhost" = {
                        root = "${staticSite}";
                        listen = [
                          {
                            addr = "0.0.0.0";
                            port = 8080;
                          }
                        ];

                        extraConfig = ''
                          # Serve pre-compressed .gz files when available
                          gzip_static on;
                        '';

                        locations."/" = {
                          # SPA fallback: try file, then directory, then index.html
                          tryFiles = "$uri $uri/ /index.html";
                          extraConfig = ''
                            add_header X-Content-Type-Options "nosniff" always;
                            add_header X-Frame-Options "SAMEORIGIN" always;
                          '';
                        };

                        # Immutable cache for hashed assets
                        # Security headers must be repeated here -- nginx drops
                        # parent add_header directives when a location defines its own.
                        locations."~* \\.(css|js|woff2?|ttf|eot|svg|png|jpg|jpeg|gif|ico|webp)$" = {
                          extraConfig = ''
                            expires 1y;
                            add_header Cache-Control "public, immutable";
                            add_header X-Content-Type-Options "nosniff" always;
                            add_header X-Frame-Options "SAMEORIGIN" always;
                          '';
                        };

                        # Health endpoint
                        locations."/health" = {
                          extraConfig = ''
                            return 200 '{"status":"healthy"}';
                            default_type application/json;
                          '';
                        };
                      };
                    };
                  }
                )
              ];
            isRoot = true;
            ports = [ "8080:8080" ];
            labels = {
              "org.opencontainers.image.title" = "nginx-static-site";
              "org.opencontainers.image.description" =
                "Nginx serving a Nix-built static site with pre-compression";
            };
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./nginx-static-site-cst.yaml
              ];
            };
          };
        };
      };
  };
}
