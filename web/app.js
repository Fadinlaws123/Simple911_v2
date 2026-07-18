const toastStack = document.getElementById('toastStack');
const alertStack = document.getElementById('alertStack');
const callsPanel = document.getElementById('callsPanel');
const callsList = document.getElementById('callsList');
const callStates = new Map();
let focused = false;

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

function renderAlertCard(callId) {
    const state = callStates.get(Number(callId));
    if (!state || !state.element) return;

    const { call, data, status, element } = state;
    const isEnroute = status === 'enroute';

    element.className = `call-alert${isEnroute ? ' enroute' : ''}`;
    element.innerHTML = `
        <div class="alert-accent"></div>
        <div class="alert-body">
            <div class="alert-top">
                <div>
                    <span class="eyebrow">${isEnroute ? 'Active 911 Callout' : 'Incoming 911 Call'}</span>
                    <h3>${isEnroute ? 'En Route' : `Call #${call.id}`}</h3>
                </div>
                <span class="status-pill ${isEnroute ? 'status-enroute' : 'status-new'}">${isEnroute ? 'EN ROUTE' : 'NEW'}</span>
            </div>
            <div class="alert-location">${escapeHtml(call.location)}</div>
            <p>${escapeHtml(call.message)}</p>
            ${(data.showCallerName || data.showCallerServerId) ? `<div class="alert-caller">${data.showCallerName ? escapeHtml(call.callerName) : ''}${data.showCallerServerId ? ` · ID ${call.callerId}` : ''}</div>` : ''}
            <div class="alert-actions">
                ${isEnroute
                    ? `<button class="close-callout-button">Close Callout</button>`
                    : `<button class="respond-button">Respond & Set Waypoint</button>`}
                <span>${focused ? 'Interaction enabled' : `Press ${escapeHtml(data.focusKey || 'F6')} to interact`}</span>
            </div>
        </div>`;

    const respondButton = element.querySelector('.respond-button');
    if (respondButton) {
        respondButton.addEventListener('click', () => {
            if (!focused) return;
            post('respondCall', { callId: call.id });
        });
    }

    const closeButton = element.querySelector('.close-callout-button');
    if (closeButton) {
        closeButton.addEventListener('click', () => {
            if (!focused) return;
            post('closeCallout', { callId: call.id });
        });
    }
}

function showCallAlert(data) {
    const call = data.call;
    const element = document.createElement('article');
    alertStack.prepend(element);

    callStates.set(Number(call.id), {
        call,
        data,
        element,
        status: data.responding ? 'enroute' : 'new'
    });

    renderAlertCard(call.id);

    const duration = Number(data.duration) || 12000;
    if (!data.responding) {
        setTimeout(() => {
            const state = callStates.get(Number(call.id));
            if (state && state.status === 'new' && state.element?.isConnected) {
                state.element.remove();
                callStates.delete(Number(call.id));
            }
        }, duration);
    }
}

function setFocusState(value) {
    focused = Boolean(value);
    callStates.forEach((_, callId) => renderAlertCard(callId));
}

function updateCallStatus(callId, status) {
    const state = callStates.get(Number(callId));
    if (!state) return;
    state.status = status;
    renderAlertCard(callId);
}

function removeCall(callId) {
    const state = callStates.get(Number(callId));
    if (state?.element) state.element.remove();
    callStates.delete(Number(callId));
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
    if (event.key === 'Escape') {
        if (!callsPanel.classList.contains('hidden')) post('close');
        else if (focused) post('releaseFocus');
    }
});

window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'toast') toast(data.message, data.kind);
    if (data.action === 'newCall') showCallAlert(data);
    if (data.action === 'openCalls') openCalls(data);
    if (data.action === 'closeCalls') callsPanel.classList.add('hidden');
    if (data.action === 'syncCalls' && Array.isArray(data.calls) && !callsPanel.classList.contains('hidden')) openCalls(data);
    if (data.action === 'setFocusState') setFocusState(data.focused);
    if (data.action === 'callStatusChanged') updateCallStatus(data.callId, data.status);
    if (data.action === 'removeCall') removeCall(data.callId);
});
