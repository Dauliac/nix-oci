{
  package = pkgs.python3;
  entrypoint = [
    "${pkgs.python3}/bin/python3"
    "-m"
    "http.server"
    "8080"
  ];
}
