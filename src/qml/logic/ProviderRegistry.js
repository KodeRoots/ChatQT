/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

const PROVIDER_KEYS = {
    OLLAMA: "ollama",
    OPENCLAW: "openclaw",
    OPENAI_COMPATIBLE: "openai-compatible",
    OPENCODE: "opencode",
    PI: "pi"
};

const _providers = {};

function registerProvider(key, provider) {
    _providers[key] = provider;
}

function getProvider(providerKey) {
    const baseKey = providerKey.split(":")[0];
    return _providers[baseKey] || null;
}

function allProviders() {
    return Object.keys(_providers);
}

function registerOllama() {
    registerProvider(PROVIDER_KEYS.OLLAMA, {
        sendRequest: function(params) {
            const mcpFuncs = params.mcpFunctions && params.mcpFunctions.length > 0 ? params.mcpFunctions : undefined;
            return params.ApiClient.requestOllama(
                params.model,
                params.promptArray,
                params.listModel,
                params.onStreaming,
                params.onComplete,
                params.thinkingEnabled,
                mcpFuncs
            );
        },
        sendMcpFollowUp: function(params) {
            const mcpFuncs = params.mcpFunctions && params.mcpFunctions.length > 0 ? params.mcpFunctions : undefined;
            return params.ApiClient.requestOllama(
                params.model,
                params.promptArray,
                params.listModel,
                params.onStreaming,
                params.onComplete,
                params.thinkingEnabled,
                mcpFuncs
            );
        },
        abortRequest: function(deps) {
            deps.ApiClient.abortActiveRequest();
        },
        isConfigured: function(deps) {
            return deps.hasLocalModel;
        },
        notConfiguredMessage: function(deps) {
            return deps.i18n("No local model found.\nPlease install some first.\n\nIf you need help, check Ollama documentation.");
        },
        displayName: function(deps) {
            return "Ollama";
        }
    });
}

function registerOpenClaw() {
    registerProvider(PROVIDER_KEYS.OPENCLAW, {
        sendRequest: function(params) {
            const instance = params.appSettings.getSelectedOpenClawInstance();
            if (!instance) return null;
            return params.ApiClient.requestOpenAICompatible(
                instance.url,
                instance.token,
                "openclaw",
                params.promptArray,
                params.thinkingEnabled,
                { "x-openclaw-agent-id": "main" },
                true,
                params.listModel,
                params.onStreaming,
                params.onComplete
            );
        },
        sendMcpFollowUp: function(params) {
            const instance = params.appSettings.getSelectedOpenClawInstance();
            if (!instance) return null;
            return params.ApiClient.requestOpenAICompatible(
                instance.url,
                instance.token,
                "openclaw",
                params.promptArray,
                params.thinkingEnabled,
                { "x-openclaw-agent-id": "main" },
                true,
                params.listModel,
                params.onStreaming,
                params.onComplete
            );
        },
        abortRequest: function(deps) {
            deps.ApiClient.abortActiveRequest();
        },
        isConfigured: function(deps) {
            const instance = deps.appSettings.getSelectedOpenClawInstance();
            return instance && instance.url && instance.token;
        },
        notConfiguredMessage: function(deps) {
            return deps.i18n("OpenClaw instance not configured.\nPlease set URL and Token in settings.");
        },
        displayName: function(deps) {
            const instance = deps.appSettings.getSelectedOpenClawInstance();
            if (instance) return instance.displayName;
            return "OpenClaw";
        }
    });
}

