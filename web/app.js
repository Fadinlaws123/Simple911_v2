const toastStack = document.getElementById('toastStack');
const alertStack = document.getElementById('alertStack');
const callsPanel = document.getElementById('callsPanel');
const callsList = document.getElementById('callsList');

const resource = () => typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'Simple911_v2';
const post = (name, data = {}) => fetch(`https://${resource()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
});

const escapeHtml = value => String(value ?? '').replace(/[&<>'"]/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
}[char]));

function relativeTime(timestamp) {
    if (!timestamp) return 'Just now';
    const seconds = Math.max(0, Math.floor(Date.now() / 1000) - timestamp);
    if (seconds < 60) return `${seconds}s ago`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    return `${Math.floor(seconds / 3600)}h ago`;
}

function toast(message, kind = 'info') {
    const element = document.createElement('div');
    element.className = `toast ${kind}`;
    element.textContent = message;
    toastStack.appendChild(element);
    setTimeout(() => element.remove(), 5000);
}

function showCallAlert(data) {
    const call = data.call;
    const element = document.createElement('article');
    element.className = 'call-alert';
    element.innerHTML = `
        <div class="alert-accent"></div>
        <div class="alert-body">
            <div class="alert-top">
                <div>
                    <span class="eyebrow">Incoming 911 Call</span>
                    <h3>Call #${call.id}</h3>
                </div>
                <button class="alert-close" aria-label="Dismiss">×</button>
            </div>
            <div class="alert-location">${escapeHtml(call.location)}</div>
            <p>${escapeHtml(call.message)}</p>
            ${(data.showCallerName || data.showCallerServerId) ? `<div class="alert-caller">${data.showCallerName ? escapeHtml(call.callerName) : ''}${data.showCallerServerId ? ` · ID ${call.callerId}` : ''}</div>` : ''}
            <div class="alert-actions">
                <button class="waypoint-button">Set Waypoint</button>
                <span>${relativeTime(call.createdAt)}</span>
            </div>
        </div>`;

    element.querySelector('.alert-close').addEventListener('click', () => element.remove());
    element.querySelector('.waypoint-button').addEventListener('click', () => post('waypoint', { callId: call.id }));
    alertStack.prepend(element);

    const duration = Number(data.duration) || 12000;
    setTimeout(() => element.remove(), duration);
}

function openCalls(data) {
    const calls = data.calls || [];
    callsPanel.classList.remove('hidden');
    if (!calls.length) {
        callsList.innerHTML = '<div class="empty-state"><h3>No recent calls</h3><p>The city has, against all historical evidence, decided to behave itself.</p></div>';
        return;
    }

    callsList.innerHTML = calls.map(call => `
        <article class="call-row">
            <div class="call-id">#${call.id}</div>
            <div class="call-content">
                <div class="call-heading">
                    <strong>${escapeHtml(call.location)}</strong>
                    <span>${relativeTime(call.createdAt)}</span>
                </div>
                <p>${escapeHtml(call.message)}</p>
                ${(data.showCallerName || data.showCallerServerId) ? `<small>${data.showCallerName ? escapeHtml(call.callerName) : ''}${data.showCallerServerId ? ` · ID ${call.callerId}` : ''}</small>` : ''}
            </div>
            <button class="row-waypoint" data-call-id="${call.id}">Waypoint</button>
        </article>`).join('');

    callsList.querySelectorAll('[data-call-id]').forEach(button => {
        button.addEventListener('click', () => post('waypoint', { callId: Number(button.dataset.callId) }));
    });
}

document.getElementById('closeCalls').addEventListener('click', () => post('close'));
window.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !callsPanel.classList.contains('hidden')) post('close');
});

window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'toast') toast(data.message, data.kind);
    if (data.action === 'newCall') showCallAlert(data);
    if (data.action === 'openCalls') openCalls(data);
    if (data.action === 'closeCalls') callsPanel.classList.add('hidden');
    if (data.action === 'syncCalls' && Array.isArray(data.calls) && !callsPanel.classList.contains('hidden')) openCalls(data);
});
