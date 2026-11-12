const $ = selector => document.querySelector(selector);
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const bytes = value => value < 1024 ? `${value} B` : value < 1048576 ? `${(value / 1024).toFixed(1)} KiB` : `${(value / 1048576).toFixed(1)} MiB`;
const rules = mask => mask === 0 ? 'Public' : mask === 1 ? 'Private' : mask === 2 ? 'Approved region' : 'Private + region';
const reasons = { DESTINATION_POLICY: 'This destination is not approved for all of the file’s restrictions. No file contents were uploaded.',
  ORIGIN_RESTRICTION: 'An original source restriction prevents this transfer. No file contents were uploaded.',
  AUTHORITY_CHANGED: 'Access is no longer active. The transfer was refused.', READ_NOT_ALLOWED: 'Reading from this connection is disabled.',
  STALE_VERSION_OR_INVALID_FILE: 'The source or destination changed, or the path is unavailable. Refresh and review the current version.',
  PENDING_TRANSFER: 'A transfer is waiting for storage confirmation. Resolve it before making another change.',
  INVALID_CONNECTION_OR_PENDING: 'Finish the pending transfer before changing connection approvals.',
  CONTENT_MISMATCH: 'Stored bytes did not match the authorized file. The version remains unconfirmed.' };
let state = null, selected = null, connection = 0, tab = 'files', busy = 0;
const setup = new URLSearchParams(location.search);
const connName = id => state?.connections.find(c => c.id === id)?.name || `Storage ${id}`;
function notice(message, success = false) { $('#notice').textContent = message; $('#notice').className = success ? 'success' : ''; $('#notice').hidden = !message; }
async function api(path, body = {}, extra = {}) {
  const response = await fetch('/api/' + path, { method: 'POST', headers: { 'Content-Type': 'application/json', ...extra.headers }, body: extra.bytes || JSON.stringify(body) });
  const result = await response.json(); if (!response.ok) throw Error(reasons[result.code] || result.error || 'The operation could not finish.'); return result;
}
async function run(work, message = '') {
  busy++; document.body.classList.add('busy');
  try { const result = await work(); if (message) notice(message, true); await refresh(); return result; }
  catch (error) { notice(error.message); }
  finally { busy--; document.body.classList.remove('busy'); }
}
async function refresh() {
  const response = await fetch('/api/status');
  if (!response.ok) throw Error('Launch Writ again to open the private app session.');
  state = await response.json(); render();
}
function options(items, chosen = 0) { return items.map(c => `<option value="${c.id}" ${c.id === chosen ? 'selected' : ''}>${esc(c.name)} · ${rules(c.clearance)}</option>`).join(''); }
function switchTab(next) { tab = next; render(); }
function render() {
  $('#empty').hidden = !!state.connections.length; $('#workspace').hidden = !state.connections.length;
  $('#upload').disabled = !state.connections.length; $('#examples').disabled = !state.connections.some(c => c.enabled && c.configured);
  $('#heading').textContent = { files: 'Files', activity: 'Activity', storage: 'Storage' }[tab];
  for (const name of ['files', 'activity', 'storage']) { $(`#${name}-tab`).classList.toggle('active', tab === name); $(`#${name}-view`).hidden = tab !== name; }
  $('#connections').innerHTML = state.connections.map(c => `<button class="connection ${connection === c.id ? 'active' : ''}" data-connection="${c.id}">☁ <span>${esc(c.name)}</span>${c.enabled ? '' : 'Ⅱ'}</button>`).join('');
  $('#connections').querySelectorAll('button').forEach(button => button.onclick = () => { connection = Number(button.dataset.connection); tab = 'files'; selected = null; render(); });
  $('#sync-state').textContent = state.pending ? 'Waiting for confirmation' : state.problem ? 'Needs attention' : state.paused ? 'Syncing paused' : state.connections.length ? 'Watching your working folder' : 'Ready to connect';
  $('#pause').textContent = state.paused ? 'Resume syncing' : 'Pause syncing';
  $('#folder-path').textContent = state.folder; $('#file-count').textContent = state.files.length;
  $('#downloaded').textContent = bytes(state.fetched); $('#uploaded').textContent = bytes(state.sent);
  $('#pending').hidden = !state.pending;
  if (state.pending) { $('#pending').innerHTML = `<b>${esc(state.pending.path)}</b> — authorized, awaiting verified storage confirmation. <button id="retry">Retry / reconcile</button>`; $('#retry').onclick = () => run(() => api('retry'), 'Storage confirmation reconciled.'); }
  $('#folder-heading').textContent = connection ? connName(connection) : 'All files';
  $('#folder-caption').textContent = connection ? `Working folder: ${state.folder}/${connection}` : 'Select a file to inspect its rules, origin and history.';
  const files = state.files.filter(f => !connection || f.connection === connection);
  $('#no-files').hidden = !!files.length;
  $('#files').innerHTML = files.map(f => `<tr tabindex="0" data-version="${f.version}" class="${selected?.id === f.id ? 'selected' : ''}" aria-label="${esc(f.path)}"><td>▤ &nbsp; ${esc(f.path)}</td><td>${esc(connName(f.connection))}</td><td><span class="badge ${f.restrictions ? '' : 'public'}">${rules(f.restrictions)}</span></td><td>${esc(f.status)}</td><td>${bytes(f.size)}</td></tr>`).join('');
  $('#files').querySelectorAll('tr').forEach(row => { const choose = () => { selected = state.files.find(f => f.version === Number(row.dataset.version)); render(); }; row.onclick = choose; row.onkeydown = e => { if (e.key === 'Enter' || e.key === ' ') choose(); }; });
  if (selected) selected = state.files.find(f => f.id === selected.id) || selected;
  inspect();
  $('#activity').innerHTML = [...state.activity].reverse().map(item => `<article class="activity-item"><time>${esc(new Date(item.time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }))}</time><div><span class="badge ${['denied', 'attention'].includes(item.kind) ? 'warn' : ''}">${esc(item.kind)}</span></div><div><b>${esc(item.path || (item.destination ? connName(item.destination) : 'Workspace'))}</b><p>${esc(reasons[item.detail] || item.detail)}</p>${item.destination ? `<small>Destination: ${esc(connName(item.destination))}</small>` : ''}</div></article>`).join('') || '<p class="muted">Activity appears here as you use Writ.</p>';
  $('#storage-cards').innerHTML = state.connections.map(c => `<article class="storage-card"><h2>☁ ${esc(c.name)} ${c.id === 1 ? '<span class="badge">Workspace catalog</span>' : ''}</h2><p>${esc(c.endpoint)} · ${esc(c.bucket)}</p><div class="columns"><label>Approved to receive<select data-clearance="${c.id}"><option value="0" ${c.clearance === 0 ? 'selected' : ''}>Public files only</option><option value="1" ${c.clearance === 1 ? 'selected' : ''}>Private files</option><option value="3" ${c.clearance === 3 ? 'selected' : ''}>Private + approved region</option></select></label><button data-save="${c.id}">Save approvals</button><button data-toggle="${c.id}">${c.enabled ? 'Disable new transfers' : 'Enable transfers'}</button></div>${!c.configured ? '<p class="form-error">Credentials for this connection are needed on this device.</p><button data-credentials="${c.id}">Add credentials</button>' : ''}</article>`).join('');
  $('#storage-cards').querySelectorAll('[data-credentials]').forEach(b => b.onclick = () => { const c = state.connections.find(c => c.id === Number(b.dataset.credentials)); showConnection(); $('#connection-form [name=id]').value = c.id; $('#connection-form [name=name]').value = c.name; $('#connection-form [name=clearance]').value = c.clearance; });
  $('#storage-cards').querySelectorAll('[data-save]').forEach(b => b.onclick = () => run(() => api('configure', { id: Number(b.dataset.save), clearance: Number($(`[data-clearance="${b.dataset.save}"]`).value), enabled: state.connections.find(c => c.id === Number(b.dataset.save)).enabled }), 'Approvals saved. Existing file restrictions remain attached.'));
  $('#storage-cards').querySelectorAll('[data-toggle]').forEach(b => b.onclick = () => { const c = state.connections.find(c => c.id === Number(b.dataset.toggle)); run(() => api('configure', { id: c.id, clearance: c.clearance, enabled: !c.enabled }), c.enabled ? 'New managed transfers are disabled.' : 'Transfers enabled.'); });
}
function inspect() {
  $('#inspector').hidden = !selected; if (!selected) return;
  const f = selected, history = state.history.filter(h => h.id === f.id).reverse();
  $('#inspector').innerHTML = `<div class="eyebrow">FILE DETAILS</div><h2>${esc(f.path.split('/').pop())}</h2><p>${esc(connName(f.connection))} · version ${f.version} · ${bytes(f.size)}</p><button id="keep" class="primary">Open in desktop app ↗</button><button id="keep-local">Keep offline</button><button id="copy">Copy to storage…</button><h3>Rules attached</h3><span class="badge">${rules(f.restrictions)}</span><p>A copy keeps its original restrictions. A public destination must be approved for every restriction before any contents are sent.</p><select id="tighten"><option value="1">Add private restriction</option><option value="2">Add approved-region restriction</option><option value="3">Add both restrictions</option></select><button id="apply-rule">Add restriction</button><h3>Original sources</h3><div id="origins">Loading provenance…</div><h3>Verified content</h3><small>SHA-256 ${esc(f.digest)}</small><h3>Version history</h3>${history.map(h => `<div class="history-item"><b>Version ${h.version}</b> <small>${esc(h.kind)} · ${rules(h.restrictions)}</small><br><button data-history="${h.version}">Open separate copy</button>${h.version !== f.version ? `<button data-restore="${h.version}">Restore bytes</button>` : '<span class="badge">Current</span>'}</div>`).join('')}`;
  $('#keep').onclick = () => run(() => api('keep', { version: f.version, open: true }), 'Opened from your working folder. Save normally to sync edits.');
  $('#keep-local').onclick = () => run(() => api('keep', { version: f.version }), 'File is available in your working folder.');
  $('#copy').onclick = () => {
    $('#copy-destination').innerHTML = options(state.connections.filter(c => c.configured), f.connection);
    $('#copy-form [name=path]').value = f.path.replace(/(\.[^/.]+)?$/, '-copy$1');
    $('#copy-explanation').textContent = `${f.path} carries ${rules(f.restrictions).toLowerCase()} restrictions. Writ checks the destination before uploading and preserves its origin on the copy.`;
    $('#copy-form .form-error').textContent = ''; $('#copy-dialog').showModal();
  };
  $('#apply-rule').onclick = () => run(() => api('transfer', { connection: f.connection, path: f.path, source: f.version, expected: f.version, extra: Number($('#tighten').value), kind: 'restrict' }), 'Restriction added to the current version and retained in future copies.');
  $('#inspector').querySelectorAll('[data-history]').forEach(b => b.onclick = () => run(() => api('history', { version: Number(b.dataset.history) }), 'Historical bytes opened separately; current file retained.'));
  $('#inspector').querySelectorAll('[data-restore]').forEach(b => b.onclick = () => run(() => api('transfer', { connection: f.connection, path: f.path, source: Number(b.dataset.restore), expected: f.version, extra: 0, kind: 'restore' }), 'Historical bytes restored with all current restrictions retained.'));
  fetch('/api/provenance?version=' + f.version).then(r => r.json()).then(result => {
    if (selected?.version !== f.version) return;
    const origins = [...new Set(result.origins.trim().split('\n').filter(Boolean))];
    $('#origins').innerHTML = origins.map(line => { const [id, version, mask] = line.split(':'); const source = state.history.find(h => h.id === Number(id) - 100000 && h.version === Number(version)); return `<div class="origin">${source ? esc(source.path) + '<br>' + esc(connName(source.connection)) : 'Origin ' + esc(id)} · version ${esc(version)}<br><span class="muted">${rules(Number(mask))}</span></div>`; }).join('');
  }).catch(() => { if ($('#origins')) $('#origins').textContent = 'Provenance is temporarily unavailable.'; });
}
function showConnection() {
  $('#connection-form').reset(); $('#connection-form [name=id]').value = '';
  for (const name of ['name', 'endpoint', 'bucket', 'region']) if (setup.has(name)) $('#connection-form').elements[name].value = setup.get(name);
  $('#connection-form .form-error').textContent = ''; $('#connection-dialog').showModal();
}
for (const id of ['connect', 'first-connect']) $('#' + id).onclick = showConnection;
document.querySelectorAll('[data-close]').forEach(b => b.onclick = () => b.closest('dialog').close());
$('#connection-form').onsubmit = async event => {
  event.preventDefault(); const form = event.currentTarget, button = form.querySelector('[type=submit]'); button.disabled = true;
  const input = Object.fromEntries(new FormData(form)); input.clearance = Number(input.clearance); if (input.id) input.id = Number(input.id); else delete input.id;
  try { connection = await api('connect', input); form.reset(); $('#connection-dialog').close(); notice('Connected. Conditional storage writes verified.', true); await refresh(); }
  catch (error) { form.querySelector('.form-error').textContent = error.message; }
  finally { button.disabled = false; }
};
$('#copy-form').onsubmit = async event => {
  event.preventDefault(); const form = event.currentTarget, button = form.querySelector('[type=submit]'); button.disabled = true;
  try { await api('transfer', { connection: Number(form.elements.connection.value), path: form.elements.path.value, source: selected.version, expected: 0, extra: 0, kind: 'copy' }); $('#copy-dialog').close(); notice('Copy confirmed. Original restrictions and provenance were preserved.', true); await refresh(); }
  catch (error) { form.querySelector('.form-error').textContent = error.message; await refresh(); }
  finally { button.disabled = false; }
};
$('#files-tab').onclick = () => { connection = 0; switchTab('files'); }; $('#activity-tab').onclick = () => switchTab('activity'); $('#storage-tab').onclick = () => switchTab('storage');
$('#open-folder').onclick = () => run(() => api('open-folder'));
$('#recovery').onclick = () => run(() => api('open-folder', { recovery: true }));
$('#refresh').onclick = () => run(() => api('refresh'), 'Workspace refreshed.');
$('#pause').onclick = () => run(() => api('pause', { paused: !state.paused }));
$('#quit').onclick = () => run(async () => { await api('quit'); notice('Writ has stopped. Your downloaded files and recovery copies remain on this device.', true); });
$('#upload').onclick = () => $('#file-picker').click();
$('#file-picker').onchange = event => run(async () => {
  const destination = state.connections.find(c => c.id === connection) || state.connections.find(c => c.enabled && c.configured);
  if (!destination) throw Error('Choose a connected storage destination.');
  for (const file of event.target.files) {
    if (file.size > 67108864) throw Error('The current desktop preview supports files up to 64 MiB.');
    await api('upload', {}, { bytes: await file.arrayBuffer(), headers: { 'Content-Type': 'application/octet-stream', 'X-Writ-File': JSON.stringify({ connection: destination.id, path: file.name, extra: destination.clearance, expected: 0 }) } });
  }
  event.target.value = '';
}, 'Files uploaded and verified. Select one to inspect its rules.');
$('#examples').onclick = () => run(() => api('examples', { connection: connection || state.connections.find(c => c.enabled && c.configured)?.id }), 'Sample files were written to your storage. Try copying the private file to a public-only destination, then inspect Activity.');
$('#browse').onclick = () => { $('#import-storage').innerHTML = options(state.connections.filter(c => c.configured), connection); $('#import-results').textContent = ''; $('#import-dialog .form-error').textContent = ''; $('#import-dialog').showModal(); };
$('#import-list').onsubmit = async event => {
  event.preventDefault(); const id = Number($('#import-storage').value), prefix = $('#import-prefix').value;
  try {
    const result = await api('list-existing', { connection: id, prefix });
    $('#import-results').innerHTML = result.items.map((item, index) => `<div class="object-row"><span>${esc(item.key)}<br><small>${bytes(item.size)}</small></span><button data-import="${index}">Import</button></div>`).join('') + (result.continuation ? '<p class="muted">Showing the first 500 objects. Narrow the prefix to find more.</p>' : '');
    $('#import-results').querySelectorAll('[data-import]').forEach(b => b.onclick = async () => {
      b.disabled = true; const item = result.items[Number(b.dataset.import)];
      try { await api('import', { connection: id, key: item.key, etag: item.etag, path: item.key, extra: state.connections.find(c => c.id === id).clearance }); b.textContent = 'Imported'; await refresh(); }
      catch (error) { $('#import-dialog .form-error').textContent = error.message; b.disabled = false; }
    });
  } catch (error) { $('#import-dialog .form-error').textContent = error.message; }
};
try {
  const token = new URLSearchParams(location.hash.slice(1)).get('token');
  if (token) { await api('session', { token }); history.replaceState(null, '', '/'); }
  await refresh();
  if (setup.has('connect') && !state.connections.length) showConnection();
  setInterval(() => { if (!busy && !document.querySelector('dialog[open]') && !document.activeElement.matches('input, select, textarea')) refresh().catch(() => {}); }, 5000);
} catch (error) { notice(error.message); }
