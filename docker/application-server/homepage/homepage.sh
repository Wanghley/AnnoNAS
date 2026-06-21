#!/bin/bash
#==============================================================================
# AnnoGrid Homepage Stats Generator
# Queries Prometheus + Portainer + Jellyfin and writes stats.json
# Run via cron on anno-app:
#   */5 * * * * /home/pi/AnnoGrid/docker/application-server/homepage/homepage.sh
#==============================================================================

#==============================================================================
# Configuration — adjust to match your environment
#==============================================================================
# Path to the public dir mounted into the Homepage container
OUTPUT_DIR="$(dirname "$0")/public"
OUTPUT_FILE="$OUTPUT_DIR/stats.json"

# Prometheus (on anno-ai via Tailscale IP)
PROMETHEUS_URL="http://100.85.193.50:9090"

# Portainer (local)
PORTAINER_URL="https://localhost:9443"
PORTAINER_KEY="${HOMEPAGE_VAR_PORTAINER_KEY}"   # or paste key directly

# Jellyfin (local)
JELLYFIN_URL="http://localhost:8096"
JELLYFIN_KEY="${HOMEPAGE_VAR_JELLYFIN_KEY}"     # or paste key directly

# Prometheus instance labels (from prometheus.yml scrape targets)
INSTANCE_APP="100.67.194.10:9100"
INSTANCE_AI="100.85.193.50:9100"
INSTANCE_NAS="100.114.225.52:9100"
INSTANCE_GW="100.101.178.87:9100"

#==============================================================================
# Helpers
#==============================================================================
# Query Prometheus instant query; returns raw value or "0" on error
prom() {
    local query="$1"
    curl -sf -G "$PROMETHEUS_URL/api/v1/query" \
        --data-urlencode "query=$query" \
        | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0"
}

# Format bytes to GB string  e.g. "3.4 GB"
fmt_gb() {
    local bytes=$1
    printf "%.1f GB" "$(echo "scale=2; $bytes / 1073741824" | bc)"
}

# Format bytes to TB string  e.g. "1.8 TB"
fmt_tb() {
    local bytes=$1
    local tb
    tb=$(echo "scale=2; $bytes / 1099511627776" | bc)
    if (( $(echo "$tb >= 1" | bc -l) )); then
        printf "%.2f TB" "$tb"
    else
        printf "%.2f GB" "$(echo "scale=2; $bytes / 1073741824" | bc)"
    fi
}

# Format uptime seconds to "Xd Yh"
fmt_uptime() {
    local secs=${1%.*}
    local d=$(( secs / 86400 ))
    local h=$(( (secs % 86400) / 3600 ))
    echo "${d}d ${h}h"
}

# Format microseconds to "X,XXX h"
fmt_duration_us() {
    local us=${1:-0}
    local hours=$(( (${us%.*} + 18000000000) / 36000000000 ))
    printf "%'d h" "$hours"
}

#==============================================================================
# Per-node stats from Prometheus
#==============================================================================
node_stats() {
    local label="$1"   # e.g. anno_app
    local inst="$2"    # e.g. 100.67.194.10:9100

    local cpu ram_used ram_total disk_used disk_total uptime_secs boot_time

    cpu=$(prom "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\",instance=\"$inst\"}[5m])) * 100)")
    ram_used=$(prom "node_memory_MemTotal_bytes{instance=\"$inst\"} - node_memory_MemAvailable_bytes{instance=\"$inst\"}")
    ram_total=$(prom "node_memory_MemTotal_bytes{instance=\"$inst\"}")
    disk_used=$(prom "node_filesystem_size_bytes{instance=\"$inst\",mountpoint=\"/\",fstype!=\"tmpfs\"} - node_filesystem_avail_bytes{instance=\"$inst\",mountpoint=\"/\",fstype!=\"tmpfs\"}")
    disk_total=$(prom "node_filesystem_size_bytes{instance=\"$inst\",mountpoint=\"/\",fstype!=\"tmpfs\"}")
    boot_time=$(prom "node_boot_time_seconds{instance=\"$inst\"}")
    uptime_secs=$(echo "$(date +%s) - ${boot_time%.*}" | bc 2>/dev/null || echo "0")

    local cpu_fmt ram_fmt disk_fmt uptime_fmt
    cpu_fmt=$(printf "%.1f%%" "$cpu" 2>/dev/null || echo "– %")
    ram_fmt="$(fmt_gb "$ram_used") / $(fmt_gb "$ram_total")"
    disk_fmt="$(fmt_gb "$disk_used") / $(fmt_gb "$disk_total")"
    uptime_fmt=$(fmt_uptime "$uptime_secs")

    echo "\"$label\": {
    \"cpu\": \"$cpu_fmt\",
    \"ram\": \"$ram_fmt\",
    \"disk\": \"$disk_fmt\",
    \"uptime\": \"$uptime_fmt\","
}

