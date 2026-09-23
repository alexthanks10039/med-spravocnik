import assert from 'node:assert/strict';
import { once } from 'node:events';
import test from 'node:test';

process.env.DATABASE_URL ??= 'postgresql://test:test@127.0.0.1:5432/test';
process.env.JWT_SECRET ??= 'test-secret-key';

const { app } = await import('../src/app.js');

const server = app.listen(0);
await once(server, 'listening');
const address = server.address();
if (!address || typeof address === 'string') {
  throw new Error('Test server did not expose a TCP address');
}
const baseUrl = `http://127.0.0.1:${address.port}`;

test.after(async () => {
  server.close();
  await once(server, 'close');
});

test('GET /api/health returns an operational status', async () => {
  const response = await fetch(`${baseUrl}/api/health`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    name: 'MED SPRAVOCHNIK',
    status: 'ok',
  });
});

test('invalid JSON body returns HTTP 400', async () => {
  const response = await fetch(baseUrl + '/api/calculators/bmi', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: '{"weightKg":70,',
  });
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { message: 'Invalid JSON body' });
});

test('GET /api/ready verifies database readiness', async () => {
  const response = await fetch(baseUrl + '/api/ready');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    name: 'MED SPRAVOCHNIK',
    status: 'ready',
  });
});

test('GET /api/rag filters the library by space and query', async () => {
  const response = await fetch(
    `${baseUrl}/api/rag?q=typescript&space=development`,
  );
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.ok(Array.isArray(body.items));
  assert.equal(body.items.length, 1);
  assert.equal(body.items[0].id, 'dev-stack');
});

test('GET /api/diseases returns lightweight catalog fields', async () => {
  const response = await fetch(baseUrl + '/api/diseases?limit=2');
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.length, 2);
  assert.ok(body[0].id);
  assert.ok(body[0].name);
  assert.ok('icd10' in body[0]);
  assert.equal('treatment' in body[0], false);
});

test('GET /api/drugs returns lightweight catalog fields', async () => {
  const response = await fetch(baseUrl + '/api/drugs?limit=2');
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.length, 2);
  assert.ok(body[0].id);
  assert.ok(body[0].name);
  assert.equal('dosage' in body[0], false);
});

test('GET /api/articles returns lightweight catalog fields', async () => {
  const response = await fetch(baseUrl + '/api/articles?limit=2');
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.length, 2);
  assert.ok(body[0].id);
  assert.ok(body[0].title);
  assert.equal('content' in body[0], false);
});

test('GET /api/content batches known materials in requested order', async () => {
  const response = await fetch(
    baseUrl + '/api/content?ids=seed-amoxicillin,seed-hypertension,missing-id',
  );
  assert.equal(response.status, 200);

  const body = await response.json();
  assert.deepEqual(
    body.map((item: { id: string; type: string }) => [item.id, item.type]),
    [
      ['seed-amoxicillin', 'drug'],
      ['seed-hypertension', 'disease'],
    ],
  );
});

test('POST /api/calculators/bmi calculates BMI', async () => {
  const response = await fetch(`${baseUrl}/api/calculators/bmi`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ weightKg: 70, heightCm: 175 }),
  });
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.value, 22.9);
  assert.equal(body.category, 'normal');
});

test('POST /api/calculators/egfr calculates CKD-EPI 2021', async () => {
  const response = await fetch(`${baseUrl}/api/calculators/egfr`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ age: 45, creatinine: 1, sex: 'female' }),
  });
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.formula, 'CKD-EPI 2021');
  assert.equal(body.value, 71);
});

test('calculator validation returns HTTP 400', async () => {
  const response = await fetch(`${baseUrl}/api/calculators/bmi`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ weightKg: 0, heightCm: 175 }),
  });
  assert.equal(response.status, 400);
});