function registerOpenAICompatible() {
    registerProvider(PROVIDER_KEYS.OPENAI_COMPATIBLE, {
        sendRequest: function(params) {
            const provider = params.appSettings.getSelectedOpenAICompatibleProvider();
            if (!provider) return null;
            const mcpFuncs = params.mcpFunctions && params.mcpFunctions.length > 0 ? params.mcpFunctions : undefined;
            return params.ApiClient.requestOpenAICompatible(
                provider.url,
                provider.token,
                provider.model,
                params.promptArray,
                params.thinkingEnabled,
                null,
                false,
                params.listModel,
                params.onStreaming,
                params.onComplete,
                mcpFuncs
            );
        },
        sendMcpFollowUp: function(params) {
            const provider = params.appSettings.getSelectedOpenAICompatibleProvider();
            if (!provider) return null;
            const mcpFuncs = params.mcpFunctions && params.mcpFunctions.length > 0 ? params.mcpFunctions : undefined;
            return params.ApiClient.requestOpenAICompatible(
                provider.url,
                provider.token,
                provider.model,
                params.promptArray,
                params.thinkingEnabled,
                null,
                false,
                params.listModel,
                params.onStreaming,
                params.onComplete,
                mcpFuncs
            );
        },
        abortRequest: function(deps) {
            deps.ApiClient.abortActiveRequest();
        },
        isConfigured: function(deps) {
            const provider = deps.appSettings.getSelectedOpenAICompatibleProvider();
            return provider && provider.url && provider.token && provider.model;
        },
        notConfiguredMessage: function(deps) {
            return deps.i18n("OpenAI Compatible provider not configured.\nPlease configure it in settings.");
        },
        displayName: function(deps) {
            const provider = deps.appSettings.getSelectedOpenAICompatibleProvider();
            if (provider) return provider.displayName;
            return deps.appSettings.openaiCompatibleModel || "OpenAI";
        }
    });
}

function registerOpenCode() {
    registerProvider(PROVIDER_KEYS.OPENCODE, {
        sendRequest: function(params) {
            return params.OpenCodeClient.requestOpenCode(
                params.appSettings.opencodeUrl,
                params.appSettings.opencodeUsername,
                params.appSettings.opencodePassword,
                params.appSettings.opencodeModel,
                params.promptArray,
                params.listModel,
                params.onStreaming,
                params.onComplete
            );
        },
        sendMcpFollowUp: function(params) {
            return params.OpenCodeClient.requestOpenCode(
                params.appSettings.opencodeUrl,
                params.appSettings.opencodeUsername,
                params.appSettings.opencodePassword,
                params.appSettings.opencodeModel,
                params.promptArray,
                params.listModel,
                params.onStreaming,
                params.onComplete
            );
        },
        abortRequest: function(deps) {
            deps.OpenCodeClient.abortActiveRequest();
        },
        isConfigured: function(deps) {
            return deps.appSettings.opencodeUrl &&
                   deps.appSettings.opencodeUsername &&
                   deps.appSettings.opencodePassword;
        },
        notConfiguredMessage: function(deps) {
            return deps.i18n("OpenCode not configured.\nPlease set URL, Username, Password and Model in settings.");
        },
        displayName: function(deps) {
            return "OpenCode";
        }
    });
}

function registerPi() {
    registerProvider(PROVIDER_KEYS.PI, {
        sendRequest: function(params) {
            return params.PiClient.requestPi(
                params.PiProcessManager,
                params.promptArray,
                params.listModel,
                params.onStreaming,
                params.onComplete
            );
        },
        sendMcpFollowUp: function(params) {
            return params.PiClient.requestPi(
                params.PiProcessManager,
                params.promptArray,
                params.listModel,
                params.onStreaming,
                params.onComplete
            );
        },
        abortRequest: function(deps) {
            deps.PiClient.abortActiveRequest();
        },
        isConfigured: function(deps) {
            return deps.PiProcessManager.running;
        },
        notConfiguredMessage: function(deps) {
            return deps.i18n("Pi is not running.\nPlease start it in Settings or check the binary path.");
        },
        displayName: function(deps) {
            return "Pi";
        }
    });
}

function initAllProviders() {
    registerOllama();
    registerOpenClaw();
    registerOpenAICompatible();
    registerOpenCode();
    registerPi();
}

initAllProviders();
