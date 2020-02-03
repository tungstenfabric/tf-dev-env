function log() {
  echo -e "$(date -u +"%Y-%m-%d %H:%M:%S,%3N"): INFO: $@"
}

function err() {
  echo -e "$(date -u +"%Y-%m-%d %H:%M:%S,%3N"): ERROR: $@" >&2
}
function append_log_file() {
  local logfile=$1
  local always_echo=${2:-'false'}
  local line=''
  while read line ; do
      echo "$line" >>  $logfile
  done
}
LOG_FILE="logrun_$(date +%m-%d-%Y-%H-%M-%S)"
[ ! -d  "./logs" ] && mkdir -p ./logs
[ ! -f  "./logs/$LOG_FILE" ] && mkdir -p ./logs && touch "./logs/$LOG_FILE"