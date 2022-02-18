#!/bin/sh

if [ $UDP_RECV_BUFFER_SIZE -gt 0 ]; then
  sysctl -w net.core.rmem_max=$UDP_RECV_BUFFER_SIZE
  sysctl -w net.core.rmem_default=$UDP_RECV_BUFFER_SIZE
fi
