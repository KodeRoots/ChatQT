/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

function mapStatus(status, statusText) {
    if (status === 0) return "NETWORK_ERROR";
    if (status === 401) return "UNAUTHORIZED";
    if (status === 404) return "NOT_FOUND";
    if (status === 405) return "METHOD_NOT_ALLOWED";
    return statusText || "UNKNOWN";
}
