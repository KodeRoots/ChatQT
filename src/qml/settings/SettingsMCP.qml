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
                if (servers[i].type === undefined) {
                    servers[i].type = "remote"
                }
                if (servers[i].command === undefined) {
                    servers[i].command = ""
                }
                if (servers[i].args === undefined) {
                    servers[i].args = ""
                }
                if (servers[i].env === undefined) {
                    servers[i].env = ""
                }
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
                type: item.type,
                enabled: item.enabled !== undefined ? item.enabled : true
            }
            if (item.type === "remote") {
                server.url = item.url || ""
                server.token = item.token || ""
                server.headers = item.headers || ""
            } else if (item.type === "stdio") {
                server.command = item.command || ""
                server.args = item.args || ""
                server.env = item.env || ""
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
                command: "",
                args: "",
                env: "",
                enabled: true
            }
        }
        if (server.enabled === undefined) {
            server.enabled = true
        }
        if (!server.id) {
            server.id = generateUuid()
        }
        if (server.type === undefined) {
            server.type = "remote"
        }
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
            if (item.type === "stdio") {
                McpProcessManager.stopProcess(item.id)
            }
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
        if (!item) return

        if (item.type === "stdio") {
            connectToStdioServer(index)
        } else {
            connectToRemoteServer(index)
        }
    }

    function connectToRemoteServer(index) {
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

    function connectToStdioServer(index) {
        var item = serversModel.get(index)
        if (!item || !item.command) return

        serversModel.setProperty(index, "connectionStatus", "connecting")

        var envMap = {}
        if (item.env) {
            try {
                envMap = JSON.parse(item.env)
            } catch (e) {
                envMap = {}
            }
        }

        var argsList = []
        if (item.args) {
            argsList = item.args.split(/\s+/).filter(function(a) { return a.length > 0 })
        }

        McpProcessManager.startProcess(item.id, item.command, argsList, envMap)
    }

    function disconnectFromServer(index) {
        var item = serversModel.get(index)
        if (!item || !item.id) return

        if (item.type === "stdio") {
            McpProcessManager.stopProcess(item.id)
        } else {
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
        }

        serversModel.setProperty(index, "connectionStatus", "disconnected")
        serversModel.setProperty(index, "toolCount", 0)
        applicationWindow().showPassiveNotification(i18n("Disconnected from %1").arg(item.displayName))
    }

    Connections {
        target: McpProcessManager

        function onProcessStatusChanged(serverId, status) {
            for (var i = 0; i < serversModel.count; i++) {
                if (serversModel.get(i).id === serverId) {
                    serversModel.setProperty(i, "connectionStatus", status)
                    break
                }
            }
        }

        function onProcessError(serverId, errorMessage) {
            for (var i = 0; i < serversModel.count; i++) {
                if (serversModel.get(i).id === serverId) {
                    serversModel.setProperty(i, "connectionStatus", "error")
                    applicationWindow().showPassiveNotification(
                        i18n("MCP process error (%1): %2").arg(serverId).arg(errorMessage)
                    )
                    break
                }
            }
        }

        function onMessageReceived(serverId, jsonMessage) {
            try {
                var response = JSON.parse(jsonMessage)

                if (response.result && response.result.tools) {
                    McpClient.updateServerState(serverId, {
                        status: "connected",
                        tools: response.result.tools,
                        toolCount: response.result.tools.length,
                        type: "stdio",
                        serverId: serverId
                    })

                    for (var i = 0; i < serversModel.count; i++) {
                        if (serversModel.get(i).id === serverId) {
                            var name = response.result.tools.length > 0 ? serversModel.get(i).displayName : serversModel.get(i).displayName
                            serversModel.setProperty(i, "connectionStatus", "connected")
                            serversModel.setProperty(i, "toolCount", response.result.tools.length)
                            applicationWindow().showPassiveNotification(
                                i18n("Connected to %1 — %2 tool(s) available").arg(name).arg(response.result.tools.length)
                            )
                            break
                        }
                    }
                }

                if (response.method === "notifications/tools/list_changed") {
                    var requestId = McpClient.getNextRequestId()
                    var toolsRequest = McpClient.createJsonRpcRequest("tools/list", {})
                    McpProcessManager.sendMessage(serverId, JSON.stringify(toolsRequest), requestId)
                }
            } catch (e) {
                console.warn("Failed to parse MCP stdio message:", e)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18nc("@info", "Configure MCP (Model Context Protocol) servers to give AI models access to external tools. Supports both remote (Streamable HTTP) and local (stdio) servers.")
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
                    serverDisplayName: serversModel.get(index).displayName
                    serverUrl: serversModel.get(index).url || ""
                    serverType: serversModel.get(index).type
                    serverToken: serversModel.get(index).token || ""
                    serverEnabled: serversModel.get(index).enabled !== undefined ? serversModel.get(index).enabled : true
                    serverStatus: serversModel.get(index).connectionStatus || "disconnected"
                    serverToolCount: serversModel.get(index).toolCount || 0
                    serverCommand: serversModel.get(index).command || ""
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
                typeCombo.currentIndex = 0
                urlField.text = ""
                tokenField.text = ""
                headersField.text = ""
                commandField.text = ""
                argsField.text = ""
                envField.text = ""
                updateTypeVisibility()
                editSheet.title = i18nc("@title:window", "Add MCP Server")
                editSheet.open()
            }

            function openServer(index) {
                editingIndex = index
                var server = serversModel.get(index)
                displayNameField.text = server.displayName
                typeCombo.currentIndex = server.type === "stdio" ? 1 : 0
                urlField.text = server.url || ""
                tokenField.text = server.token || ""
                headersField.text = server.headers || ""
                commandField.text = server.command || ""
                argsField.text = server.args || ""
                envField.text = server.env || ""
                updateTypeVisibility()
                editSheet.title = i18nc("@title:window", "Edit MCP Server")
                editSheet.open()
            }

            function updateTypeVisibility() {
                var isRemote = typeCombo.currentIndex === 0
                remoteSection.visible = isRemote
                stdioSection.visible = !isRemote
            }

            standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

            onAccepted: {
                var server = {
                    displayName: displayNameField.text,
                    type: typeCombo.currentIndex === 0 ? "remote" : "stdio",
                    url: urlField.text,
                    token: tokenField.text,
                    headers: headersField.text,
                    command: commandField.text,
                    args: argsField.text,
                    env: envField.text
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
                    placeholderText: i18nc("@info:placeholder", "e.g., Exa Search, Filesystem")
                }

                QQC2.Label {
                    text: i18nc("@label:textbox", "Type:")
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                QQC2.ComboBox {
                    id: typeCombo
                    Layout.fillWidth: true
                    model: [
                        { text: i18nc("@info", "Remote (Streamable HTTP)"), value: "remote" },
                        { text: i18nc("@info", "Local (stdio)"), value: "stdio" }
                    ]
                    textRole: "text"
                    valueRole: "value"
                    onCurrentIndexChanged: editSheet.updateTypeVisibility()
                }

                ColumnLayout {
                    id: remoteSection
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

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

                ColumnLayout {
                    id: stdioSection
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: false

                    QQC2.Label {
                        text: i18nc("@info", "Local MCP servers run as subprocesses, communicating via stdin/stdout using JSON-RPC.")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    QQC2.Label {
                        text: i18nc("@label:textbox", "Command:")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }

                    QQC2.TextField {
                        id: commandField
                        Layout.fillWidth: true
                        placeholderText: i18nc("@info:placeholder", "e.g., npx, /path/to/server-binary")
                    }

                    QQC2.Label {
                        text: i18nc("@label:textbox", "Arguments:")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }

                    QQC2.TextField {
                        id: argsField
                        Layout.fillWidth: true
                        placeholderText: i18nc("@info:placeholder", "e.g., -y @modelcontextprotocol/server-filesystem /home/user")
                    }

                    QQC2.Label {
                        text: i18nc("@label:textbox", "Environment Variables (JSON, optional):")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }

                    QQC2.TextField {
                        id: envField
                        Layout.fillWidth: true
                        placeholderText: '{"API_KEY": "your-key", "DEBUG": "true"}'
                    }
                }
            }
        }
    }
}