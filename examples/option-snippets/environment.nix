{
  package = pkgs.hello;
  environment = {
    RUST_LOG = "info";
    APP_ENV = "production";
  };
}
