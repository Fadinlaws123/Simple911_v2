const toastStack = document.getElementById('toastStack');
const alertStack = document.getElementById('alertStack');
const callsPanel = document.getElementById('callsPanel');
const callsList = document.getElementById('callsList');
const callStates = new Map();
let focused = false;
let currentFocusKey = 'N';
let recentCalls = [];
let recentSelfServerId = null;

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
    if (!active) actionButton = '<button class="respond-button primary-action">Respond & Set Waypoint</button>';
    else if (role === 'primary') actionButton = '<button class="close-callout-button danger-action">Close Callout</button>';
    else if (role === 'attached') actionButton = '<button class="detach-call-button secondary-action">Detach From Call</button>';
    else actionButton = '<button class="attach-call-button primary-action">Attach & Set Waypoint</button>';

    element.className = `call-alert ${status.className} role-${role}`;
    element.innerHTML = `
        <div class="alert-accent"></div>
        <div class="alert-body">
            <div class="alert-top">
                <div>
                    <span class="eyebrow">${active ? 'Active 911 Callout' : 'Incoming 911 Call'}</span>
                    <div class="title-line"><h3>${status.title}</h3><span class="status-pill status-${status.className}">${status.label}</span></div>
                </div>
                <span class="call-time">${relativeTime(call.createdAt)}</span>
            </div>
            <div class="alert-location-row"><span class="location-icon">◆</span><div><small>LOCATION</small><strong>${escapeHtml(call.location)}</strong></div></div>
            <div class="message-card"><small>CALL DETAILS</small><p>${escapeHtml(call.message)}</p></div>
            ${(data.showCallerName || data.showCallerServerId) ? `<div class="caller-row"><span>CALLER</span><strong>${data.showCallerName ? escapeHtml(call.callerName) : ''}${data.showCallerServerId ? ` · ID ${call.callerId}` : ''}</strong></div>` : ''}
            ${active ? `<div class="response-block"><div class="primary-unit-row"><div><span>PRIMARY UNIT</span><strong>${escapeHtml(primaryName)}</strong></div><span class="attached-count">${attachedCount} ATTACHED</span></div><div class="attached-units">${attachedSummary(call)}</div>${call.status === 'onscene' && call.onSceneBy ? `<div class="arrival-note">On scene confirmed by ${escapeHtml(call.onSceneBy.name)}</div>` : ''}</div>` : ''}
            <div class="alert-actions">${actionButton}<span>${focused ? 'Interaction enabled' : `Press ${escapeHtml(currentFocusKey)} to interact`}</span></div>
        </div>`;

    [['.respond-button','respondCall'],['.attach-call-button','attachCall'],['.detach-call-button','detachCall'],['.close-callout-button','closeCallout']].forEach(([selector, endpoint]) => {
        const button = element.querySelector(selector);
        if (button) button.addEventListener('click', () => focused && post(endpoint, { callId: call.id }));
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
    if (state.timer) { clearTimeout(state.timer); state.timer = null; }
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
    recentCalls = recentCalls.filter(call => Number(call.id) !== Number(callId));
    if (!callsPanel.classList.contains('hidden')) renderRecentCalls();
}

function clearCards() {
    callStates.forEach(state => {
        if (state.timer) clearTimeout(state.timer);
        if (state.element) state.element.remove();
    });
    callStates.clear();
}

function recentCallStatus(call) {
    if (call.status === 'onscene') return { label: 'ON SCENE', className: 'recent-onscene', icon: '✓', subtitle: 'Units have arrived' };
    if (call.status === 'enroute') return { label: 'EN ROUTE', className: 'recent-enroute', icon: '↗', subtitle: 'Response in progress' };
    return { label: 'NEW CALL', className: 'recent-new', icon: '!', subtitle: 'Waiting for a unit' };
}

function recentActionButtons(call, role) {
    const active = call.status === 'enroute' || call.status === 'onscene';
    if (!active) {
        return `<button class="recent-action recent-primary" data-action="respondCall" data-call-id="${call.id}">Respond & Waypoint</button>`;
    }
    if (role === 'primary') {
        return `<button class="recent-action recent-secondary" data-action="waypoint" data-call-id="${call.id}">Waypoint</button><button class="recent-action recent-danger" data-action="closeCallout" data-call-id="${call.id}">Close Callout</button>`;
    }
    if (role === 'attached') {
        return `<button class="recent-action recent-secondary" data-action="waypoint" data-call-id="${call.id}">Waypoint</button><button class="recent-action recent-muted" data-action="detachCall" data-call-id="${call.id}">Detach</button>`;
    }
    return `<button class="recent-action recent-secondary" data-action="waypoint" data-call-id="${call.id}">Waypoint</button><button class="recent-action recent-primary" data-action="attachCall" data-call-id="${call.id}">Attach & Waypoint</button>`;
}

function attachedUnitsText(call) {
    const units = call.attachedUnits || [];
    if (!units.length) return '<span class="recent-empty-copy">No additional units</span>';
    return units.slice(0, 4).map(unit => `<span class="recent-unit-chip">${escapeHtml(unit.name)}</span>`).join('') + (units.length > 4 ? `<span class="recent-unit-chip recent-more-chip">+${units.length - 4}</span>` : '');
}

function renderRecentCalls() {
    if (!recentCalls.length) {
        callsList.innerHTML = `<div class="recent-empty-state"><div class="recent-empty-icon">✓</div><h3>No active 911 calls</h3><p>Nothing currently needs a response.</p></div>`;
        return;
    }

    callsList.innerHTML = recentCalls.map(call => {
        const status = recentCallStatus(call);
        const role = getRole(call, recentSelfServerId);
        const primary = call.primaryUnit?.name || 'No primary unit';
        const roleLabel = role === 'primary' ? 'You are primary' : role === 'attached' ? 'You are attached' : 'Not assigned';
        const caller = call.callerName || 'Unknown Caller';

        return `
            <article class="recent-call-card ${status.className}">
                <div class="recent-card-accent"></div>
                <div class="recent-card-shell">
                    <div class="recent-card-header">
                        <div class="recent-status-mark">${status.icon}</div>
                        <div class="recent-heading-copy">
                            <div class="recent-kicker-row">
                                <span class="recent-call-number">CALL #${call.id}</span>
                                <span class="recent-status-pill">${status.label}</span>
                            </div>
                            <h3>${escapeHtml(call.location)}</h3>
                            <p>${status.subtitle} · ${relativeTime(call.createdAt)}</p>
                        </div>
                        <span class="recent-role-pill ${role !== 'observer' ? 'active' : ''}">${roleLabel}</span>
                    </div>

                    <div class="recent-card-content">
                        <div class="recent-main-column">
                            <div class="recent-section recent-details-section">
                                <span class="recent-section-label">CALL DETAILS</span>
                                <p>${escapeHtml(call.message)}</p>
                            </div>
                            <div class="recent-caller-line">
                                <span>Caller</span>
                                <strong>${escapeHtml(caller)}</strong>
                            </div>
                        </div>

                        <div class="recent-response-column">
                            <div class="recent-response-box">
                                <span class="recent-section-label">PRIMARY UNIT</span>
                                <strong>${escapeHtml(primary)}</strong>
                            </div>
                            <div class="recent-response-box">
                                <div class="recent-box-heading">
                                    <span class="recent-section-label">ATTACHED UNITS</span>
                                    <span class="recent-count-badge">${(call.attachedUnits || []).length}</span>
                                </div>
                                <div class="recent-unit-list">${attachedUnitsText(call)}</div>
                            </div>
                            ${call.status === 'onscene' && call.onSceneBy ? `<div class="recent-onscene-line"><span>✓</span><div><small>ON SCENE CONFIRMED BY</small><strong>${escapeHtml(call.onSceneBy.name)}</strong></div></div>` : ''}
                        </div>
                    </div>

                    <div class="recent-card-actions">
                        ${recentActionButtons(call, role)}
                    </div>
                </div>
            </article>`;
    }).join('');

    callsList.querySelectorAll('[data-action][data-call-id]').forEach(button => {
        button.addEventListener('click', async () => {
            const callId = Number(button.dataset.callId);
            const action = button.dataset.action;
            button.disabled = true;
            try {
                await post(action, { callId });
            } finally {
                await post('close');
            }
        });
    });
}

function openCalls(data) {
    recentCalls = data.calls || [];
    recentSelfServerId = data.selfServerId;
    callsPanel.classList.remove('hidden');
    renderRecentCalls();
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
    if (data.action === 'callUpdated') {
        upsertCallCard(data, true);
        const index = recentCalls.findIndex(call => Number(call.id) === Number(data.call.id));
        if (index >= 0) recentCalls[index] = data.call;
        else recentCalls.unshift(data.call);
        if (!callsPanel.classList.contains('hidden')) renderRecentCalls();
    }
    if (data.action === 'openCalls') openCalls(data);
    if (data.action === 'closeCalls') callsPanel.classList.add('hidden');
    if (data.action === 'syncCalls' && Array.isArray(data.calls) && !callsPanel.classList.contains('hidden')) openCalls(data);
    if (data.action === 'setFocusState') setFocusState(data.focused);
    if (data.action === 'removeCall') removeCall(data.callId);
    if (data.action === 'clearCards') clearCards();
});
