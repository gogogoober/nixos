{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      # 7 min idle → suspend; sleep.conf hibernates 8 min later (15 min total)
      listener = [
        {
          timeout = 420;
          on-timeout = "systemctl suspend-then-hibernate";
        }
      ];
    };
  };
}
