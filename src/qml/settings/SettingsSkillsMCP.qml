/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami
import org.kde.chatqt
import org.koderoots.chatqt

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Skills and MCP Servers")

    property var settings: null
    property bool skillsExpanded: false

    ListModel {
        id: skillFoldersModel
    }

    ListModel {
        id: discoveredSkillsModel
    }

    ListModel {
        id: serversModel
    }

    Component.onCompleted: {
        loadSkillFolders()
        loadServers()
    }

    function loadSkillFolders() {
        skillFoldersModel.clear()
        var folders = settings ? settings.getSkillFolders() : []
        for (var i = 0; i < folders.length; i++) {
            skillFoldersModel.append({"folderPath": folders[i]})
        }
        scanSkills()
    }

    function scanSkills() {
        discoveredSkillsModel.clear()
        var folders = []
        for (var i = 0; i < skillFoldersModel.count; i++) {
            var path = skillFoldersModel.get(i).folderPath
            if (path && path !== "") {
                folders.push(path)
            }
        }

        var skills = SkillScanner.discoverSkills(folders)
        for (var j = 0; j < skills.length; j++) {
            var skill = skills[j]
            if (typeof skill === "string") {
                try { skill = JSON.parse(skill) } catch(e) { continue }
            }
            discoveredSkillsModel.append({
                "skillName": skill.name || "",
                "skillDescription": skill.description || "",
                "skillFolder": skill.folder || "",
                "skillDirName": skill.directoryName || ""
            })
        }
    }

    function addSkillFolder(path) {
        if (!path || path === "") return

        var cleanPath = path.replace("file://", "")
        for (var i = 0; i < skillFoldersModel.count; i++) {
            if (skillFoldersModel.get(i).folderPath === cleanPath) return
        }

        skillFoldersModel.append({"folderPath": cleanPath})
        saveSkillFolders()
        scanSkills()
    }

    function removeSkillFolder(index) {
        skillFoldersModel.remove(index)
        saveSkillFolders()
        scanSkills()
    }

    function saveSkillFolders() {
        var folders = []
        for (var i = 0; i < skillFoldersModel.count; i++) {
            folders.push(skillFoldersModel.get(i).folderPath)
        }
        settings.skillFolders = JSON.stringify(folders)
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
                if (servers[i].isBuiltIn === undefined) {
                    servers[i].isBuiltIn = false
                }
                var state = McpClient.getServerState(servers[i].id)
                servers[i].connectionStatus = state ? (state.status || "disconnected") : "disconnected"
                servers[i].toolCount = state ? (state.toolCount || 0) : 0
                serversModel.append(servers[i])
            }

            autoConnectBuiltInServers()
        } catch (e) {
            console.error("Failed to parse MCP servers:", e)
        }
    }

    function autoConnectBuiltInServers() {
        for (var i = 0; i < serversModel.count; i++) {
            var item = serversModel.get(i)
            if (item.isBuiltIn && item.enabled && item.connectionStatus === "disconnected") {
                connectToServer(i)
            }
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
                enabled: item.enabled !== undefined ? item.enabled : true,
                isBuiltIn: item.isBuiltIn === true
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
                enabled: true,
                isBuiltIn: false
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
        if (existing.isBuiltIn !== undefined) {
            server.isBuiltIn = existing.isBuiltIn
        }
        server.connectionStatus = existing.connectionStatus || "disconnected"
        server.toolCount = existing.toolCount || 0
        serversModel.set(index, server)
        saveServers()
    }

    function removeServer(index) {
        var item = serversModel.get(index)
        if (item && item.isBuiltIn) {
            applicationWindow().showPassiveNotification(
                i18n("Built-in servers cannot be removed. Disable them instead.")
            )
            return
        }
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
                            serversModel.setProperty(i, "connectionStatus", "connected")
                            serversModel.setProperty(i, "toolCount", response.result.tools.length)
                            applicationWindow().showPassiveNotification(
                                i18n("Connected to %1 — %2 tool(s) available").arg(serversModel.get(i).displayName).arg(response.result.tools.length)
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

    FolderDialog {
        id: folderDialog
        title: i18nc("@title:window", "Select Skills Folder")
        onAccepted: {
            var folder = folderDialog.selectedFolder.toString()
            folder = folder.replace(/^file:\/\//, "")
            root.addSkillFolder(folder)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18nc("@info", "Skills are markdown files (SKILL.md) organized in folders. They give AI models context about available capabilities. All skills in the configured folders will be loaded into the chat context.")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            level: 2
            text: i18nc("@title:group", "Skill Folders")
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: skillFoldersModel.count > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: skillFoldersModel
                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            text: model.folderPath
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            font: Kirigami.Theme.smallFont
                        }

                        QQC2.Label {
                            visible: {
                                var count = 0
                                for (var i = 0; i < discoveredSkillsModel.count; i++) {
                                    if (discoveredSkillsModel.get(i).skillFolder === model.folderPath) {
                                        count++
                                    }
                                }
                                return count > 0
                            }
                            text: {
                                var count = 0
                                for (var i = 0; i < discoveredSkillsModel.count; i++) {
                                    if (discoveredSkillsModel.get(i).skillFolder === model.folderPath) {
                                        count++
                                    }
                                }
                                return i18nc("@info", "%1 skill(s)").arg(count)
                            }
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.positiveTextColor
                        }

                        QQC2.ToolButton {
                            icon.name: "entry-delete-symbolic"
                            display: QQC2.AbstractButton.IconOnly
                            text: i18nc("@action:button", "Remove folder")
                            onClicked: root.removeSkillFolder(index)

                            QQC2.ToolTip {
                                text: parent.text
                                delay: Kirigami.Units.toolTipDelay
                            }
                        }
                    }
                }
            }
        }

        QQC2.Button {
            text: i18nc("@action:button", "Add Skill Folder")
            icon.name: "folder-add-symbolic"
            Layout.fillWidth: true
            onClicked: folderDialog.open()
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.ToolButton {
                icon.name: skillsExpanded ? "go-down-symbolic" : "go-next-symbolic"
                display: QQC2.AbstractButton.IconOnly
                text: skillsExpanded ? i18nc("@action:button", "Collapse") : i18nc("@action:button", "Expand")
                onClicked: skillsExpanded = !skillsExpanded
                Layout.alignment: Qt.AlignVCenter

                QQC2.ToolTip {
                    text: parent.text
                    delay: Kirigami.Units.toolTipDelay
                }
            }

            Kirigami.Heading {
                level: 2
                text: i18nc("@title:group", "Discovered Skills")
                Layout.fillWidth: true
            }

            Rectangle {
                visible: discoveredSkillsModel.count > 0
                radius: Kirigami.Units.smallSpacing
                height: Kirigami.Units.gridUnit * 1.2
                width: skillCountLabel.width + Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.positiveTextColor
                Layout.alignment: Qt.AlignVCenter

                QQC2.Label {
                    id: skillCountLabel
                    anchors.centerIn: parent
                    text: discoveredSkillsModel.count
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.backgroundColor
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: skillsExpanded
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                visible: discoveredSkillsModel.count === 0
                text: i18nc("@info", "No skills found. Add folders containing SKILL.md files.")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: discoveredSkillsModel.count > 0
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: discoveredSkillsModel
                    delegate: Kirigami.AbstractCard {
                        Layout.fillWidth: true

                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Heading {
                                    level: 3
                                    text: model.skillName
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                QQC2.Label {
                                    text: model.skillDirName
                                    font: Kirigami.Theme.smallFont
                                    color: Kirigami.Theme.disabledTextColor
                                }
                            }

                            QQC2.Label {
                                visible: model.skillDescription !== ""
                                text: model.skillDescription
                                font: Kirigami.Theme.smallFont
                                color: Kirigami.Theme.disabledTextColor
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            QQC2.Button {
                text: i18nc("@action:button", "Rescan Skills")
                icon.name: "view-refresh-symbolic"
                Layout.fillWidth: true
                onClicked: root.scanSkills()
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

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
            text: i18nc("@title:group", "MCP Servers")
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
                    serverType: model.type
                    serverToken: model.token || ""
                    serverEnabled: model.enabled !== undefined ? model.enabled : true
                    serverStatus: model.connectionStatus || "disconnected"
                    serverToolCount: model.toolCount || 0
                    serverCommand: model.command || ""
                    serverIsBuiltIn: model.isBuiltIn === true
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
                var server = serversModel.get(index)
                if (server.isBuiltIn) {
                    applicationWindow().showPassiveNotification(
                        i18n("Built-in servers cannot be edited.")
                    )
                    return
                }
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
