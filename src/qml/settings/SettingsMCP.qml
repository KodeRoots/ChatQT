/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.chatqt
import org.koderoots.chatqt

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "MCP Servers")

    property var settings: null

    ListModel {
        id: serversModel
    }

    Component.onCompleted: {
        if (root.settings) {
            loadServers()
        }
    }

    function generateUuid() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            var r = Math.random() * 16 | 0
            var v = c === 'x' ? r : (r & 0x3 | 0x8)
            return v.toString(16)
        })
    }

    function loadServers() {
        serversModel.clear()
        try {
            var servers = JSON.parse(root.settings.mcpServers || "[]")
            for (var i = 0; i < servers.length; i++) {
                if (servers[i].enabled === undefined) {
                    servers[i].enabled = true
                }
                if (!servers[i].id) {
                    servers[i].id = generateUuid()
                }
                servers[i].type = "remote"
                var state = McpClient.getServerState(servers[i].id)
                servers[i].connectionStatus = state ? (state.status || "disconnected") : "disconnected"
                servers[i].toolCount = state ? (state.toolCount || 0) : 0
                serversModel.append(servers[i])
            }
        } catch (e) {
            console.error("Failed to parse MCP servers:", e)
        }
    }

    function saveServers() {
        var servers = []
        for (var i = 0; i < serversModel.count; i++) {
            var item = serversModel.get(i)
            var server = {
                id: item.id,
                displayName: item.displayName,
                type: "remote",
                enabled: item.enabled !== undefined ? item.enabled : true,
                url: item.url || "",
                token: item.token || "",
                headers: item.headers || ""
            }
            servers.push(server)
        }
        root.settings.mcpServers = JSON.stringify(servers)
    }

    function addServer(server) {
        if (server === undefined) {
            server = {
                id: generateUuid(),
                displayName: i18nc("@info", "New MCP Server"),
                type: "remote",
                url: "",
                token: "",
                headers: "",
                enabled: true
            }
        }
        if (server.enabled === undefined) {
            server.enabled = true
        }
        if (!server.id) {
            server.id = generateUuid()
        }
        server.type = "remote"
        server.connectionStatus = "disconnected"
        server.toolCount = 0
        serversModel.append(server)
        saveServers()
    }

    function updateServer(index, server) {
        var existing = serversModel.get(index)
        if (existing.enabled !== undefined) {
            server.enabled = existing.enabled
        }
        server.connectionStatus = existing.connectionStatus || "disconnected"
        server.toolCount = existing.toolCount || 0
        serversModel.set(index, server)
        saveServers()
    }

    function removeServer(index) {
        var item = serversModel.get(index)
        if (item && item.id) {
            McpClient.disconnectServer(item.id)
        }
        serversModel.remove(index)
        saveServers()
    }

    function toggleServerEnabled(index) {
        var item = serversModel.get(index)
        serversModel.setProperty(index, "enabled", !item.enabled)
        saveServers()
    }

    function connectToServer(index) {
        var item = serversModel.get(index)
        if (!item || !item.url) return

        serversModel.setProperty(index, "connectionStatus", "connecting")

        var headers = {}
        if (item.token) {
            headers["Authorization"] = "Bearer " + item.token
        }
        if (item.headers) {
            try {
                var customHeaders = JSON.parse(item.headers)
                var keys = Object.keys(customHeaders)
                for (var i = 0; i < keys.length; i++) {
                    headers[keys[i]] = customHeaders[keys[i]]
                }
            } catch (e) {}
        }

        McpClient.initializeServer(
            item.url,
            headers,
            function(result) {
                McpClient.updateServerState(item.id, {
                    status: "connected",
                    sessionId: result.sessionId,
                    serverInfo: result.serverInfo,
                    capabilities: result.capabilities,
                    headers: headers,
                    url: item.url.replace(/\/$/, ''),
                    type: "remote"
                })

                McpClient.listTools(
                    item.url,
                    result.sessionId,
                    headers,
                    function(tools) {
                        McpClient.updateServerState(item.id, {
                            tools: tools,
                            toolCount: tools.length
                        })
                        serversModel.setProperty(index, "connectionStatus", "connected")
                        serversModel.setProperty(index, "toolCount", tools.length)
                        applicationWindow().showPassiveNotification(
                            i18n("Connected to %1 — %2 tool(s) available").arg(item.displayName).arg(tools.length)
                        )
                    },
                    function(code, message) {
                        McpClient.updateServerState(item.id, {
                            status: "connected",
                            tools: [],
                            toolCount: 0
                        })
                        serversModel.setProperty(index, "connectionStatus", "connected")
                        serversModel.setProperty(index, "toolCount", 0)
                        applicationWindow().showPassiveNotification(
                            i18n("Connected to %1 but failed to list tools: %2").arg(item.displayName).arg(message)
                        )
                    }
                )
            },
            function(code, message) {
                McpClient.updateServerState(item.id, {
                    status: "error"
                })
                serversModel.setProperty(index, "connectionStatus", "error")
                applicationWindow().showPassiveNotification(
                    i18n("Failed to connect to %1: %2").arg(item.displayName).arg(message)
                )
            }
        )
    }

    function disconnectFromServer(index) {
        var item = serversModel.get(index)
        if (!item || !item.id) return

        var state = McpClient.getServerState(item.id)
        if (state && state.url) {
            var xhr = new XMLHttpRequest()
            xhr.open("DELETE", state.url.replace(/\/$/, ''), true)
            if (state.sessionId) {
                xhr.setRequestHeader("Mcp-Session-Id", state.sessionId)
            }
            xhr.send()
        }
        McpClient.disconnectServer(item.id)

        serversModel.setProperty(index, "connectionStatus", "disconnected")
        serversModel.setProperty(index, "toolCount", 0)
        applicationWindow().showPassiveNotification(i18n("Disconnected from %1").arg(item.displayName))
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18nc("@info", "Configure remote MCP (Model Context Protocol) servers to give AI models access to external tools via Streamable HTTP.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            visible: serversModel.count > 0
            level: 2
            text: i18nc("@title:group", "Servers")
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: serversModel.count > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: serversModel
                delegate: McpCard {
                    Layout.fillWidth: true
                    serverDisplayName: model.displayName
                    serverUrl: model.url || ""
                    serverType: "remote"
                    serverToken: model.token || ""
                    serverEnabled: model.enabled !== undefined ? model.enabled : true
                    serverStatus: model.connectionStatus || "disconnected"
                    serverToolCount: model.toolCount || 0
                    onEditClicked: editSheet.openServer(index)
                    onRemoveClicked: root.removeServer(index)
                    onEnabledToggled: root.toggleServerEnabled(index)
                    onConnectClicked: root.connectToServer(index)
                    onDisconnectClicked: root.disconnectFromServer(index)
                }
            }
        }

        QQC2.Button {
            text: i18nc("@action:button", "Add MCP Server")
            icon.name: "list-add-symbolic"
            Layout.fillWidth: true
            onClicked: editSheet.openNewServer()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Kirigami.Dialog {
            id: editSheet
            parent: root
            title: i18nc("@title:window", "Edit MCP Server")
            padding: Kirigami.Units.largeSpacing
            width: Kirigami.Units.gridUnit * 32

            property int editingIndex: -1

            function openNewServer() {
                editingIndex = -1
                displayNameField.text = i18nc("@info", "New MCP Server")
                urlField.text = ""
                tokenField.text = ""
                headersField.text = ""
                editSheet.title = i18nc("@title:window", "Add MCP Server")
                editSheet.open()
            }

            function openServer(index) {
                var server = serversModel.get(index)
                editingIndex = index
                displayNameField.text = server.displayName
                urlField.text = server.url || ""
                tokenField.text = server.token || ""
                headersField.text = server.headers || ""
                editSheet.title = i18nc("@title:window", "Edit MCP Server")
                editSheet.open()
            }

            standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

            onAccepted: {
                var server = {
                    displayName: displayNameField.text,
                    type: "remote",
                    url: urlField.text,
                    token: tokenField.text,
                    headers: headersField.text
                }
                if (editingIndex >= 0) {
                    root.updateServer(editingIndex, server)
                } else {
                    root.addServer(server)
                }
            }

            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: i18nc("@label:textbox", "Display Name:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.TextField {
                    id: displayNameField
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "e.g., Exa Search")
                }

                QQC2.Label {
                    text: i18nc("@label:textbox", "MCP Server URL:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.TextField {
                    id: urlField
                    Layout.fillWidth: true
                    placeholderText: "https://mcp.exa.ai/mcp"
                }

                QQC2.Label {
                    text: i18nc("@label:textbox", "API Token (optional):")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.TextField {
                    id: tokenField
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "Enter API token if required")
                    echoMode: QQC2.TextField.Password
                }

                QQC2.Label {
                    text: i18nc("@label:textbox", "Custom Headers (JSON, optional):")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.TextField {
                    id: headersField
                    Layout.fillWidth: true
                    placeholderText: '{"x-api-key": "your-key"}'
                }
            }
        }
    }
}
