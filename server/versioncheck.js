const https = require('https');
const { URL } = require('url');

const resourceName = GetCurrentResourceName();
const timeoutMs = 15000;
const boxWidth = 82;

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

function printLine(text) {
    console.log(colorize(text));
}

function printCenter(text) {
    const innerWidth = boxWidth - 2;
    const visibleLength = stripColors(text).length;
    const padding = Math.max(0, innerWidth - visibleLength);
    const left = Math.floor(padding / 2);
    const right = padding - left;
    printLine(`^5║${' '.repeat(left)}${text}${' '.repeat(right)}║^7`);
}

function printDivider(label) {
    const labelWidth = stripColors(label).length + 4;
    const remaining = Math.max(0, boxWidth - 2 - labelWidth);
    const left = Math.floor(remaining / 2);
    const right = remaining - left;
    printLine(`^5╠${'═'.repeat(left)}[ ^6${label} ^5]${'═'.repeat(right)}╣^7`);
}

function compareVersions(currentVersion, latestVersion) {
    const normalize = value => String(value || '0')
        .replace(/^v/i, '')
        .split(/[.-]/)
        .map(part => (/^\d+$/.test(part) ? Number(part) : part.toLowerCase()));

    const current = normalize(currentVersion);
    const latest = normalize(latestVersion);
    const length = Math.max(current.length, latest.length);

    for (let index = 0; index < length; index += 1) {
        const a = current[index];
        const b = latest[index];

        if (a === undefined && b === undefined) return 0;
        if (a === undefined) return typeof b === 'string' ? 1 : -1;
        if (b === undefined) return typeof a === 'string' ? -1 : 1;
        if (a === b) continue;

        if (typeof a === 'number' && typeof b === 'number') return a > b ? 1 : -1;
        if (typeof a === 'number') return 1;
        if (typeof b === 'number') return -1;
        return a > b ? 1 : -1;
    }

    return 0;
}

function readVersionConfig() {
    try {
        const config = LoadResourceFile(resourceName, 'config.lua') || '';
        const block = config.match(/Config\.VersionChecker\s*=\s*\{([\s\S]*?)\}/i);

        if (!block) {
            return { enabled: false, versionFileUrl: '' };
        }

        const body = block[1];
        const enabledMatch = body.match(/enabled\s*=\s*(true|false)/i);
        const urlMatch = body.match(/versionFileUrl\s*=\s*["']([^"']+)["']/i);

        return {
            enabled: enabledMatch ? enabledMatch[1].toLowerCase() === 'true' : false,
            versionFileUrl: urlMatch ? urlMatch[1].trim() : '',
        };
    } catch (error) {
        return { enabled: false, versionFileUrl: '' };
    }
}

function fetchVersionData(versionUrl) {
    return new Promise(resolve => {
        let parsedUrl;

        try {
            parsedUrl = new URL(versionUrl);
        } catch (error) {
            resolve({ ok: false, message: 'The configured version URL is invalid.' });
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
                    resolve({ ok: false, message: `Version check returned HTTP ${response.statusCode}.` });
                    return;
                }

                try {
                    const data = JSON.parse(body || '{}');
                    const latest = String(data.latest_version || data.version || '').trim();

                    if (!latest) {
                        resolve({ ok: false, message: 'Version response did not include a latest version.' });
                        return;
                    }

                    resolve({
                        ok: true,
                        latest,
                        downloadUrl: String(data.download_url || ''),
                        changelog: Array.isArray(data.changelog) ? data.changelog : [],
                    });
                } catch (error) {
                    resolve({ ok: false, message: 'Version response could not be parsed as JSON.' });
                }
            });
        });

        request.on('timeout', () => {
            request.destroy();
            resolve({ ok: false, message: 'Version check timed out.' });
        });

        request.on('error', error => {
            resolve({ ok: false, message: `Version check failed: ${error.message || 'Unknown network error.'}` });
        });
    });
}

function printVersionResult(currentVersion, result) {
    const top = '╔' + '═'.repeat(boxWidth - 2) + '╗';
    const bottom = '╚' + '═'.repeat(boxWidth - 2) + '╝';

    printLine(`^5${top}`);
    printCenter('^2Simple911 v2 ^7• ^6Version Checker');
    printDivider('Version Status');

    if (!result.ok) {
        printCenter(`^1${result.message}`);
        printLine(`^5${bottom}`);
        return;
    }

    const comparison = compareVersions(currentVersion, result.latest);
    printCenter(`^7Current: ^2${currentVersion}   ^7Latest: ${comparison < 0 ? '^3' : '^2'}${result.latest}`);

    if (comparison < 0) {
        printCenter('^3An update is available for Simple911 v2.');
        if (result.downloadUrl) printCenter(`^7Download: ^5${result.downloadUrl}`);

        const latestEntry = result.changelog[0];
        if (latestEntry && Array.isArray(latestEntry.changes) && latestEntry.changes.length > 0) {
            printDivider('Latest Changes');
            latestEntry.changes.slice(0, 4).forEach(change => printCenter(`^7• ${String(change)}`));
        }
    } else if (comparison > 0) {
        printCenter('^4You are running a newer or development build.');
    } else {
        printCenter('^2Simple911 v2 is up to date.');
    }

    printLine(`^5${bottom}`);
}

async function checkVersion() {
    const config = readVersionConfig();
    if (!config.enabled) return;

    if (!config.versionFileUrl) {
        console.log('[Simple911 Version] Version checker enabled, but versionFileUrl is empty.');
        return;
    }

    const currentVersion = GetResourceMetadata(resourceName, 'version', 0) || '0.0.0';
    const result = await fetchVersionData(config.versionFileUrl);
    printVersionResult(currentVersion, result);
}

on('onResourceStart', startedResource => {
    if (startedResource !== resourceName) return;

    checkVersion().catch(error => {
        console.log(`[Simple911 Version] Version check failed unexpectedly: ${error?.message || 'Unknown error.'}`);
    });
});
