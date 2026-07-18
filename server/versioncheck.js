const https = require('https');
const { URL } = require('url');

const resourceName = GetCurrentResourceName();
const timeoutMs = 15000;
const boxWidth = 86;

const scriptArt = [
    '  ____  _                 _       ___  _ _ ',
    '/ ___|(_)_ __ ___  _ __ | | ___/  _ \\/ / |',
    ' \\___ \\| | \'_ ` _ \\| \'_ \\| |/ _ \\ (_) | | |',
    '  ___) | | | | | | | |_) | |  __/\\__, | | |',
    ' |____/|_|_| |_| |_| .__/|_|\\___|  /_/|_|_|',
    '                   |_|                     ',
    '                               ^3 v2'
];

const colorMap = {
    '^0': '\u001b[0m',
    '^1': '\u001b[31m',
    '^2': '\u001b[32m',
    '^3': '\u001b[33m',
    '^4': '\u001b[34m',
    '^5': '\u001b[35m',
    '^6': '\u001b[36m',
    '^7': '\u001b[37m',
};

function colorize(text) {
    return String(text || '').replace(/\^\d/g, match => colorMap[match] || '') + '\u001b[0m';
}

function stripColors(text) {
    return String(text || '').replace(/\^\d/g, '');
}

function plainLength(text) {
    return stripColors(text).length;
}

function printLine(text) {
    console.log(colorize(text));
}

function printEmpty(width = boxWidth) {
    printLine(`^5║${' '.repeat(width - 2)}║^7`);
}

function printCenter(text, width = boxWidth) {
    const innerWidth = width - 2;
    const visible = plainLength(text);
    const totalPadding = Math.max(0, innerWidth - visible);
    const left = Math.floor(totalPadding / 2);
    const right = totalPadding - left;
    printLine(`^5║${' '.repeat(left)}${text}${' '.repeat(right)}║^7`);
}

function printDivider(label, width = boxWidth) {
    const visible = plainLength(label) + 4;
    const remaining = Math.max(0, width - 2 - visible);
    const left = Math.floor(remaining / 2);
    const right = remaining - left;
    printLine(`^5╠${'═'.repeat(left)}[ ^6${label} ^5]${'═'.repeat(right)}╣^7`);
}

function wrapText(text, width) {
    const tokens = String(text || '').match(/\^\d|\S+|\s+/g) || [];
    const lines = [];
    let current = '';
    let currentLength = 0;

    const pushCurrent = () => {
        if (currentLength > 0 || current.trim().length > 0) {
            lines.push(current.trimEnd());
        }
        current = '';
        currentLength = 0;
    };

    for (const token of tokens) {
        if (/\^\d/.test(token)) {
            current += token;
            continue;
        }

        if (/^\s+$/.test(token)) {
            if (currentLength > 0) {
                current += ' ';
                currentLength += 1;
            }
            continue;
        }

        const visibleLength = token.length;

        if (visibleLength > width) {
            if (currentLength > 0) pushCurrent();

            let remainder = token;
            while (remainder.length > width) {
                lines.push(remainder.slice(0, width));
                remainder = remainder.slice(width);
            }

            if (remainder.length > 0) {
                current = remainder;
                currentLength = remainder.length;
            }
            continue;
        }

        if (currentLength + visibleLength > width) pushCurrent();

        current += token;
        currentLength += visibleLength;
    }

    pushCurrent();
    return lines.length ? lines : [''];
}

function printWrappedCenter(text, color = '^7', width = boxWidth) {
    const innerWidth = width - 6;
    const lines = wrapText(text, innerWidth);

    for (const line of lines) {
        const content = /^\^\d/.test(line) ? `${line}^5` : `${color}${line}^5`;
        printCenter(content, width);
    }
}

