{pkgs, ... }:
{
  name = "pyroscope";
  nodes.server =
    { ... }:
    {
      environment.systemPackages = [ pkgs.xh ];
      services.pyroscope = {
        enable = true;
        configuration.server.http_listen_port = 4040;
      };
    };

  testScript = ''
    start_all()
    server.wait_for_unit("pyroscope.service")
    server.wait_for_open_port(4040)

    # takes around 15 seconds
    server.wait_until_succeeds("xh localhost:4040/ready")

    server.succeed("xh get localhost:4040/pyroscope/render query==process_cpu:cpu:nanoseconds:cpu:nanoseconds")
  '';
}