#==============================================================================
# Container counts from Portainer
#==============================================================================
portainer_counts() {
    local env_id="$1"   # Portainer environment ID (1 = local)
    local result
    result=$(curl -sf -k -H "X-API-Key: $PORTAINER_KEY" \
        "$PORTAINER_URL/api/endpoints/$env_id/docker/containers/json?all=true" 2>/dev/null)

    local running stopped
    running=$(echo "$result" | jq '[.[] | select(.State=="running")] | length' 2>/dev/null || echo 0)
    stopped=$(echo "$result" | jq '[.[] | select(.State!="running")] | length' 2>/dev/null || echo 0)
    echo "$running $stopped"
}

#==============================================================================
# Jellyfin stats
#==============================================================================
jellyfin_item_counts() {
    curl -sf "$JELLYFIN_URL/Items/Counts?api_key=$JELLYFIN_KEY" 2>/dev/null || echo "{}"
}

jellyfin_library_size() {
    local media_type="$1"   # Movie or Episode
    curl -sf "$JELLYFIN_URL/Items?IncludeItemTypes=$media_type&Recursive=true&Fields=Size&api_key=$JELLYFIN_KEY" \
        2>/dev/null | jq '[.Items[].Size // 0] | add // 0' 2>/dev/null || echo 0
}

jellyfin_play_counts() {
    local media_type="$1"
    curl -sf "$JELLYFIN_URL/Items?IncludeItemTypes=$media_type&Recursive=true&Fields=UserData&api_key=$JELLYFIN_KEY" \
        2>/dev/null | jq '[.Items[].UserData.PlayCount // 0] | add // 0' 2>/dev/null || echo 0
}

#==============================================================================
# Main
#==============================================================================
mkdir -p "$OUTPUT_DIR"

echo "[ AnnoGrid stats ] $(date)"

# ── Node stats ──────────────────────────────────────────────────────────────
APP_STATS=$(node_stats "anno_app" "$INSTANCE_APP")
AI_STATS=$(node_stats "anno_ai" "$INSTANCE_AI")
NAS_STATS=$(node_stats "anno_nas" "$INSTANCE_NAS")
GW_STATS=$(node_stats "anno_gw" "$INSTANCE_GW")

# ── NAS storage (use largest mounted filesystem) ─────────────────────────────
NAS_DISK_TOTAL=$(prom "node_filesystem_size_bytes{instance=\"$INSTANCE_NAS\",mountpoint=\"/\",fstype!=\"tmpfs\"}")
NAS_DISK_AVAIL=$(prom "node_filesystem_avail_bytes{instance=\"$INSTANCE_NAS\",mountpoint=\"/\",fstype!=\"tmpfs\"}")
NAS_DISK_USED=$(echo "$NAS_DISK_TOTAL - $NAS_DISK_AVAIL" | bc 2>/dev/null || echo "0")
NAS_PCT=$(echo "scale=1; $NAS_DISK_USED * 100 / ($NAS_DISK_TOTAL + 1)" | bc 2>/dev/null || echo "0")

# ── Container counts (Portainer env 1 = local anno-app) ─────────────────────
APP_CNTR=$(portainer_counts 1)
APP_UP=$(echo "$APP_CNTR" | cut -d' ' -f1)
APP_DOWN=$(echo "$APP_CNTR" | cut -d' ' -f2)

