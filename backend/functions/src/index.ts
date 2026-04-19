import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onRequest } from 'firebase-functions/v2/https';
import type { Request, Response } from 'express';

import { fitbitConfig, validateFitbitConfig } from './config/fitbit_config';
import {
  describeFirestorePersistenceError,
  readFirestorePersistenceReadinessIssue,
  readFirestoreRuntimeHealth,
} from './services/firestore_runtime';
import {
  FirestoreFitbitCallbackPersistence,
} from './services/firestore_fitbit_callback_persistence';
import {
  type FitbitCallbackFlowResult,
  type FitbitCallbackStatusResult,
  finalizeFitbitCallbackFlow,
} from './services/fitbit_callback_flow';
import {
  exchangeCodeForTokens,
  buildFitbitAuthorizationUrl,
  fetchFitbitDevices,
  fetchFitbitHealthMetrics,
  selectPrimaryFitbitDevice,
} from './services/fitbit_service';

initializeApp();

const firestore = getFirestore();
const fitbitCallbackPersistence = new FirestoreFitbitCallbackPersistence(
  firestore,
);

function sendConfigErrorResponse(response: Response): boolean {
  const missing = validateFitbitConfig();

  if (missing.length === 0) {
    return false;
  }

  response.status(500).json({
    ok: false,
    error: 'Fitbit backend configuration is incomplete.',
    missing,
  });

  return true;
}

function readAuthorizationBearer(request: Request): string | null {
  const authorizationHeader = request.get('authorization');

  if (authorizationHeader?.startsWith('Bearer ')) {
    return authorizationHeader.slice('Bearer '.length).trim();
  }

  return null;
}

function readStringValue(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalizedValue = value.trim();
  return normalizedValue.length === 0 ? null : normalizedValue;
}

function readJsonBody(request: Request): Record<string, unknown> {
  const body = request.body;

  if (typeof body === 'string') {
    try {
      const parsedBody = JSON.parse(body) as unknown;
      return typeof parsedBody === 'object' &&
        parsedBody != null &&
        !Array.isArray(parsedBody)
        ? (parsedBody as Record<string, unknown>)
        : {};
    } catch (_) {
      return {};
    }
  }

  return typeof body === 'object' && body != null && !Array.isArray(body)
    ? (body as Record<string, unknown>)
    : {};
}

function readAccessToken(request: Request): string | null {
  const authorizationToken = readAuthorizationBearer(request);

  if (authorizationToken != null) {
    return authorizationToken;
  }

  const queryToken = request.query.accessToken;

  if (typeof queryToken === 'string' && queryToken.trim().length > 0) {
    return queryToken.trim();
  }

  return null;
}

async function readAuthenticatedUserId(request: Request): Promise<string> {
  const idToken = readAuthorizationBearer(request);

  if (idToken == null) {
    throw new Error(
      'Missing Firebase ID token. Sign in before finalizing Fitbit connection.',
    );
  }

  const decodedToken = await getAuth().verifyIdToken(idToken);
  return decodedToken.uid;
}

function readFitbitCallbackCode(request: Request): string | null {
  const body = readJsonBody(request);

  return (
    readStringValue(request.query.code) ?? readStringValue(body.code) ?? null
  );
}

function readFitbitCallbackState(request: Request): string | null {
  const body = readJsonBody(request);

  return (
    readStringValue(request.query.state) ?? readStringValue(body.state) ?? null
  );
}

export const health = onRequest((request, response) => {
  const missingFitbitConfig = validateFitbitConfig();
  const firestoreRuntime = readFirestoreRuntimeHealth();

  response.json({
    ok: true,
    service: 'carebit-functions',
    method: request.method,
    fitbitConfigured: missingFitbitConfig.length === 0,
    fitbitMissingConfig: missingFitbitConfig,
    firestore: firestoreRuntime,
  });
});

export const fitbitAuthStart = onRequest((request, response) => {
  if (sendConfigErrorResponse(response)) {
    return;
  }

  if (sendFirestoreReadinessErrorResponse(response)) {
    return;
  }

  const state =
    typeof request.query.state === 'string' ? request.query.state : undefined;
  const mode = typeof request.query.mode === 'string' ? request.query.mode : '';
  const authUrl = buildFitbitAuthorizationUrl(state);

  if (mode.toLowerCase() === 'json') {
    response.json({
      ok: true,
      authUrl,
      redirectUri: fitbitConfig.redirectUri,
      scopes: fitbitConfig.scopes,
    });
    return;
  }

  response.redirect(authUrl);
});

