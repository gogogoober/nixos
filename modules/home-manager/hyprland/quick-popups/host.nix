{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;
  enabledPopups = filterAttrs (_: p: p.enable) cfg.popups;

  classPrefix = "dev.hypr-popup";
  classOf = id: "${classPrefix}.${id}";
  workspaceOf = id: "popup-${id}";

  popupWidth = 800;
  popupHeight = 500;
  rightOffset = 20;
  topOffset = 40;

  # Mirrors barHeight (28) + barMargin (3) from bar.nix with a 1px buffer.
  # Clicks above this y belong to waybar's on-click and should not dismiss.
  barReservedY = 32;

  # Lock records the class the click handler just dismissed, so the bar
  # icon's on-click that fired the dismiss does not also respawn it.
  dismissLock = "/tmp/hypr-popup-dismissed-$USER";
  dismissGuardMs = 300;
  reconnectDelaySec = 1;

  # Generated case branches mapping popup id to its launch metadata. Used
  # by the launcher to resolve `hypr-popup <name>`.
  metaCase = concatStringsSep "\n  " (mapAttrsToList (id: p:
    "${id}) cmd=${escapeShellArg p.command}; persistent=${if p.persistent then "1" else "0"}; refresh_sig=${toString (if p.refreshSignal == null then 0 else p.refreshSignal)} ;;"
  ) enabledPopups);

  # Generated case branches marking which popup ids are persistent. Used by
  # every script that needs to act on an arbitrary popup window. Ephemerals
  # contribute nothing — they fall through to the catchall and stay at the
  # default c_persistent=0.
  persistentBranches = mapAttrsToList (id: _: "${id}) c_persistent=1 ;;")
    (filterAttrs (_: p: p.persistent) enabledPopups);
  persistentCase = concatStringsSep "\n    " (persistentBranches ++ [ "*) ;;" ]);

  scriptPath = makeBinPath [
    pkgs.hyprland
    pkgs.jq
    pkgs.ghostty
    pkgs.procps
    pkgs.socat
    pkgs.coreutils
  ];

  # Build-time constants injected at the top of each script. Values are
  # already-quoted bash literals; double quotes around DISMISS_LOCK let
  # $USER expand at runtime.
  constants = {
    CLASS_PREFIX = ''"${classPrefix}"'';
    DISMISS_LOCK = ''"${dismissLock}"'';
    DISMISS_GUARD_MS = toString dismissGuardMs;
    BAR_RESERVED_Y = toString barReservedY;
    RECONNECT_DELAY_SEC = toString reconnectDelaySec;
  };

  mkPrelude = vars: ''
    PATH=${scriptPath}:$PATH
  '' + concatStringsSep "\n" (map (v: "${v}=${constants.${v}}") vars) + "\n";

  # Read the script body, drop the shebang (writeShellScriptBin re-adds one),
  # inject the prelude, and replace the case-body markers with the generated
  # branches.
  mkScript = { src, vars }:
    let
      body = builtins.readFile src;
      shebang = "#!/usr/bin/env bash\n";
      withoutShebang = removePrefix shebang body;
      substituted = replaceStrings
        [ "# @POPUP_META_CASE@" "# @PERSISTENT_CASE@" ]
        [ metaCase persistentCase ]
        withoutShebang;
    in
      mkPrelude vars + substituted;

  hyprPopup = pkgs.writeShellScriptBin "hypr-popup" (mkScript {
    src = ./scripts/launcher.sh;
    vars = [ "CLASS_PREFIX" "DISMISS_LOCK" "DISMISS_GUARD_MS" ];
  });

  hyprPopupClickHandler = pkgs.writeShellScriptBin "hypr-popup-click-handler" (mkScript {
    src = ./scripts/click-handler.sh;
    vars = [ "CLASS_PREFIX" "DISMISS_LOCK" "BAR_RESERVED_Y" ];
  });

  hyprPopupWatcher = pkgs.writeShellScriptBin "hypr-popup-watcher" (mkScript {
    src = ./scripts/watcher.sh;
    vars = [ "CLASS_PREFIX" "RECONNECT_DELAY_SEC" ];
  });

  # Geometry rules apply uniformly to every popup via class regex. Workspace
  # assignment is per-popup since each persistent popup owns its own special
  # workspace, so only one persistent is visible at a time.
  classRegex = "^(dev\\.hypr-popup\\..*)$";

  geometryRules = [
    "float on,                                                                       match:class ${classRegex}"
    "size ${toString popupWidth} ${toString popupHeight},                            match:class ${classRegex}"
    "move (monitor_w-window_w-${toString rightOffset}) ${toString topOffset},        match:class ${classRegex}"
    "no_blur on,                                                                     match:class ${classRegex}"
    "no_shadow on,                                                                   match:class ${classRegex}"
    "no_anim on,                                                                     match:class ${classRegex}"
    "rounding 0,                                                                     match:class ${classRegex}"
  ];

  workspaceRules = mapAttrsToList (id: _:
    "workspace special:${workspaceOf id} silent,                                     match:class ^(${classOf id})$"
  ) (filterAttrs (_: p: p.persistent) enabledPopups);

  popupPackages = concatLists (mapAttrsToList (_: p: p.packages) enabledPopups);

  validIdPattern = "^[a-zA-Z0-9_-]+$";
in
{
  options.modules.hyprland.popups = mkOption {
    description = "Per-popup definitions consumed by the quick-popup host.";
    default = { };
    type = types.attrsOf (types.submodule {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether this popup is registered with the host.";
        };
        command = mkOption {
          type = types.str;
          description = "Shell command run inside the popup terminal.";
        };
        persistent = mkOption {
          type = types.bool;
          default = false;
          description = "Keep the process alive in a special workspace when hidden.";
        };
        refreshSignal = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "SIGRTMIN+N sent to waybar on dismiss for instant module refresh.";
        };
        packages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "Packages installed alongside this popup.";
        };
      };
    });
  };

  config = mkIf cfg.enable {
    assertions = mapAttrsToList (id: _: {
      assertion = builtins.match validIdPattern id != null;
      message = "modules.hyprland.popups.\"${id}\": popup id must match ${validIdPattern} (used as a window class and bash case pattern).";
    }) cfg.popups;

    home.packages = [
      hyprPopup
      hyprPopupClickHandler
      hyprPopupWatcher
      pkgs.socat
    ] ++ popupPackages;

    wayland.windowManager.hyprland.settings = {
      windowrule = geometryRules ++ workspaceRules;
      bindn = [ ", mouse:272, exec, hypr-popup-click-handler" ];
      exec-once = [ "hypr-popup-watcher" ];
    };
  };
}
