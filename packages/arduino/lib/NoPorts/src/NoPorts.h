/**
 * @file NoPorts.h
 * @brief Arduino/ESP32 NoPorts daemon library (sshnpd equivalent)
 *
 * This library implements a NoPorts daemon for ESP32 devices, based on the
 * C implementation of sshnpd from https://github.com/atsign-foundation/noports
 *
 * It provides:
 *  - Device registration on the atProtocol network
 *  - Monitoring for incoming tunnel/ping requests
 *  - NPT (No Ports Tunnel) request handling with encrypted TCP relaying
 *  - Ping/heartbeat response for device discovery
 *
 * The atSDK (atclient, atchops, atlogger, atcommons, cJSON) is bundled
 * directly in this library — no external atsdk dependency is needed.
 *
 * @note SSH request handling is NOT supported on Arduino/ESP32 as there is
 * no SSH server. Only NPT (network port tunneling) is supported.
 *
 * Copyright (c) 2024-2026 Atsign Foundation
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef NOPORTS_H
#define NOPORTS_H

#include "noports/noports_config.h"
#include "noports/noports_daemon.h"
#include "noports/noports_relay.h"
#include "noports/noports_log.h"
#include "noports/noports_keys.h"

#endif // NOPORTS_H
