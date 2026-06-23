#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE=(docker compose -f "${SCRIPT_DIR}/compose.yaml")
BITCOIN_CLI=("${COMPOSE[@]}" exec -T -u blits bitcoind /opt/bitcoin/bin/bitcoin-cli -regtest)
INITIAL_BLOCKS="${INITIAL_BLOCKS:-103}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-120}"

die() {
  echo "error: $*" >&2
  exit 1
}

wait_for_bitcoind() {
  local start
  start="$(date +%s)"
  until "${BITCOIN_CLI[@]}" getblockchaininfo >/dev/null 2>&1; do
    if (( "$(date +%s)" - start > TIMEOUT_SECONDS )); then
      "${COMPOSE[@]}" logs bitcoind >&2
      die "timed out waiting for bitcoind RPC"
    fi
    sleep 1
  done
}

wait_for_host_bitcoind_rpc() {
  local start
  local rpc_port="${BITCOIND_RPC_PORT:-18444}"
  start="$(date +%s)"
  until curl --fail --silent \
    --user user:password \
    --data-binary '{"jsonrpc":"1.0","id":"regtest","method":"getblockchaininfo","params":[]}' \
    -H 'content-type: text/plain;' \
    "http://127.0.0.1:${rpc_port}/" >/dev/null 2>&1; do
    if (( "$(date +%s)" - start > TIMEOUT_SECONDS )); then
      "${COMPOSE[@]}" logs bitcoind >&2
      die "timed out waiting for host bitcoind RPC on 127.0.0.1:${rpc_port}"
    fi
    sleep 1
  done
}

wait_for_electrs() {
  local start
  local electrs_port="${ELECTRS_PORT:-50002}"
  start="$(date +%s)"
  until nc -z 127.0.0.1 "${electrs_port}" >/dev/null 2>&1; do
    if (( "$(date +%s)" - start > TIMEOUT_SECONDS )); then
      "${COMPOSE[@]}" logs electrs >&2 || true
      die "timed out waiting for electrs"
    fi
    sleep 1
  done
}

ensure_miner_wallet() {
  if ! "${BITCOIN_CLI[@]}" listwallets | grep -q '"miner"'; then
    if "${BITCOIN_CLI[@]}" listwalletdir | grep -q '"name": "miner"'; then
      "${BITCOIN_CLI[@]}" loadwallet miner >/dev/null
    else
      "${BITCOIN_CLI[@]}" createwallet miner >/dev/null
    fi
  fi
}

ensure_initial_blocks() {
  local height
  height="$("${BITCOIN_CLI[@]}" getblockcount)"
  if (( height < INITIAL_BLOCKS )); then
    "${BITCOIN_CLI[@]}" -rpcwallet=miner -generate "$((INITIAL_BLOCKS - height))" >/dev/null
  fi
}

start() {
  mkdir -p "${SCRIPT_DIR}/data/bitcoind" "${SCRIPT_DIR}/data/electrs"
  "${COMPOSE[@]}" up -d bitcoind
  wait_for_bitcoind
  ensure_miner_wallet
  ensure_initial_blocks
  wait_for_host_bitcoind_rpc
  "${COMPOSE[@]}" up -d proxy electrs
  wait_for_electrs
  info
}

stop() {
  "${COMPOSE[@]}" stop
}

reset() {
  "${COMPOSE[@]}" down -v --remove-orphans
  rm -rf "${SCRIPT_DIR}/data"
}

mine() {
  local blocks="${1:-}"
  [[ -n "${blocks}" ]] || die "usage: $0 mine <blocks>"
  wait_for_bitcoind
  ensure_miner_wallet
  "${BITCOIN_CLI[@]}" -rpcwallet=miner -generate "${blocks}" >/dev/null
}

send_to_address() {
  local address="${1:-}"
  local amount="${2:-}"
  [[ -n "${address}" && -n "${amount}" ]] || die "usage: $0 sendtoaddress <address> <amount>"
  wait_for_bitcoind
  ensure_miner_wallet
  "${BITCOIN_CLI[@]}" -rpcwallet=miner sendtoaddress "${address}" "${amount}"
}

info() {
  local proxy_port="${RGB_PROXY_PORT:-3003}"
  local electrs_port="${ELECTRS_PORT:-50002}"
  local rpc_port="${BITCOIND_RPC_PORT:-18444}"
  echo "rgb-sdk-flutter regtest:"
  echo "  bitcoind RPC: 127.0.0.1:${rpc_port} user/password"
  echo "  electrs:      127.0.0.1:${electrs_port}"
  echo "  RGB proxy:    rpc://127.0.0.1:${proxy_port}/json-rpc"
  echo "  network:      regtest"
  "${COMPOSE[@]}" ps
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  reset) reset ;;
  mine) mine "${2:-}" ;;
  sendtoaddress) send_to_address "${2:-}" "${3:-}" ;;
  info) info ;;
  ps) "${COMPOSE[@]}" ps ;;
  logs) "${COMPOSE[@]}" logs -f "${2:-}" ;;
  *)
    cat <<EOF
Usage: $0 <command>

Commands:
  start                         Start bitcoind, electrs, proxy and mine initial blocks.
  stop                          Stop containers without deleting data.
  reset                         Stop containers and delete this stack's regtest data.
  mine <blocks>                 Mine blocks with the miner wallet.
  sendtoaddress <address> <btc> Send BTC from the miner wallet.
  info                          Print endpoints and container state.
  ps                            Print container state.
  logs [service]                Follow compose logs.
EOF
    ;;
esac
