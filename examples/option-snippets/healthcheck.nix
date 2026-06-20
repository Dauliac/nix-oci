{
  package = pkgs.python3;
  dependencies = [ pkgs.curl ];
  entrypoint = [
    "${pkgs.python3}/bin/python3"
    "-m"
    "http.server"
    "8080"
  ];
  ports = [ "8080:8080" ];
  healthcheck = {
    command = [
      "${pkgs.curl}/bin/curl"
      "-f"
      "http://localhost:8080/"
    ];
    interval = 15;
    timeout = 3;
    startPeriod = 5;
    retries = 3;
  };
}