export const fitbitAuthCallback = onRequest(async (request, response) => {
  if (sendConfigErrorResponse(response)) {
    return;
  }

  let userId: string;
  try {
    userId = await readAuthenticatedUserId(request);
  } catch (err) {
    response.status(401).json({
      ok: false,
      error:
        err instanceof Error
          ? err.message
          : 'Could not verify the Firebase user for Fitbit connection.',
    });
    return;
  }

  const error = request.query.error;
  if (typeof error === 'string') {
    response.status(400).json({
      ok: false,
      error,
      errorDescription:
        typeof request.query.error_description === 'string'
          ? request.query.error_description
          : null,
    });
    return;
  }

  const code = readFitbitCallbackCode(request);
  if (code == null) {
    response.status(400).json({
      ok: false,
      error: 'Missing Fitbit authorization code.',
    });
    return;
  }

  if (sendFirestoreReadinessErrorResponse(response)) {
    return;
  }

  let flowResult: FitbitCallbackFlowResult;
  try {
    flowResult = await finalizeFitbitCallbackFlow({
      code,
      fitbitApiClient: {
        exchangeCodeForTokens,
        fetchDevices: fetchFitbitDevices,
        selectPrimaryDevice: selectPrimaryFitbitDevice,
      },
      persistence: fitbitCallbackPersistence,
      state: readFitbitCallbackState(request),
      userId,
    });
  } catch (error) {
    logger.error('Fitbit callback persistence failed', {
      error: error instanceof Error ? error.message : String(error),
      firestore: readFirestoreRuntimeHealth(),
      userId,
    });
    sendFirestorePersistenceErrorResponse(response, error);
    return;
  }

  if (!flowResult.ok) {
    response.status(flowResult.statusCode).json({
      ok: false,
      error: flowResult.error,
    });
    return;
  }

  logger.info('Fitbit callback finalized', {
    callbackStateDocumentId: flowResult.callbackStateDocumentId,
    connectionDocumentId: userId,
    reused: flowResult.reused,
    userId,
    watchDataDocumentId: flowResult.device.documentId,
  });

  response.json({
    ok: true,
    reused: flowResult.reused,
    device: flowResult.device,
    documentIds: {
      callbackState: flowResult.callbackStateDocumentId,
      connection: userId,
      watchData: flowResult.device.documentId,
    },
  });
});

export const fitbitAuthCallbackStatus = onRequest(async (request, response) => {
  let userId: string;
  try {
    userId = await readAuthenticatedUserId(request);
  } catch (err) {
    response.status(401).json({
      ok: false,
      error:
        err instanceof Error
          ? err.message
          : 'Could not verify the Firebase user for Fitbit connection.',
    });
    return;
  }

  const state = readFitbitCallbackState(request);
  if (state == null) {
    response.status(400).json({
      ok: false,
      error: 'Missing Fitbit OAuth state. Start the connection again.',
    });
    return;
  }

  if (sendFirestoreReadinessErrorResponse(response)) {
    return;
  }

  let callbackStatus: FitbitCallbackStatusResult;
  try {
    callbackStatus = await fitbitCallbackPersistence.readCallbackStatus({
      state,
      userId,
    });
  } catch (error) {
    logger.error('Fitbit callback status lookup failed', {
      error: error instanceof Error ? error.message : String(error),
      firestore: readFirestoreRuntimeHealth(),
      userId,
    });
    sendFirestorePersistenceErrorResponse(response, error);
    return;
  }

  switch (callbackStatus.kind) {
    case 'not_found':
      response.json({
        ok: true,
        status: 'not_found',
        callbackStateDocumentId: callbackStatus.callbackStateDocumentId,
      });
      return;
    case 'processing':
      response.json({
        ok: true,
        status: 'processing',
        callbackStateDocumentId: callbackStatus.callbackStateDocumentId,
      });
      return;
    case 'failed':
      response.json({
        ok: true,
        status: 'failed',
        callbackStateDocumentId: callbackStatus.callbackStateDocumentId,
        error: callbackStatus.error,
      });
      return;
    case 'succeeded':
      response.json({
        ok: true,
        status: 'succeeded',
        callbackStateDocumentId: callbackStatus.callbackStateDocumentId,
        device: callbackStatus.device,
      });
      return;
  }
});

