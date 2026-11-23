import fs from 'node:fs/promises';
import path from 'node:path';
import { createReadStream } from 'node:fs';
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand
} from '@aws-sdk/client-s3';

const KEY_PATTERN = /^[a-f0-9-]{36}$/i;

function validateKey(key) {
  if (typeof key !== 'string' || !KEY_PATTERN.test(key)) {
    throw Object.assign(new Error('invalid_storage_key'), { status: 400 });
  }
  return key;
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
