#!/usr/bin/env bash

# Reserved host ports for the SDK-owned regtest stack. Keep these isolated from
# application development stacks so release tests never attach to foreign
# services or recreate containers with missing port mappings.
: "${BITCOIND_RPC_PORT:=18444}"
: "${ELECTRS_PORT:=50002}"
: "${RGB_PROXY_PORT:=3013}"

export BITCOIND_RPC_PORT
export ELECTRS_PORT
export RGB_PROXY_PORT