function sendFirestoreReadinessErrorResponse(response: Response): boolean {
  const issue = readFirestorePersistenceReadinessIssue();
  if (issue == null) {
    return false;
  }

  response.status(503).json({
    ok: false,
    error: issue,
    firestore: readFirestoreRuntimeHealth(),
  });
  return true;
}

function sendFirestorePersistenceErrorResponse(
  response: Response,
  error: unknown,
): void {
  response.status(503).json({
    ok: false,
    error: describeFirestorePersistenceError(error),
    firestore: readFirestoreRuntimeHealth(),
  });
}

export const fitbitDevices = onRequest(async (request, response) => {
  const accessToken = readAccessToken(request);

  if (accessToken == null) {
    response.status(400).json({
      ok: false,
      error:
        'Missing Fitbit access token. Pass it as Authorization: Bearer <token> or ?accessToken=<token>.',
    });
    return;
  }

  try {
    const devices = await fetchFitbitDevices(accessToken);
    response.json({
      ok: true,
      devices,
    });
  } catch (err) {
    response.status(500).json({
      ok: false,
      error: err instanceof Error ? err.message : 'Failed to fetch Fitbit devices.',
    });
  }
});

export const fitbitHealthMetrics = onRequest(async (request, response) => {
  const accessToken = readAccessToken(request);

  if (accessToken == null) {
    response.status(400).json({
      ok: false,
      error:
        'Missing Fitbit access token. Pass it as Authorization: Bearer <token> or ?accessToken=<token>.',
    });
    return;
  }

  try {
    const metrics = await fetchFitbitHealthMetrics(accessToken);
    response.json({
      ok: true,
      metrics,
    });
  } catch (err) {
    response.status(500).json({
      ok: false,
      error:
        err instanceof Error ? err.message : 'Failed to fetch Fitbit health metrics.',
    });
  }
});

export const fitbitMyMetrics = onRequest(async (request, response) => {
  // 1. Authenticate user via Firebase ID token
  let userId: string;
  try {
    userId = await readAuthenticatedUserId(request);
  } catch (err) {
    response.status(401).json({
      ok: false,
      error:
        err instanceof Error
          ? err.message
          : 'Could not verify your Firebase account.',
    });
    return;
  }

  // 2. Look up the stored Fitbit access token for this user
  const connectionDoc = await firestore
    .collection('fitbit_connections')
    .doc(userId)
    .get();

  if (!connectionDoc.exists) {
    response.status(404).json({
      ok: false,
      error: 'No Fitbit connection found for this user. Please connect your Fitbit first.',
    });
    return;
  }

  const connectionData = connectionDoc.data() ?? {};
  const accessToken = connectionData.accessToken as string | undefined;

  if (!accessToken) {
    response.status(400).json({
      ok: false,
      error: 'Fitbit access token missing from connection record.',
    });
    return;
  }

  // 3. Fetch live health metrics from Fitbit using the stored token
  try {
    const targetDateStr = typeof request.query.date === 'string' ? request.query.date : undefined;
    const metrics = await fetchFitbitHealthMetrics(accessToken, targetDateStr);
    logger.info('fitbitMyMetrics raw result', {
      profileKeys: metrics.profile ? Object.keys(metrics.profile as object) : null,
      heartRateKeys: metrics.heartRate ? Object.keys(metrics.heartRate as object) : null,
      heartRateHistoryKeys: metrics.heartRateHistory
        ? Object.keys(metrics.heartRateHistory as object)
        : null,
      heartRateIntradayKeys: metrics.heartRateIntraday
        ? Object.keys(metrics.heartRateIntraday as object)
        : null,
      sleepKeys: metrics.sleep ? Object.keys(metrics.sleep as object) : null,
      oxygenSaturationKeys: metrics.oxygenSaturation ? Object.keys(metrics.oxygenSaturation as object) : null,
      rawHeartRate: JSON.stringify(metrics.heartRate)?.slice(0, 500),
      rawHeartRateHistory: JSON.stringify(metrics.heartRateHistory)?.slice(0, 500),
      rawHeartRateIntraday: JSON.stringify(metrics.heartRateIntraday)?.slice(0, 500),
      rawSleep: JSON.stringify(metrics.sleep)?.slice(0, 500),
      rawSpO2: JSON.stringify(metrics.oxygenSaturation)?.slice(0, 300),
      errors: metrics.errors,
    });
    response.json({
      ok: true,
      metrics,
    });
  } catch (err) {
    response.status(500).json({
      ok: false,
      error: err instanceof Error ? err.message : 'Failed to fetch health metrics.',
    });
  }
});