# Remote nodes: query each node's Portainer agent or use cAdvisor counts
AI_UP=$(prom "count(container_last_seen{instance=\"100.85.193.50:8081\",name!~\"/(pause|.+POD.+)/\"})"); AI_DOWN=0
NAS_UP=$(prom "count(container_last_seen{instance=\"100.114.225.52:8080\",name!~\"/(pause|.+POD.+)/\"})"); NAS_DOWN=0
GW_UP=$(prom "count(container_last_seen{instance=\"100.101.178.87:8080\",name!~\"/(pause|.+POD.+)/\"})"); GW_DOWN=0

CLUSTER_RUNNING=$(( ${APP_UP:-0} + ${AI_UP:-0} + ${NAS_UP:-0} + ${GW_UP:-0} ))
CLUSTER_STOPPED=$(( ${APP_DOWN:-0} + ${AI_DOWN:-0} + ${NAS_DOWN:-0} + ${GW_DOWN:-0} ))
CLUSTER_TOTAL=$(( CLUSTER_RUNNING + CLUSTER_STOPPED ))

# ── Jellyfin ─────────────────────────────────────────────────────────────────
JF_COUNTS=$(jellyfin_item_counts)
MOVIE_COUNT=$(echo "$JF_COUNTS" | jq '.MovieCount // 0' 2>/dev/null || echo 0)
EPISODE_COUNT=$(echo "$JF_COUNTS" | jq '.EpisodeCount // 0' 2>/dev/null || echo 0)

MOVIE_SIZE=$(jellyfin_library_size "Movie")
SERIES_SIZE=$(jellyfin_library_size "Episode")
MOVIE_PLAYS=$(jellyfin_play_counts "Movie")
SERIES_PLAYS=$(jellyfin_play_counts "Episode")

MOVIE_RUNTIME=$(prom "sum(jellyfin_item_duration_seconds{MediaType=\"Movie\"}) or vector(0)")
SERIES_RUNTIME=$(prom "sum(jellyfin_item_duration_seconds{MediaType=\"Episode\"}) or vector(0)")

MOVIE_RUNTIME_FMT=$(fmt_duration_us "$(echo "$MOVIE_RUNTIME * 1000000" | bc 2>/dev/null || echo 0)")
SERIES_RUNTIME_FMT=$(fmt_duration_us "$(echo "$SERIES_RUNTIME * 1000000" | bc 2>/dev/null || echo 0)")

#==============================================================================
# Write JSON
#==============================================================================
cat > "$OUTPUT_FILE" << EOF
{
  $APP_STATS
    "containers_up": "$APP_UP",
    "containers_down": "$APP_DOWN"
  },
  $AI_STATS
    "containers_up": "$AI_UP",
    "containers_down": "$AI_DOWN"
  },
  "anno_nas": {
    "storage_used": "$(fmt_tb "$NAS_DISK_USED")",
    "storage_free": "$(fmt_tb "$NAS_DISK_AVAIL")",
    "disk_pct": "${NAS_PCT}%",
    "uptime": "$(fmt_uptime "$(echo "$(date +%s) - $(prom "node_boot_time_seconds{instance=\"$INSTANCE_NAS\"}" | cut -d. -f1)" | bc 2>/dev/null || echo 0)")",
    "containers_up": "$NAS_UP",
    "containers_down": "$NAS_DOWN"
  },
  $GW_STATS
    "containers_up": "$GW_UP",
    "containers_down": "$GW_DOWN"
  },
  "jellyfin": {
    "movies": {
      "count": $MOVIE_COUNT,
      "storage": "$(fmt_tb "$MOVIE_SIZE")",
      "plays": $MOVIE_PLAYS,
      "runtime": "$MOVIE_RUNTIME_FMT"
    },
    "series": {
      "episodes": $EPISODE_COUNT,
      "storage": "$(fmt_tb "$SERIES_SIZE")",
      "plays": $SERIES_PLAYS,
      "runtime": "$SERIES_RUNTIME_FMT"
    }
  },
  "cluster": {
    "running": $CLUSTER_RUNNING,
    "stopped": $CLUSTER_STOPPED,
    "total": $CLUSTER_TOTAL,
    "hosts": 4
  },
  "timestamp": $(date +%s000)
}
EOF

echo "[ AnnoGrid stats ] Written to $OUTPUT_FILE"
