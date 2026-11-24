import fs from 'node:fs/promises';
import path from 'node:path';
import { createReadStream } from 'node:fs';
import { Readable } from 'node:stream';
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand
} from '@aws-sdk/client-s3';

const KEY_PATTERN = /^[a-f0-9-]{36}$/i;
const RAPIDFILE_ID_PATTERN = /^[A-Za-z0-9_-]{6,80}$/;

function validateKey(key) {
  if (typeof key !== 'string' || !KEY_PATTERN.test(key)) {
    throw Object.assign(new Error('invalid_storage_key'), { status: 400 });
  }
  return key;
}

async function rapidfileJson(response) {
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw Object.assign(new Error('rapidfile_request_failed_' + response.status), { status: 502 });
  }
  return data;
}

export function createPrivateObjectStorage({ storageDir }) {
  const names = [
    'S3_ENDPOINT',
    'S3_REGION',
    'S3_BUCKET',
    'S3_ACCESS_KEY_ID',
    'S3_SECRET_ACCESS_KEY'
  ];
  const configured = names.filter((name) => Boolean(process.env[name]));
  const anyS3Setting = configured.length > 0;
  const rapidfileKey = process.env.RAPIDFILE_SECRET_KEY?.trim();

  if (rapidfileKey && anyS3Setting) {
    throw new Error('Configure only one private storage provider: Rapidfile or S3.');
  }

  if (rapidfileKey) {
    return {
      mode: 'rapidfile',
      async put(key, body, contentType) {
        validateKey(key);
        const url = new URL('https://api.rapidfile.cc/v1/files');
        url.searchParams.set('name', key);
        url.searchParams.set('acl', 'private');
        const response = await fetch(url, {
          method: 'PUT',
          headers: { Authorization: 'Bearer ' + rapidfileKey, 'Content-Type': contentType },
          body
        });
        const data = await rapidfileJson(response);
        if (!data.file?.id || data.file.acl !== 'private' || data.file.status !== 'ready') {
          throw Object.assign(new Error('rapidfile_private_upload_not_ready'), { status: 502 });
        }
        return data.file.id;
      },
      async get(fileId) {
        if (typeof fileId !== 'string' || !RAPIDFILE_ID_PATTERN.test(fileId)) {
          throw Object.assign(new Error('invalid_storage_key'), { status: 400 });
        }
        const signedResponse = await fetch('https://api.rapidfile.cc/v1/files/' + encodeURIComponent(fileId) + '/signed-url', {
          method: 'POST',
          headers: { Authorization: 'Bearer ' + rapidfileKey, 'Content-Type': 'application/json' },
          body: JSON.stringify({ expiresIn: 120 })
        });
        const signed = await rapidfileJson(signedResponse);
        if (typeof signed.url !== 'string' || !signed.url.startsWith('https://cdn.rapidfile.cc/')) {
          throw Object.assign(new Error('rapidfile_signed_url_unavailable'), { status: 502 });
        }
        const response = await fetch(signed.url);
        if (!response.ok || !response.body) {
          throw Object.assign(new Error('rapidfile_file_unavailable'), { status: response.status || 502 });
        }
        return Readable.fromWeb(response.body);
      },
      async delete(fileId) {
        if (typeof fileId !== 'string' || !RAPIDFILE_ID_PATTERN.test(fileId)) {
          throw Object.assign(new Error('invalid_storage_key'), { status: 400 });
        }
        const response = await fetch('https://api.rapidfile.cc/v1/files/' + encodeURIComponent(fileId), {
          method: 'DELETE',
          headers: { Authorization: 'Bearer ' + rapidfileKey }
        });
        await rapidfileJson(response);
      }
    };
  }


  if (anyS3Setting && configured.length !== names.length) {
    const missing = names.filter((name) => !process.env[name]);
    throw new Error(`Incomplete S3 configuration. Missing: ${missing.join(', ')}`);
  }

  if (anyS3Setting) {
    const client = new S3Client({
      endpoint: process.env.S3_ENDPOINT,
      region: process.env.S3_REGION,
      forcePathStyle: process.env.S3_FORCE_PATH_STYLE === 'true',
      credentials: {
        accessKeyId: process.env.S3_ACCESS_KEY_ID,
        secretAccessKey: process.env.S3_SECRET_ACCESS_KEY
      }
    });
    const bucket = process.env.S3_BUCKET;

    return {
      mode: 's3',
      async put(key, body, contentType) {
        validateKey(key);
        await client.send(new PutObjectCommand({
          Bucket: bucket,
          Key: key,
          Body: body,
          ContentType: contentType,
          // The bucket itself must remain private; no ACL/public URL is created.
        }));
        return key;
      },
      async get(key) {
        validateKey(key);
        const result = await client.send(new GetObjectCommand({
          Bucket: bucket,
          Key: key
        }));
        if (!result.Body) throw Object.assign(new Error('stored_file_body_missing'), { status: 404 });
        return result.Body;
      },
      async delete(key) {
        validateKey(key);
        await client.send(new DeleteObjectCommand({
          Bucket: bucket,
          Key: key
        }));
      }
    };
  }

  const root = path.resolve(storageDir);
  return {
    mode: 'local',
    async put(key, body) {
      validateKey(key);
      await fs.mkdir(root, { recursive: true, mode: 0o700 });
      await fs.writeFile(path.join(root, key), body, { flag: 'wx', mode: 0o600 });
      return key;
    },
    async get(key) {
      validateKey(key);
      return createReadStream(path.join(root, key));
    },
    async delete(key) {
      validateKey(key);
      await fs.rm(path.join(root, key), { force: true });
    }
  };
}
