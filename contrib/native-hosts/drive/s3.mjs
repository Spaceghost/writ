// Native S3 HTTP/crypto effects. Writ authorization and publication state are
// supplied by Bend; this module cannot construct an admitted write intent.
import { createHash, createHmac, randomBytes } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { open } from 'node:fs/promises';
import { request as httpRequest } from 'node:http';
import { request as httpsRequest } from 'node:https';

export const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const hmac = (key, value) => createHmac('sha256', key).update(value).digest();
const encode = value => encodeURIComponent(value).replace(/[!'()*]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase());
const safeEtag = value => typeof value === 'string' && /^"[A-Za-z0-9-]{1,160}"$/.test(value);
const reportedErrors = new Set(['AccessDenied', 'SignatureDoesNotMatch', 'InvalidAccessKeyId',
  'NoSuchBucket', 'NoSuchKey', 'PreconditionFailed', 'ConditionalRequestConflict',
  'InternalError', 'SlowDown', 'RequestTimeTooSkewed', 'ExpiredToken', 'InvalidToken',
  'AuthorizationHeaderMalformed', 'InvalidArgument', 'NotImplemented', 'ServiceUnavailable']);

export class StorageError extends Error {
  constructor(status, code, uncertain = false) {
    super(status ? `Storage returned ${status} (${code}).` : 'Storage request did not complete.');
    this.status = status; this.code = code; this.uncertain = uncertain;
  }
}

export function validateConnection(input) {
  const endpoint = new URL(input.endpoint);
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(endpoint.hostname);
  if (endpoint.protocol !== 'https:' && !(endpoint.protocol === 'http:' && local))
    throw Error('Use HTTPS for your S3 endpoint. HTTP is allowed only on this computer.');
  if (endpoint.username || endpoint.password || endpoint.search || endpoint.hash)
    throw Error('The endpoint must not contain credentials, a query or a fragment.');
  if (!/^[A-Za-z0-9][A-Za-z0-9.-]{1,61}[A-Za-z0-9]$/.test(input.bucket))
    throw Error('Enter a valid bucket name.');
  if (!/^[A-Za-z0-9-]{1,80}$/.test(input.region)) throw Error('Enter an S3 region, or auto if your provider requires it.');
  if (!/^[A-Za-z0-9/_-]{1,160}$/.test(input.prefix) || input.prefix.startsWith('/') || input.prefix.includes('//'))
    throw Error('Use a relative workspace prefix containing letters, digits, slashes, dashes or underscores.');
  if (typeof input.accessKey !== 'string' || input.accessKey.length < 3 || input.accessKey.length > 256 ||
      typeof input.secretKey !== 'string' || input.secretKey.length < 8 || input.secretKey.length > 512 ||
      /[\r\n]/.test(input.accessKey + input.secretKey + (input.sessionToken || '')))
    throw Error('Enter the access key and secret key for this connection.');
  if (input.sessionToken && (typeof input.sessionToken !== 'string' || input.sessionToken.length > 8192))
    throw Error('The session token is too long.');
  return { endpoint: endpoint.href.replace(/\/$/, ''), bucket: input.bucket,
    region: input.region, prefix: input.prefix.replace(/\/+$/, ''),
    accessKey: input.accessKey, secretKey: input.secretKey, sessionToken: input.sessionToken || '' };
}

export function sign(connection, method, key, query, headers, bodyHash, now = new Date()) {
  const endpoint = new URL(connection.endpoint);
  const path = endpoint.pathname.replace(/\/$/, '') + '/' + encode(connection.bucket) +
    (key ? '/' + key.split('/').map(encode).join('/') : '');
  const search = Object.entries(query).map(([k, v]) => [encode(k), encode(String(v))])
    .sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0)
    .map(([k, v]) => k + '=' + v).join('&');
  const date = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
  const signed = { ...headers, host: endpoint.host, 'x-amz-date': date, 'x-amz-content-sha256': bodyHash };
  if (connection.sessionToken) signed['x-amz-security-token'] = connection.sessionToken;
  const names = Object.keys(signed).sort();
  const canonicalHeaders = names.map(name => name + ':' + String(signed[name]).trim().replace(/\s+/g, ' ') + '\n').join('');
  const canonical = [method, path, search, canonicalHeaders, names.join(';'), bodyHash].join('\n');
  const scope = `${date.slice(0, 8)}/${connection.region}/s3/aws4_request`;
  const signingKey = hmac(hmac(hmac(hmac('AWS4' + connection.secretKey, date.slice(0, 8)), connection.region), 's3'), 'aws4_request');
  const signature = hmac(signingKey, ['AWS4-HMAC-SHA256', date, scope, sha256(canonical)].join('\n')).toString('hex');
  signed.authorization = `AWS4-HMAC-SHA256 Credential=${connection.accessKey}/${scope}, SignedHeaders=${names.join(';')}, Signature=${signature}`;
  return { endpoint, path: path + (search ? '?' + search : ''), headers: signed };
}

function xml(text, tag) {
  const match = new RegExp('<' + tag + '>([\\s\\S]*?)</' + tag + '>').exec(text);
  if (!match) return '';
  return match[1].replace(/&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);/g, (_, code) => {
    if (code.startsWith('#')) {
      const n = code.startsWith('#x') ? parseInt(code.slice(2), 16) : Number(code.slice(1));
      if (!Number.isInteger(n) || n < 1 || n > 0x10ffff || (n >= 0xd800 && n <= 0xdfff)) throw Error('Invalid storage XML character.');
      return String.fromCodePoint(n);
    }
    return { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" }[code];
  });
}

export class S3 {
  constructor(connection) { this.connection = validateConnection(connection); }
  key(relative) { return this.connection.prefix + '/' + relative; }

  async request(method, key = '', { query = {}, headers = {}, body = Buffer.alloc(0), file,
    hash, size, maxBytes = 8 * 1024 * 1024, output, timeout = 120000 } = {}) {
    if (!file) { size = body.length; hash = sha256(body); }
    if (method === 'PUT' || method === 'POST') headers = { ...headers, 'content-length': String(size) };
    const signed = sign(this.connection, method, key, query, headers, hash || sha256(''));
    const transport = signed.endpoint.protocol === 'https:' ? httpsRequest : httpRequest;
    const response = await new Promise((resolve, reject) => {
      const req = transport(signed.endpoint, { method, path: signed.path, headers: signed.headers,
        timeout, maxHeaderSize: 32768 }, resolve);
      req.on('timeout', () => req.destroy());
      req.on('error', () => reject(new StorageError(0, 'CONNECTION', method === 'PUT')));
      const deadline = setTimeout(() => req.destroy(), timeout); deadline.unref();
      req.on('close', () => clearTimeout(deadline));
      if (file) {
        const source = createReadStream(file);
        source.on('error', () => req.destroy()); req.on('close', () => source.destroy()); source.pipe(req);
      } else req.end(body);
    });
    const accepted = response.statusCode >= 200 && response.statusCode < 300;
    const chunks = []; let count = 0, handle;
    const digest = createHash('sha256');
    try {
      if (accepted && output) handle = await open(output, 'wx', 0o600);
      for await (const chunk of response) {
        count += chunk.length;
        if (count > (accepted ? maxBytes : 65536)) { response.destroy(); throw new StorageError(0, 'RESPONSE_BOUND', method === 'PUT'); }
        if (handle) {
          let offset = 0;
          while (offset < chunk.length) {
            const { bytesWritten } = await handle.write(chunk, offset, chunk.length - offset);
            if (!bytesWritten) throw Error('Incomplete local write.');
            offset += bytesWritten;
          }
          digest.update(chunk);
        }
        else chunks.push(chunk);
      }
      if (!accepted) {
        const code = xml(Buffer.concat(chunks).toString('utf8'), 'Code');
        throw new StorageError(response.statusCode, reportedErrors.has(code) ? code : 'REQUEST_FAILED');
      }
      if (handle) await handle.sync();
      return { status: response.statusCode, headers: response.headers, bytes: count,
        body: handle ? null : Buffer.concat(chunks), sha256: handle ? digest.digest('hex') : undefined };
    } catch (error) {
      if (error instanceof StorageError) throw error;
      throw new StorageError(0, 'INCOMPLETE_RESPONSE', method === 'PUT');
    } finally { if (handle) await handle.close(); }
  }

  async get(key, options = {}) { return this.request('GET', key, options); }
  async put(key, body, condition = {}) { return this.request('PUT', key, { body, headers: condition }); }
  async putFile(key, file, size, hash) { return this.request('PUT', key, { file, size, hash, headers: { 'x-amz-meta-writ-sha256': hash } }); }
  async remove(key) { return this.request('DELETE', key); }

  async catalog() {
    try {
      const result = await this.get(this.key('catalog.json'));
      if (!safeEtag(result.headers.etag)) throw Error('Storage did not provide a usable catalog ETag.');
      return { etag: result.headers.etag, bytes: result.body };
    } catch (error) { if (error.status === 404) return { etag: '', bytes: null }; throw error; }
  }

  async replaceCatalog(bytes, expected) {
    if (expected && !safeEtag(expected)) throw Error('Invalid expected catalog ETag.');
    const response = await this.put(this.key('catalog.json'), bytes,
      expected ? { 'if-match': expected } : { 'if-none-match': '*' });
    if (!safeEtag(response.headers.etag)) throw new StorageError(0, 'MISSING_ETAG', true);
    return response.headers.etag;
  }

  async probeConditions() {
    // Only this fresh, random probe key is modified or removed. Never probe a
    // user's existing object, and never downgrade to unconditional overwrite.
    const key = this.key('probes/' + randomBytes(24).toString('hex'));
    const first = Buffer.from('writ condition probe 1'), second = Buffer.from('writ condition probe 2');
    let created = false;
    try {
      const initial = await this.put(key, first, { 'if-none-match': '*' }); created = true;
      if (!safeEtag(initial.headers.etag)) throw Error('Storage needs strong object ETags.');
      for (const condition of [{ 'if-none-match': '*' }, { 'if-match': '"writ-stale-etag"' }]) {
        try { await this.put(key, second, condition); }
        catch (error) { if (error.status === 412) continue; throw error; }
        throw Error('This endpoint does not enforce the conditional writes Writ requires.');
      }
      const race = await Promise.allSettled([
        this.put(key, second, { 'if-match': initial.headers.etag }),
        this.put(key, Buffer.from('writ condition probe 3'), { 'if-match': initial.headers.etag })]);
      if (race.filter(r => r.status === 'fulfilled').length !== 1 ||
          race.filter(r => r.status === 'rejected' && [409, 412].includes(r.reason.status)).length !== 1)
        throw Error('This endpoint did not serialize competing conditional writes.');
      return true;
    } finally { if (created) await this.remove(key).catch(() => {}); }
  }

  async list(prefix, continuation = '') {
    const query = { 'list-type': '2', 'max-keys': '500', prefix };
    if (continuation) query['continuation-token'] = continuation;
    const result = await this.request('GET', '', { query, maxBytes: 2 * 1024 * 1024 });
    const text = result.body.toString('utf8');
    if (text.includes('<!DOCTYPE') || text.includes('<!ENTITY')) throw Error('Unsupported storage XML.');
    const items = [...text.matchAll(/<Contents>([\s\S]*?)<\/Contents>/g)].map(match => {
      const size = Number(xml(match[1], 'Size')), key = xml(match[1], 'Key'), etag = xml(match[1], 'ETag');
      if (!Number.isSafeInteger(size) || size < 0 || key.length > 2048 || !safeEtag(etag))
        throw Error('Invalid storage listing.');
      return { key, size, etag, modified: xml(match[1], 'LastModified') };
    });
    if (items.length > 500) throw Error('Storage listing exceeded its page bound.');
    return { items, continuation: xml(text, 'NextContinuationToken') };
  }
}