function compareVersions(currentVersion, latestVersion) {
    const currentParts = String(currentVersion || '0').replace(/^v/i, '').split('.').map(part => parseInt(part, 10) || 0);
    const latestParts = String(latestVersion || '0').replace(/^v/i, '').split('.').map(part => parseInt(part, 10) || 0);
    const length = Math.max(currentParts.length, latestParts.length);

    for (let index = 0; index < length; index += 1) {
        const current = currentParts[index] || 0;
        const latest = latestParts[index] || 0;
        if (current > latest) return 1;
        if (current < latest) return -1;
    }

    return 0;
}

function readConfigFile() {
    try {
        const content = LoadResourceFile(resourceName, 'config.lua');
        return typeof content === 'string' ? content : '';
    } catch (error) {
        return '';
    }
}

function getConfigValue(configContent, keyPath) {
    if (!configContent) return null;

    const key = keyPath.split('.').pop();
    const blockMatch = configContent.match(/Config\.VersionChecker\s*=\s*\{([\s\S]*?)\}/i);

    if (blockMatch && blockMatch[1]) {
        const blockPattern = new RegExp(`${key}\\s*=\\s*(["']([^"']+)["']|true|false|\\d+(?:\\.\\d+)?)`, 'i');
        const blockValue = blockMatch[1].match(blockPattern);
        if (blockValue) {
            return blockValue[2] ? String(blockValue[2]).trim() : String(blockValue[1]).trim();
        }
    }

    const fullPattern = new RegExp(`${keyPath.replace(/\./g, '\\.')}\\s*=\\s*(["']([^"']+)["']|true|false|\\d+(?:\\.\\d+)?)`, 'i');
    const fullValue = configContent.match(fullPattern);
    if (!fullValue) return null;

    return fullValue[2] ? String(fullValue[2]).trim() : String(fullValue[1]).trim();
}

function getVersionConfig() {
    const configContent = readConfigFile();
    const enabled = String(getConfigValue(configContent, 'Config.VersionChecker.enabled') || 'false').toLowerCase() === 'true';
    const versionFileUrl = getConfigValue(configContent, 'Config.VersionChecker.versionFileUrl') || '';
    const currentVersion = GetResourceMetadata(resourceName, 'version', 0) || '1.0.0';

    return {
        enabled,
        currentVersion,
        versionFileUrl,
    };
}

function fetchVersionData(versionUrl, currentVersion) {
    return new Promise(resolve => {
        const fallback = {
            enabled: false,
            checked: false,
            current: currentVersion,
            latest: '?',
            comparison: 0,
            message: 'Version checker disabled.',
            downloadUrl: '',
            changelog: [],
        };

        if (!versionUrl) {
            resolve({
                ...fallback,
                checked: true,
                message: 'Version URL is not configured.',
            });
            return;
        }

        let parsedUrl;
        try {
            parsedUrl = new URL(versionUrl);
        } catch (error) {
            resolve({
                ...fallback,
                checked: true,
                message: 'Version URL is invalid.',
            });
            return;
        }

        const request = https.get({
            hostname: parsedUrl.hostname,
            path: parsedUrl.pathname + parsedUrl.search,
            port: parsedUrl.port || 443,
            timeout: timeoutMs,
            headers: {
                'User-Agent': `${resourceName}-VersionChecker`,
                Accept: 'application/json, text/plain, */*',
            },
        }, response => {
            let body = '';

            response.on('data', chunk => {
                body += chunk;
            });

            response.on('end', () => {
                if (response.statusCode < 200 || response.statusCode >= 300) {
                    resolve({
                        ...fallback,
                        checked: true,
                        message: `Version check failed with HTTP ${response.statusCode}.`,
                    });
                    return;
                }

                try {
                    const data = JSON.parse(body || '{}');
                    const latest = String(data.latest_version || data.version || '?');
                    const comparison = latest !== '?' ? compareVersions(currentVersion, latest) : 0;
                    const changelog = Array.isArray(data.changelog) ? data.changelog : [];

                    resolve({
                        enabled: true,
                        checked: true,
                        current: currentVersion,
                        latest,
                        comparison,
                        message: comparison < 0
                            ? 'Update available.'
                            : comparison > 0
                                ? 'Running a newer/development build.'
                                : 'Resource is up to date.',
                        downloadUrl: String(data.download_url || ''),
                        changelog,
                    });
                } catch (error) {
                    resolve({
                        ...fallback,
                        checked: true,
                        message: 'Version response could not be parsed.',
                    });
                }
            });
        });

        request.on('timeout', () => {
            request.destroy();
            resolve({
                ...fallback,
                checked: true,
                message: 'Version check timed out.',
            });
        });

        request.on('error', error => {
            resolve({
                ...fallback,
                checked: true,
                message: `Version check failed: ${String(error.message || 'Unknown error.')}`,
            });
        });
    });
}

