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
