const toastStack = document.getElementById('toastStack');
const alertStack = document.getElementById('alertStack');
const callsPanel = document.getElementById('callsPanel');
const callsList = document.getElementById('callsList');
const callStates = new Map();
let focused = false;
let currentFocusKey = 'N';

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

function getRole(call, selfServerId) {
    if (call.primaryUnit && Number(call.primaryUnit.source) === Number(selfServerId)) return 'primary';
    if ((call.attachedUnits || []).some(unit => Number(unit.source) === Number(selfServerId))) return 'attached';
    return 'observer';
}

function attachedSummary(call) {
    const units = call.attachedUnits || [];
    if (!units.length) return '<span class="unit-empty">No additional units attached</span>';
    const visible = units.slice(0, 2).map(unit => `<span class="unit-chip">${escapeHtml(unit.name)}</span>`).join('');
    const extra = units.length > 2 ? `<span class="unit-chip unit-more">+${units.length - 2} more</span>` : '';
    return visible + extra;
}

function statusInfo(call) {
    if (call.status === 'onscene') return { title: 'On Scene', label: 'ON SCENE', className: 'onscene' };
    if (call.status === 'enroute') return { title: 'En Route', label: 'EN ROUTE', className: 'enroute' };
    return { title: `Call #${call.id}`, label: 'NEW', className: 'incoming' };
}

function renderAlertCard(callId) {
    const state = callStates.get(Number(callId));
    if (!state || !state.element) return;

    const { call, data, element } = state;
    const active = call.status === 'enroute' || call.status === 'onscene';
    const status = statusInfo(call);
    const role = getRole(call, data.selfServerId);
    const primaryName = call.primaryUnit?.name || 'Unassigned';
    const attachedCount = (call.attachedUnits || []).length;
    currentFocusKey = String(data.focusKey || currentFocusKey || 'N').toUpperCase();

    let actionButton = '';
    if (!active) {
        actionButton = '<button class="respond-button primary-action">Respond & Set Waypoint</button>';
    } else if (role === 'primary') {
        actionButton = '<button class="close-callout-button danger-action">Close Callout</button>';
    } else if (role === 'attached') {
        actionButton = '<button class="detach-call-button secondary-action">Detach From Call</button>';
    } else {
        actionButton = '<button class="attach-call-button primary-action">Attach & Set Waypoint</button>';
    }

    element.className = `call-alert ${status.className} role-${role}`;
    element.innerHTML = `
        <div class="alert-accent"></div>
        <div class="alert-body">
            <div class="alert-top">
                <div>
                    <span class="eyebrow">${active ? 'Active 911 Callout' : 'Incoming 911 Call'}</span>
                    <div class="title-line">
                        <h3>${status.title}</h3>
                        <span class="status-pill status-${status.className}">${status.label}</span>
                    </div>
                </div>
                <span class="call-time">${relativeTime(call.createdAt)}</span>
            </div>

            <div class="alert-location-row">
                <span class="location-icon">◆</span>
                <div><small>LOCATION</small><strong>${escapeHtml(call.location)}</strong></div>
            </div>

            <div class="message-card">
                <small>CALL DETAILS</small>
                <p>${escapeHtml(call.message)}</p>
            </div>

            ${(data.showCallerName || data.showCallerServerId) ? `
                <div class="caller-row">
                    <span>CALLER</span>
                    <strong>${data.showCallerName ? escapeHtml(call.callerName) : ''}${data.showCallerServerId ? ` · ID ${call.callerId}` : ''}</strong>
                </div>` : ''}

            ${active ? `
                <div class="response-block">
                    <div class="primary-unit-row">
                        <div><span>PRIMARY UNIT</span><strong>${escapeHtml(primaryName)}</strong></div>
                        <span class="attached-count">${attachedCount} ATTACHED</span>
                    </div>
                    <div class="attached-units">${attachedSummary(call)}</div>
                    ${call.status === 'onscene' && call.onSceneBy ? `<div class="arrival-note">On scene confirmed by ${escapeHtml(call.onSceneBy.name)}</div>` : ''}
                </div>` : ''}

            <div class="alert-actions">
                ${actionButton}
                <span>${focused ? 'Interaction enabled' : `Press ${escapeHtml(currentFocusKey)} to interact`}</span>
            </div>
        </div>`;

    [
        ['.respond-button', 'respondCall'],
        ['.attach-call-button', 'attachCall'],
        ['.detach-call-button', 'detachCall'],
        ['.close-callout-button', 'closeCallout']
    ].forEach(([selector, endpoint]) => {
        const button = element.querySelector(selector);
        if (!button) return;
        button.addEventListener('click', () => {
            if (!focused) return;
            post(endpoint, { callId: call.id });
        });
    });
}

