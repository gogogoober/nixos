{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.modules.location = {
    city = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "City name. Null lets services geolocate.";
    };
    state = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "State, province, or region code. Null lets services geolocate.";
    };
    country = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "ISO 3166-1 alpha-2 country code. Null lets services geolocate.";
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