function printVersionSection(versionData) {
    printDivider('Version Status');
    printEmpty();

    if (!versionData.enabled) {
        printWrappedCenter(versionData.message || 'Version checker is disabled in config.lua.', '^4');
        printEmpty();
        return;
    }

    printWrappedCenter(`^7Current Version: ^2${versionData.current}   ^7Latest Version: ${versionData.comparison < 0 ? '^3' : '^2'}${versionData.latest}`, '^7');
    printWrappedCenter(versionData.message, versionData.comparison < 0 ? '^3' : '^2');

    if (versionData.downloadUrl) {
        printWrappedCenter(`^7Download: ^5${versionData.downloadUrl}`, '^7');
    }

    if (versionData.comparison < 0 && versionData.changelog.length > 0) {
        const latestEntry = versionData.changelog[0];
        if (latestEntry && Array.isArray(latestEntry.changes)) {
            printEmpty();
            printDivider('Latest Changes');
            printEmpty();
            printWrappedCenter(`^6v${latestEntry.version || versionData.latest}^7 ${latestEntry.date ? `(${latestEntry.date})` : ''}`, '^7');
            latestEntry.changes.slice(0, 4).forEach(change => {
                printWrappedCenter(`^7• ${change}`, '^7');
            });
        }
    }

    printEmpty();
}

function printBanner(versionData) {
    const top = '╔' + '═'.repeat(boxWidth - 2) + '╗';
    const bottom = '╚' + '═'.repeat(boxWidth - 2) + '╝';

    printLine(`^5${top}`);
    printEmpty();
    scriptArt.forEach(line => printCenter(`^2${line}^5`));
    printEmpty();
    printDivider('Resource Information');
    printEmpty();
    printCenter(`^7Resource:^5 ${resourceName}`);
    printCenter(`^7Version:^5 ${versionData.current || GetResourceMetadata(resourceName, 'version', 0) || 'Unknown'}`);
    printEmpty();
    printVersionSection(versionData);
    printDivider('Community & Support');
    printEmpty();
    printWrappedCenter('^7Join our Discord: ^5https://discord.gg/RquDVTfDwu', '^7');
    printWrappedCenter('^7Find more scripts at: ^5https://simpledevelopments.org/', '^7');
    printWrappedCenter('^7GitHub: ^5https://github.com/Fadinlaws123/Simple911_v2', '^7');
    printEmpty();
    printLine(`^5${bottom}`);
}

async function runVersionCheck() {
    const versionConfig = getVersionConfig();

    const versionData = versionConfig.enabled
        ? await fetchVersionData(versionConfig.versionFileUrl, versionConfig.currentVersion)
        : {
            enabled: false,
            checked: false,
            current: versionConfig.currentVersion,
            latest: '?',
            comparison: 0,
            message: 'Version checker is disabled in config.lua.',
            downloadUrl: '',
            changelog: [],
        };

    printBanner(versionData);
}

on('onResourceStart', startedResource => {
    if (startedResource !== resourceName) return;

    runVersionCheck().catch(error => {
        const versionConfig = getVersionConfig();
        printBanner({
            enabled: versionConfig.enabled,
            checked: false,
            current: versionConfig.currentVersion,
            latest: '?',
            comparison: 0,
            message: `Version check failed unexpectedly: ${error && error.message ? String(error.message) : 'Unknown error.'}`,
            downloadUrl: '',
            changelog: [],
        });
    });
});
