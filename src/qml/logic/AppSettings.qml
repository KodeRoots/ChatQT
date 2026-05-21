/*
    SPDX-FileCopyrightText: 2024 Denys Madureira <denysmb@zoho.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

import QtQuick
import QtCore
import org.kde.chatqt
import org.koderoots.chatqt

QtObject {
    id: settings

    property string provider: _settings.value("provider", "ollama")
    property string openclawUrl: _settings.value("openclawUrl", "http://127.0.0.1:18789")
    property string openclawToken: _settings.value("openclawToken", "")
    property string openaiCompatibleUrl: _settings.value("openaiCompatibleUrl", "")
    property string openaiCompatibleToken: _settings.value("openaiCompatibleToken", "")
    property string openaiCompatibleModel: _settings.value("openaiCompatibleModel", "")
    property string openaiCompatibleProviders: _settings.value("openaiCompatibleProviders", "[]")
    property string selectedOpenAICompatibleProviderId: _settings.value("selectedOpenAICompatibleProviderId", "")
    property string openclawInstances: _settings.value("openclawInstances", "[]")
    property string selectedOpenClawInstanceId: _settings.value("selectedOpenClawInstanceId", "")
    property string opencodeUrl: _settings.value("opencodeUrl", "http://127.0.0.1:4096")
    property string opencodeUsername: _settings.value("opencodeUsername", "")
    property string opencodePassword: _settings.value("opencodePassword", "")
    property string opencodeModel: _settings.value("opencodeModel", "")
    property string lastActiveSessionId: _settings.value("lastActiveSessionId", "")

    property string mcpServers: _settings.value("mcpServers", "[]")
    property string mcpToolResults: "{}"
    property bool mcpDefaultsInitialized: _settings.value("mcpDefaultsInitialized", false)

    property string skillFolders: _settings.value("skillFolders", JSON.stringify(["~/.skills", "~/.agents/skills"]))
    property string agentFilePath: _settings.value("agentFilePath", "")

    property bool ollamaEnabled: _settings.value("ollamaEnabled", true)
    property bool experimentalFeatures: typeof experimentalFeaturesEnabled !== 'undefined' ? experimentalFeaturesEnabled : false

    property bool openclawEnabledRaw: _settings.value("openclawEnabled", false)
    property bool opencodeEnabledRaw: _settings.value("opencodeEnabled", false)
    property bool piEnabledRaw: _settings.value("piEnabled", false)

    property bool openclawEnabled: experimentalFeatures && openclawEnabledRaw
    property bool openaiCompatibleEnabled: _settings.value("openaiCompatibleEnabled", true)
    property bool opencodeEnabled: experimentalFeatures && opencodeEnabledRaw
    property bool piEnabled: experimentalFeatures && piEnabledRaw

    readonly property bool isOllama: provider === ProviderConstants.PROVIDERS.OLLAMA
    readonly property bool isOpenClaw: provider === ProviderConstants.PROVIDERS.OPENCLAW
    readonly property bool isOpenAICompatible: provider === ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE
    readonly property bool isOpenCode: provider === ProviderConstants.PROVIDERS.OPENCODE
    readonly property bool isPi: provider === ProviderConstants.PROVIDERS.PI

    function getProviderDisplayName() {
        if (provider === ProviderConstants.PROVIDERS.OLLAMA) return "Ollama"
        if (provider === ProviderConstants.PROVIDERS.OPENCLAW) {
            const selectedInstance = getSelectedOpenClawInstance()
            if (selectedInstance) {
                return selectedInstance.displayName
            }
            return "OpenClaw"
        }
        if (provider === ProviderConstants.PROVIDERS.OPENAI_COMPATIBLE) {
            const selectedProvider = getSelectedOpenAICompatibleProvider()
            if (selectedProvider) {
                return selectedProvider.displayName
            }
            return openaiCompatibleModel || "OpenAI"
        }
        if (provider === ProviderConstants.PROVIDERS.OPENCODE) return "OpenCode"
        if (provider === ProviderConstants.PROVIDERS.PI) return "Pi"
        return "ChatQT"
    }

    function generateUuid() {
        return UuidGenerator.generateUuid()
    }

    function getOpenaiCompatibleProviders() {
        try {
            let providers = JSON.parse(openaiCompatibleProviders)
            return providers.map(function(p) {
                if (p.enabled === undefined) {
                    p.enabled = true
                }
                if (!p.id) {
                    p.id = generateUuid()
                }
                return p
            })
        } catch (e) {
            return []
        }
    }

    function saveOpenaiCompatibleProviders(array) {
        openaiCompatibleProviders = JSON.stringify(array)
    }

    function getFirstEnabledOpenAICompatibleProvider() {
        const providers = getOpenaiCompatibleProviders()
        for (let i = 0; i < providers.length; i++) {
            if (providers[i].enabled === true) {
                return providers[i]
            }
        }
        return null
    }

    function getSelectedOpenAICompatibleProvider() {
        const providers = getOpenaiCompatibleProviders()
        for (let i = 0; i < providers.length; i++) {
            if (providers[i].id === selectedOpenAICompatibleProviderId) {
                return providers[i]
            }
        }
        return null
    }

    function getOpenClawInstances() {
        try {
            let instances = JSON.parse(openclawInstances)
            return instances.map(function(i) {
                if (i.enabled === undefined) {
                    i.enabled = true
                }
                if (!i.id) {
                    i.id = generateUuid()
                }
                return i
            })
        } catch (e) {
            return []
        }
    }

    function saveOpenClawInstances(array) {
        openclawInstances = JSON.stringify(array)
    }

    function getFirstEnabledOpenClawInstance() {
        const instances = getOpenClawInstances()
        for (let i = 0; i < instances.length; i++) {
            if (instances[i].enabled === true) {
                return instances[i]
            }
        }
        return null
    }

    function getSelectedOpenClawInstance() {
        const instances = getOpenClawInstances()
        for (let i = 0; i < instances.length; i++) {
            if (instances[i].id === selectedOpenClawInstanceId) {
                return instances[i]
            }
        }
        return null
    }

    function getSkillFolders() {
        try {
            return JSON.parse(skillFolders)
        } catch (e) {
            return ["~/.skills", "~/.agents/skills"]
        }
    }

    function getMcpServers() {
        try {
            let servers = JSON.parse(mcpServers)
            return servers.map(function(s) {
                if (s.enabled === undefined) {
                    s.enabled = true
                }
                if (!s.id) {
                    s.id = generateUuid()
                }
                if (s.isBuiltIn === undefined) {
                    s.isBuiltIn = false
                }
                return s
            })
        } catch (e) {
            return []
        }
    }

    function ensureDefaultMcpServers() {
        let servers = getMcpServers()
        let hasBashMcp = false
        let hasFilesystem = false
        for (let i = 0; i < servers.length; i++) {
            if (servers[i].id === "built-in-bash-mcp") hasBashMcp = true
            if (servers[i].id === "built-in-filesystem") hasFilesystem = true
        }

        if (hasBashMcp && hasFilesystem) {
            if (!mcpDefaultsInitialized) mcpDefaultsInitialized = true
            return
        }

        if (!hasBashMcp) {
            servers.unshift({
                id: "built-in-bash-mcp",
                displayName: "Bash MCP",
                type: "stdio",
                enabled: true,
                isBuiltIn: true,
                command: "npx",
                args: "bash-mcp",
                env: ""
            })
        }
        if (!hasFilesystem) {
            servers.unshift({
                id: "built-in-filesystem",
                displayName: "Filesystem MCP",
                type: "stdio",
                enabled: true,
                isBuiltIn: true,
                command: "npx",
                args: "-y @modelcontextprotocol/server-filesystem " + _getHomeDir(),
                env: ""
            })
        }

        saveMcpServers(servers)
        mcpDefaultsInitialized = true
    }

    function _getHomeDir() {
        const homeUrl = StandardPaths.writableLocation(StandardPaths.HomeLocation)
        return homeUrl.toString().replace(/^file:\/\//, "")
    }

    function saveMcpServers(array) {
        mcpServers = JSON.stringify(array)
    }

    function getEnabledMcpServers() {
        const servers = getMcpServers()
        const enabled = []
        for (let i = 0; i < servers.length; i++) {
            if (servers[i].enabled === true) {
                enabled.push(servers[i])
            }
        }
        return enabled
    }

    function getMcpToolResults() {
        try {
            return JSON.parse(mcpToolResults)
        } catch (e) {
            return {}
        }
    }

    function saveMcpToolResults(results) {
        mcpToolResults = JSON.stringify(results)
    }

    function save() {
        _settings.setValue("provider", provider)
        _settings.setValue("openclawUrl", openclawUrl)
        _settings.setValue("openclawToken", openclawToken)
        _settings.setValue("openaiCompatibleUrl", openaiCompatibleUrl)
        _settings.setValue("openaiCompatibleToken", openaiCompatibleToken)
        _settings.setValue("openaiCompatibleModel", openaiCompatibleModel)
        _settings.setValue("openaiCompatibleProviders", openaiCompatibleProviders)
        _settings.setValue("opencodeUrl", opencodeUrl)
        _settings.setValue("opencodeUsername", opencodeUsername)
        _settings.setValue("opencodePassword", opencodePassword)
        _settings.setValue("opencodeModel", opencodeModel)
        _settings.setValue("ollamaEnabled", ollamaEnabled)
        _settings.setValue("openclawEnabled", openclawEnabledRaw)
        _settings.setValue("openaiCompatibleEnabled", openaiCompatibleEnabled)
        _settings.setValue("opencodeEnabled", opencodeEnabledRaw)
        _settings.setValue("piEnabled", piEnabledRaw)
        _settings.setValue("selectedOpenAICompatibleProviderId", selectedOpenAICompatibleProviderId)
        _settings.setValue("openclawInstances", openclawInstances)
        _settings.setValue("selectedOpenClawInstanceId", selectedOpenClawInstanceId)
        _settings.setValue("lastActiveSessionId", lastActiveSessionId)
        _settings.setValue("mcpServers", mcpServers)
        _settings.setValue("mcpDefaultsInitialized", mcpDefaultsInitialized)
        _settings.setValue("skillFolders", skillFolders)
        _settings.setValue("agentFilePath", agentFilePath)
        _settings.sync()
    }

    property Settings _settings: Settings {
        category: "Provider"
    }

    onProviderChanged: save()
    onOpenclawUrlChanged: save()
    onOpenclawTokenChanged: save()
    onOpenaiCompatibleUrlChanged: save()
    onOpenaiCompatibleTokenChanged: save()
    onOpenaiCompatibleModelChanged: save()
    onOpenaiCompatibleProvidersChanged: save()
    onOpencodeUrlChanged: save()
    onOpencodeUsernameChanged: save()
    onOpencodePasswordChanged: save()
    onOpencodeModelChanged: save()
    onOllamaEnabledChanged: save()
    onOpenclawEnabledChanged: save()
    onOpenaiCompatibleEnabledChanged: save()
    onOpencodeEnabledChanged: save()
    onPiEnabledChanged: save()
    onSelectedOpenAICompatibleProviderIdChanged: save()
    onOpenclawInstancesChanged: save()
    onSelectedOpenClawInstanceIdChanged: save()
    onLastActiveSessionIdChanged: save()
    onMcpServersChanged: save()
    onMcpDefaultsInitializedChanged: save()
    onSkillFoldersChanged: save()
    onAgentFilePathChanged: save()

    Component.onCompleted: {
        ensureDefaultMcpServers()

        if (typeof ProcessManager !== "undefined") {
            opencodeUrl = ProcessManager.serverUrl
            if (ProcessManager.password !== "") {
                opencodeUsername = "opencode"
                opencodePassword = ProcessManager.password
            }

            ProcessManager.serverUrlChanged.connect(function() {
                opencodeUrl = ProcessManager.serverUrl
            })
            ProcessManager.passwordChanged.connect(function() {
                if (ProcessManager.password !== "") {
                    opencodeUsername = "opencode"
                    opencodePassword = ProcessManager.password
                }
            })
        }

        if (openclawInstances === "[]") {
            if (openclawUrl !== "http://127.0.0.1:18789" || openclawToken !== "") {
                const migratedInstance = {
                    id: generateUuid(),
                    displayName: "OpenClaw",
                    url: openclawUrl,
                    token: openclawToken,
                    enabled: true
                }
                openclawInstances = JSON.stringify([migratedInstance])
                selectedOpenClawInstanceId = migratedInstance.id
                console.log("Migrated existing OpenClaw settings to multi-instance format")
            }
        }
    }
}