function upsertCallCard(data, persistent = false) {
    const call = data.call;
    let state = callStates.get(Number(call.id));

    if (!state) {
        const element = document.createElement('article');
        alertStack.prepend(element);
        state = { call, data, element, timer: null };
        callStates.set(Number(call.id), state);
    } else {
        state.call = call;
        state.data = { ...state.data, ...data };
    }

    if (state.timer) {
        clearTimeout(state.timer);
        state.timer = null;
    }

    renderAlertCard(call.id);

    if (!persistent && call.status === 'new') {
        const duration = Number(data.duration) || 12000;
        state.timer = setTimeout(() => {
            const current = callStates.get(Number(call.id));
            if (current && current.call.status === 'new' && current.element?.isConnected) {
                current.element.remove();
                callStates.delete(Number(call.id));
                post('cardHidden', { callId: call.id });
            }
        }, duration);
    }
}

function setFocusState(value) {
    focused = Boolean(value);
    callStates.forEach((_, callId) => renderAlertCard(callId));
}

function removeCall(callId) {
    const state = callStates.get(Number(callId));
    if (state?.timer) clearTimeout(state.timer);
    if (state?.element) state.element.remove();
    callStates.delete(Number(callId));
}

function clearCards() {
    callStates.forEach(state => {
        if (state.timer) clearTimeout(state.timer);
        if (state.element) state.element.remove();
    });
    callStates.clear();
}

function openCalls(data) {
    const calls = data.calls || [];
    callsPanel.classList.remove('hidden');
    if (!calls.length) {
        callsList.innerHTML = '<div class="empty-state"><h3>No recent calls</h3><p>The city has, against all historical evidence, decided to behave itself.</p></div>';
        return;
    }

    callsList.innerHTML = calls.map(call => {
        const primary = call.primaryUnit?.name || 'Unassigned';
        const attached = (call.attachedUnits || []).length;
        const label = call.status === 'onscene' ? 'On Scene' : call.status === 'enroute' ? `Primary: ${escapeHtml(primary)}` : 'Unassigned';
        return `
            <article class="call-row">
                <div class="call-id">#${call.id}</div>
                <div class="call-content">
                    <div class="call-heading"><strong>${escapeHtml(call.location)}</strong><span>${relativeTime(call.createdAt)}</span></div>
                    <p>${escapeHtml(call.message)}</p>
                    <div class="row-meta"><span>${label}</span>${call.status !== 'new' ? `<span>${attached} attached</span>` : ''}</div>
                </div>
                <button class="row-waypoint" data-call-id="${call.id}">Waypoint</button>
            </article>`;
    }).join('');

    callsList.querySelectorAll('[data-call-id]').forEach(button => {
        button.addEventListener('click', () => post('waypoint', { callId: Number(button.dataset.callId) }));
    });
}

document.getElementById('closeCalls').addEventListener('click', () => post('close'));
window.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
        if (!callsPanel.classList.contains('hidden')) post('close');
        else if (focused) post('releaseFocus');
        return;
    }
    if (focused && event.key.toUpperCase() === currentFocusKey) post('releaseFocus');
});

window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'toast') toast(data.message, data.kind);
    if (data.action === 'newCall') upsertCallCard(data, false);
    if (data.action === 'callUpdated') upsertCallCard(data, true);
    if (data.action === 'openCalls') openCalls(data);
    if (data.action === 'closeCalls') callsPanel.classList.add('hidden');
    if (data.action === 'syncCalls' && Array.isArray(data.calls) && !callsPanel.classList.contains('hidden')) openCalls(data);
    if (data.action === 'setFocusState') setFocusState(data.focused);
    if (data.action === 'removeCall') removeCall(data.callId);
    if (data.action === 'clearCards') clearCards();
});
