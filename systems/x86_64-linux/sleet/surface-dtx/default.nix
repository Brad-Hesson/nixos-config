{ lib, pkgs, ... }:

let
  surfaceDtxDaemon = pkgs.rustPlatform.buildRustPackage {
    pname = "surface-dtx-daemon";
    version = "0.3.11";

    src = builtins.fetchGit {
      url = "https://github.com/linux-surface/surface-dtx-daemon.git";
      rev = "ed4466356d9e63abe95b4937afbb0a8e99f9a698";
    };

    cargoHash = "sha256-5V9BY8ucAYvHZapmILI1JQDwDLlQDZW3GR2YEaySifA=";

    nativeBuildInputs = [
      pkgs.pkg-config
    ];

    buildInputs = [
      pkgs.dbus
    ];

    cargoBuildFlags = [
      "-p"
      "surface-dtx-daemon"
    ];

    cargoInstallFlags = [
      "--path"
      "surface-dtx-daemon"
    ];

    postInstall = ''
      # D-Bus system policy required for surface-dtx-daemon to own its bus name.
      mkdir -p $out/etc/dbus-1/system.d
      cp etc/dbus/*.conf $out/etc/dbus-1/system.d/

      # Upstream DTX udev integration.
      mkdir -p $out/lib/udev/rules.d
      cp etc/udev/*.rules $out/lib/udev/rules.d/
    '';
  };

  detachGuard = pkgs.writeShellApplication {
    name = "surface-dtx-detach-guard";

    runtimeInputs = with pkgs; [
      coreutils
      procps
      util-linux
      psmisc
      glib
      surface-control
    ];

    text = builtins.readFile ./surface-detach-guard.sh;
  };

  attachNotifier = pkgs.writeShellApplication {
    name = "surface-dtx-attach-notify";

    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      glib
    ];

    text = builtins.readFile ./surface-attach-notify.sh;
  };

  # Give the notification a real application identity. Plasma uses the
  # desktop-entry hint to associate notifications with an application and its
  # notification-center/history settings. NoDisplay keeps it out of launchers.
  desktopEntry = pkgs.writeTextDir "share/applications/surface-detach-guard.desktop" ''
    [Desktop Entry]
    Type=Application
    Name=Surface Detach
    Comment=Surface Book base detach guard
    Icon=computer-laptop
    Exec=${pkgs.coreutils}/bin/true
    NoDisplay=true
    Terminal=false
    Categories=System;
  '';

  dtxConfig = pkgs.writeText "surface-dtx-daemon.conf" ''
    [log]
    level = "info"

    [handler.detach]
    exec = "${detachGuard}/bin/surface-dtx-detach-guard"

    # Allow a long interactive session while applications are being closed.
    timeout = 3600

    [handler.attach]
    exec = "${attachNotifier}/bin/surface-dtx-attach-notify"

    # Notify as soon as the daemon receives the re-attach event. The upstream
    # default is 5 seconds, intended for handlers that need devices fully set up.
    delay = 0
    timeout = 15
  '';

in
{
  environment.systemPackages = [
    pkgs.surface-control
    surfaceDtxDaemon
    desktopEntry
  ];

  boot.kernelModules = [
    "surface_dtx"
  ];

  services.udev.packages = [
    surfaceDtxDaemon
  ];

  services.dbus.packages = [
    surfaceDtxDaemon
  ];

  # There should only be one DTX daemon running. This intentionally replaces
  # any unit supplied by another Surface module.
  systemd.services.surface-dtx-daemon = {
    description = "Surface Detachment System (DTX) Daemon";
    wantedBy = [ "multi-user.target" ];

    after = [
      "systemd-modules-load.service"
      "dbus.service"
    ];

    serviceConfig = {
      Type = "simple";

      ExecStart = lib.mkForce ''
        ${surfaceDtxDaemon}/bin/surface-dtx-daemon \
          --no-log-time \
          -c ${dtxConfig}
      '';

      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
}