test('Enterprise Data Store preserves MCP payloads and versions', async () => {
  const login = await fetch(baseUrl + '/api/auth/login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'admin@med.local', password: 'Admin123!' }),
  });
  assert.equal(login.status, 200);
  const { token } = await login.json() as { token: string };
  const headers = { 'content-type': 'application/json', authorization: 'Bearer ' + token };

  const collectionResponse = await fetch(baseUrl + '/api/data/collections', {
    method: 'POST',
    headers,
    body: JSON.stringify({ key: 'ci-mcp', name: 'CI MCP' }),
  });
  assert.equal(collectionResponse.status, 201);
  const collection = await collectionResponse.json() as { id: string };

  const firstPayload = {
    content: [{
      type: 'text',
      text: JSON.stringify({
        id: 'mcp-1',
        name: 'Гипертензия',
        nested: { values: [1, 2, 3] },
      }),
    }],
  };

  const importOne = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/import', {
    method: 'POST',
    headers,
    body: JSON.stringify({ filename: 'mcp.json', data: firstPayload }),
  });
  assert.equal(importOne.status, 201);
  const importOneBody = await importOne.json() as { imported: number; rejected: number };
  assert.equal(importOneBody.imported, 1);
  assert.equal(importOneBody.rejected, 0);

  const list = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/records', {
    headers: { authorization: 'Bearer ' + token },
  });
  assert.equal(list.status, 200);
  const listed = await list.json() as { items: Array<{ id: string; payload: Record<string, unknown>; version: number }> };
  assert.equal(listed.total, 1);
  assert.deepEqual(listed.items[0].payload, {
    id: 'mcp-1',
    name: 'Гипертензия',
    nested: { values: [1, 2, 3] },
  });
  assert.equal(listed.items[0].version, 1);

  const repeatImport = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/import', {
    method: 'POST',
    headers,
    body: JSON.stringify({ filename: 'mcp.json', data: firstPayload }),
  });
  assert.equal(repeatImport.status, 201);
  const repeatDetail = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/records/' + listed.items[0].id, {
    headers: { authorization: 'Bearer ' + token },
  });
  const repeatCurrent = await repeatDetail.json() as { version: number };
  assert.equal(repeatCurrent.version, 1);

  const secondPayload = {
    data: [{
      id: 'mcp-1',
      name: 'Гипертензия обновлена',
      nested: { values: [4, 5] },
    }],
  };
  const importTwo = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/import', {
    method: 'POST',
    headers,
    body: JSON.stringify(secondPayload),
  });
  assert.equal(importTwo.status, 201);

  const detail = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/records/' + listed.items[0].id, {
    headers: { authorization: 'Bearer ' + token },
  });
  const current = await detail.json() as { payload: Record<string, unknown>; version: number };
  assert.equal(current.version, 2);
  assert.equal((current.payload.name as string), 'Гипертензия обновлена');

  const versionsResponse = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/records/' + listed.items[0].id + '/versions', {
    headers: { authorization: 'Bearer ' + token },
  });
  assert.equal(versionsResponse.status, 200);
  const versions = await versionsResponse.json() as { currentVersion: number; items: Array<{ version: number; payload: Record<string, unknown> }> };
  assert.equal(versions.currentVersion, 2);
  assert.equal(versions.items.some((item) => item.version === 1), true);

  const rollback = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/records/' + listed.items[0].id + '/rollback/1', {
    method: 'POST',
    headers,
  });
  assert.equal(rollback.status, 200);
  const rolledBack = await rollback.json() as { payload: Record<string, unknown>; version: number };
  assert.equal(rolledBack.version, 3);
  assert.equal((rolledBack.payload.name as string), 'Гипертензия');

  const status = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/records/bulk-status', {
    method: 'POST',
    headers,
    body: JSON.stringify({ ids: [listed.items[0].id], status: 'ARCHIVED' }),
  });
  assert.equal(status.status, 200);

  const archived = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/records?status=ARCHIVED', {
    headers: { authorization: 'Bearer ' + token },
  });
  const archivedBody = await archived.json() as { total: number };
  assert.equal(archivedBody.total, 1);

  const unauthorized = await fetch(baseUrl + '/api/data/collections');
  assert.equal(unauthorized.status, 401);

  const exported = await fetch(baseUrl + '/api/data/collections/' + collection.id + '/export?format=envelope', {
    headers: { authorization: 'Bearer ' + token },
  });
  assert.equal(exported.status, 200);
  const envelope = await exported.json() as { type: string; count: number; items: unknown[] };
  assert.equal(envelope.type, 'collection');
  assert.equal(envelope.count, 0);
  assert.deepEqual(envelope.items, []);
});
