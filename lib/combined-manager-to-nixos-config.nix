config:
config
// {
  class = "nixos";
  options = config.options.os;
  config = config.config.os;
}
