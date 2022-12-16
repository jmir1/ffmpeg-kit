#!/bin/bash

make clean

make -j$(get_cpu_count) no_test || return 1
make DESTDIR="${INSTALL_PKG_CONFIG_DIR}" install || return 1
