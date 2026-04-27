{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.modules.location = {
    city = mkOption {
      type = types.str;
      default = "New York";
      description = "City name. Used by weather and other location-aware modules.";
    };
    state = mkOption {
      type = types.str;
      default = "NY";
      description = "State, province, or region code.";
    };
    country = mkOption {
      type = types.str;
      default = "US";
      description = "ISO 3166-1 alpha-2 country code.";
    };
    units = mkOption {
      type = types.enum [
        "imperial"
        "metric"
      ];
      default = "imperial";
      description = "Unit system for weather, distance, and other physical quantities.";
    };
  };
}
