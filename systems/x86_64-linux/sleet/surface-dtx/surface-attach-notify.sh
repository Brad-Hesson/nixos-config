# The attach handler runs as root. Find the active Plasma Wayland session and
# send a short notification into that user's session.

session_uid=""
session_gid=""
session_user=""
session_home=""
runtime_dir=""

log_info() {
  logger --tag surface-dtx-guard --priority daemon.info -- "$*"
}

log_warn() {
  logger --tag surface-dtx-guard --priority daemon.warning -- "$*"
}

setup_plasma_session() {
  local kwin_pid=""
  local proc comm exe entry

  for proc in /proc/[0-9]*; do
    [[ -r "$proc/comm" ]] || continue

    comm="$(cat "$proc/comm" 2>/dev/null || true)"
    exe="$(readlink -f "$proc/exe" 2>/dev/null || true)"

    if [[ "$comm" == *kwin_wayland* || "$exe" == *kwin_wayland* ]]; then
      kwin_pid="${proc##*/}"
      break
    fi
  done

  if [[ -z "$kwin_pid" ]]; then
    log_warn "base attached, but no Plasma Wayland session was found"
    return 1
  fi

  session_uid="$(stat -c '%u' "/proc/$kwin_pid")"
  session_gid="$(stat -c '%g' "/proc/$kwin_pid")"
  session_user="$(stat -c '%U' "/proc/$kwin_pid")"
  runtime_dir="/run/user/$session_uid"

  if [[ ! -S "$runtime_dir/bus" ]]; then
    log_warn "base attached, but Plasma session bus was not found at $runtime_dir/bus"
    return 1
  fi

  session_home=""
  if [[ -r "/proc/$kwin_pid/environ" ]]; then
    while IFS= read -r -d "" entry; do
      case "$entry" in
        HOME=*)
          session_home="${entry#*=}"
          ;;
      esac
    done < "/proc/$kwin_pid/environ"
  fi

  if [[ -z "$session_home" ]]; then
    session_home="/home/$session_user"
  fi
}

session_exec() {
  setpriv \
    --reuid="$session_uid" \
    --regid="$session_gid" \
    --init-groups \
    env \
      "HOME=$session_home" \
      "USER=$session_user" \
      "LOGNAME=$session_user" \
      "XDG_RUNTIME_DIR=$runtime_dir" \
      "DBUS_SESSION_BUS_ADDRESS=unix:path=$runtime_dir/bus" \
      "$@"
}

log_info "Surface base attach event received"

# Failure to display a desktop toast must never make the attach handler fail.
if ! setup_plasma_session; then
  exit 0
fi

if session_exec gdbus call \
  --session \
  --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.Notify \
  "Surface Detach" \
  0 \
  "computer-laptop" \
  "Surface base attached" \
  "Keyboard base reconnected." \
  "[]" \
  "{'desktop-entry': <'surface-detach-guard'>, 'resident': <false>, 'transient': <true>, 'urgency': <byte 0>}" \
  3500 \
  >/dev/null; then
  log_info "Surface base attach notification shown"
else
  log_warn "failed to show Surface base attach notification"
fi

exit 0
