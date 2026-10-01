#!/bin/bash
set -e

# /init scrubs the environment before running CMD; rehydrate it so HERMES_HOME,
# PATH and the Railway service variables are visible (same as upstream's
# docker/main-wrapper.sh).
if [ -z "${HERMES_START_ENV_READY:-}" ] && [ -x /command/with-contenv ]; then
    export HERMES_START_ENV_READY=1
    exec /command/with-contenv bash "$0" "$@"
fi

export HOME=/opt/data
cd /opt/data
# shellcheck disable=SC1091
. /opt/hermes/.venv/bin/activate

# The dashboard is NOT started here. The image ships its own supervised
# dashboard service (docker/s6-rc.d/dashboard), gated on HERMES_DASHBOARD and
# bound via HERMES_DASHBOARD_HOST/_PORT, with auth from
# HERMES_DASHBOARD_BASIC_AUTH_USERNAME/_PASSWORD.

# Teams is a plugin platform, so Hermes derives its default toolset name as
# "hermes-teams" - which is not a registered toolset in v2026.8.3. With that
# value the Teams bot runs with NO tools ("platform 'teams' has no valid
# toolsets configured ... See issue #38798"). Point it at the full core
# toolset (same set Telegram/CLI get) instead.
if [ -f /opt/data/config.yaml ] && grep -qE '^\s*- hermes-teams$' /opt/data/config.yaml; then
    sed -i 's/^\(\s*- \)hermes-teams$/\1hermes-cli/' /opt/data/config.yaml
    echo "[railway-start] platform_toolsets.teams: hermes-teams -> hermes-cli"
fi

if [ "$(id -u)" = 0 ]; then
    # Files copied in from a local install (uid 501/staff on macOS) or created
    # by root end up read-only to the gateway, which runs as the unprivileged
    # `hermes` user under s6 ("kanban.db is not writable", "Permission denied:
    # /opt/data/sessions/sessions.json", memories/ not updatable). Upstream's
    # stage2 hook only repairs a fixed list of subdirectories, not top-level
    # files, so repair anything not owned by hermes here (-h: never follow
    # symlinks).
    find /opt/data -xdev \( ! -user hermes -o ! -group hermes \) \
        -not -path '/opt/data/lost+found*' \
        -exec chown -h hermes:hermes {} + 2>/dev/null || true

    # Establish the default gateway profile's durable "running" intent, as the
    # hermes user so nothing it creates is root-owned. Returns immediately -
    # the gateway itself runs under s6.
    s6-setuidgid hermes hermes gateway run
else
    hermes gateway run
fi

# CMD is /init's main program: when it exits the whole supervision tree comes
# down. Nothing left to do in the foreground, so just stay alive.
exec sleep infinity
