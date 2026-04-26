import { initializeApp } from 'firebase-admin/app';
import { getAuth, type UserRecord } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onRequest } from 'firebase-functions/v2/https';
import type { Request, Response } from 'express';
import nodemailer from 'nodemailer';
import { createHash, randomBytes } from 'crypto';

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
const usersCollection = 'users';
const communityGroupsCollection = 'community_groups';
const communityMembershipsCollection = 'community_memberships';
const communityInvitesCollection = 'community_invites';

const communityInviteEmailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

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

function readStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((entry) => readStringValue(entry))
    .filter((entry): entry is string => entry != null);
}

function normalizeEmail(value: unknown): string | null {
  const email = readStringValue(value)?.toLowerCase();
  if (email == null || !communityInviteEmailRegex.test(email)) {
    return null;
  }

  return email;
}

function emailDisplayFallback(email: string): string {
  const localPart = email.split('@')[0]?.trim();
  return localPart != null && localPart.length > 0 ? localPart : email;
}

function buildCommunityMembershipDocumentId(groupId: string, userId: string): string {
  return `${groupId}_${userId}`;
}

function hashCommunityInviteToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function buildCommunityInviteLink(inviteId: string, token: string): string {
  const searchParams = new URLSearchParams({
    inviteId,
    token,
  });
  return `carebit://community-invite?${searchParams.toString()}`;
}

function readTimestampIso(value: unknown): string | null {
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }

  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : new Date(parsed).toISOString();
  }

  return null;
}

function isInviteExpired(expiresAt: unknown): boolean {
  const iso = readTimestampIso(expiresAt);
  if (iso == null) {
    return true;
  }

  return Date.parse(iso) <= Date.now();
}

function readInviteId(request: Request): string | null {
  const body = readJsonBody(request);
  return readStringValue(request.query.inviteId) ?? readStringValue(body.inviteId);
}

function readInviteToken(request: Request): string | null {
  const body = readJsonBody(request);
  return readStringValue(request.query.token) ?? readStringValue(body.token);
}

function readCommunityGroupId(request: Request): string | null {
  const body = readJsonBody(request);
  return readStringValue(request.query.groupId) ?? readStringValue(body.groupId);
}

function readCommunityInviteEmail(request: Request): string | null {
  const body = readJsonBody(request);
  return normalizeEmail(body.email);
}

function buildUserProfilePayload(args: {
  displayName: string;
  email: string;
  photoURL: string | null;
}): Record<string, unknown> {
  return {
    displayName:
      args.displayName.trim().length > 0
        ? args.displayName.trim()
        : emailDisplayFallback(args.email),
    email: args.email,
    emailLower: args.email.toLowerCase(),
    photoURL: args.photoURL,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function upsertCommunityUserProfile(args: {
  userId: string;
  displayName: string;
  email: string;
  photoURL: string | null;
}): Promise<void> {
  const userReference = firestore.collection(usersCollection).doc(args.userId);
  const snapshot = await userReference.get();
  const payload = buildUserProfilePayload(args);

  if (!snapshot.exists) {
    payload.createdAt = FieldValue.serverTimestamp();
    payload.groupIds = [];
  }

  await userReference.set(payload, { merge: true });
}

async function ensureCommunityGroupForInviter(args: {
  userId: string;
  displayName: string;
  email: string;
  photoURL: string | null;
}): Promise<{ groupId: string; groupName: string }> {
  const groupsReference = firestore.collection(communityGroupsCollection).doc();
  const userReference = firestore.collection(usersCollection).doc(args.userId);
  const membershipReference = firestore
    .collection(communityMembershipsCollection)
    .doc(buildCommunityMembershipDocumentId(groupsReference.id, args.userId));
  const defaultGroupName =
    args.displayName.trim().length > 0
      ? `${args.displayName.trim()}'s Care Circle`
      : `${emailDisplayFallback(args.email)}'s Care Circle`;
  let resolvedGroupId = groupsReference.id;
  let resolvedGroupName = defaultGroupName;

  await firestore.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userReference);
    const existingGroups = readStringList(userSnapshot.data()?.groupIds);
    if (existingGroups.length > 0) {
      resolvedGroupId = existingGroups[0];
      return;
    }

    transaction.set(groupsReference, {
      name: defaultGroupName,
      ownerUid: args.userId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(membershipReference, {
      groupId: groupsReference.id,
      uid: args.userId,
      displayNameSnapshot:
        args.displayName.trim().length > 0
          ? args.displayName.trim()
          : emailDisplayFallback(args.email),
      emailLower: args.email.toLowerCase(),
      role: 'owner',
      joinedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(
      userReference,
      {
        ...buildUserProfilePayload({
          displayName: args.displayName,
          email: args.email,
          photoURL: args.photoURL,
        }),
        groupIds: FieldValue.arrayUnion(groupsReference.id),
        createdAt: userSnapshot.exists
          ? userSnapshot.data()?.createdAt ?? FieldValue.serverTimestamp()
          : FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  if (resolvedGroupId != groupsReference.id) {
    const existingGroupSnapshot = await firestore
      .collection(communityGroupsCollection)
      .doc(resolvedGroupId)
      .get();
    resolvedGroupName =
      readStringValue(existingGroupSnapshot.data()?.name) ?? defaultGroupName;
  }

  return {
    groupId: resolvedGroupId,
    groupName: resolvedGroupName,
  };
}

async function resolveCommunityInviteGroup(args: {
  requestedGroupId: string | null;
  userId: string;
}): Promise<{ groupId: string; groupName: string }> {
  const authUser = await getAuth().getUser(args.userId);
  const email = normalizeEmail(authUser.email);
  if (email == null) {
    throw new Error('Your Firebase account does not have a valid email address.');
  }

  await upsertCommunityUserProfile({
    userId: authUser.uid,
    displayName: authUser.displayName ?? '',
    email,
    photoURL: authUser.photoURL ?? null,
  });

  const userSnapshot = await firestore.collection(usersCollection).doc(args.userId).get();
  const groupIds = readStringList(userSnapshot.data()?.groupIds);

  if (groupIds.length === 0) {
    const createdGroup = await ensureCommunityGroupForInviter({
      userId: authUser.uid,
      displayName: authUser.displayName ?? '',
      email,
      photoURL: authUser.photoURL ?? null,
    });
    return createdGroup;
  }

  const requestedGroupId = args.requestedGroupId;
  if (requestedGroupId != null) {
    if (!groupIds.includes(requestedGroupId)) {
      throw new Error('You can only invite members into a community group you belong to.');
    }

    const groupSnapshot = await firestore
      .collection(communityGroupsCollection)
      .doc(requestedGroupId)
      .get();

    return {
      groupId: requestedGroupId,
      groupName:
        readStringValue(groupSnapshot.data()?.name) ?? 'Care Circle',
    };
  }

  if (groupIds.length > 1) {
    throw new Error('You belong to multiple community groups. Choose a group before sending the invite.');
  }

  const groupSnapshot = await firestore
    .collection(communityGroupsCollection)
    .doc(groupIds[0])
    .get();
  return {
    groupId: groupIds[0],
    groupName: readStringValue(groupSnapshot.data()?.name) ?? 'Care Circle',
  };
}

async function sendCommunityInviteEmail(args: {
  email: string;
  groupName: string;
  inviteLink: string;
  inviterName: string;
  expiresAt: Date;
}): Promise<void> {
  const host = readStringValue(process.env.INVITE_EMAIL_HOST);
  const port = Number.parseInt(process.env.INVITE_EMAIL_PORT ?? '', 10);
  const secure = (process.env.INVITE_EMAIL_SECURE ?? 'false').toLowerCase() === 'true';
  const username = readStringValue(process.env.INVITE_EMAIL_USERNAME);
  const password = readStringValue(process.env.INVITE_EMAIL_PASSWORD);
  const from = readStringValue(process.env.INVITE_EMAIL_FROM);

  if (
    host == null ||
    !Number.isFinite(port) ||
    username == null ||
    password == null ||
    from == null
  ) {
    throw new Error('Invite email configuration is incomplete.');
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: {
      user: username,
      pass: password,
    },
  });
  const expiry = args.expiresAt.toLocaleString('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });

  await transporter.sendMail({
    from,
    to: args.email,
    subject: `${args.inviterName} invited you to join ${args.groupName} on Carebit`,
    text: [
      `${args.inviterName} invited you to join ${args.groupName} on Carebit.`,
      '',
      `Open this link on your phone to accept the invitation: ${args.inviteLink}`,
      '',
      `This invitation expires on ${expiry}.`,
    ].join('\n'),
    html: [
      `<p>${args.inviterName} invited you to join <strong>${args.groupName}</strong> on Carebit.</p>`,
      `<p><a href="${args.inviteLink}">Accept community invitation</a></p>`,
      `<p>This invitation expires on ${expiry}.</p>`,
    ].join(''),
  });
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

export const createCommunityInvite = onRequest(async (request, response) => {
  let inviterUserId: string;
  try {
    inviterUserId = await readAuthenticatedUserId(request);
  } catch (error) {
    response.status(401).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : 'Could not verify your Firebase account.',
    });
    return;
  }

  if (sendFirestoreReadinessErrorResponse(response)) {
    return;
  }

  const invitedEmail = readCommunityInviteEmail(request);
  if (invitedEmail == null) {
    response.status(400).json({
      ok: false,
      error: 'Please enter a valid email address.',
    });
    return;
  }

  let invitedAuthUser: UserRecord;
  let inviterAuthUser: UserRecord;
  try {
    invitedAuthUser = await getAuth().getUserByEmail(invitedEmail);
    inviterAuthUser = await getAuth().getUser(inviterUserId);
  } catch (error) {
    const code =
      typeof error === 'object' &&
      error != null &&
      'code' in error &&
      typeof error.code === 'string'
        ? error.code
        : '';

    if (code === 'auth/user-not-found') {
      response.status(404).json({
        ok: false,
        error: 'That email address does not have an active Carebit account yet.',
      });
      return;
    }

    response.status(500).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : 'Could not verify the invited account.',
    });
    return;
  }

  if (invitedAuthUser.uid === inviterAuthUser.uid) {
    response.status(400).json({
      ok: false,
      error: 'You cannot invite your own account.',
    });
    return;
  }

  const inviterEmail = normalizeEmail(inviterAuthUser.email);
  if (inviterEmail == null) {
    response.status(400).json({
      ok: false,
      error: 'Your signed-in account must have a valid email address before sending invites.',
    });
    return;
  }

  const requestedGroupId = readCommunityGroupId(request);
  let resolvedGroup: { groupId: string; groupName: string };
  try {
    resolvedGroup = await resolveCommunityInviteGroup({
      requestedGroupId,
      userId: inviterUserId,
    });
  } catch (error) {
    response.status(400).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : 'Could not resolve the community group for this invitation.',
    });
    return;
  }

  const membershipSnapshot = await firestore
    .collection(communityMembershipsCollection)
    .doc(
      buildCommunityMembershipDocumentId(
        resolvedGroup.groupId,
        invitedAuthUser.uid,
      ),
    )
    .get();

  if (membershipSnapshot.exists) {
    response.status(409).json({
      ok: false,
      error: 'That account is already a member of this community group.',
    });
    return;
  }

  const activeInviteSnapshot = await firestore
    .collection(communityInvitesCollection)
    .where('groupId', '==', resolvedGroup.groupId)
    .where('invitedUid', '==', invitedAuthUser.uid)
    .where('status', '==', 'pending')
    .get();

  const hasActiveInvite = activeInviteSnapshot.docs.some(
    (doc) => !isInviteExpired(doc.data().expiresAt),
  );
  if (hasActiveInvite) {
    response.status(409).json({
      ok: false,
      error: 'There is already an active invitation for that account in this group.',
    });
    return;
  }

  const inviteReference = firestore.collection(communityInvitesCollection).doc();
  const inviteToken = randomBytes(24).toString('hex');
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  const inviterName =
    readStringValue(inviterAuthUser.displayName) ??
    emailDisplayFallback(inviterEmail);

  try {
    await upsertCommunityUserProfile({
      userId: inviterAuthUser.uid,
      displayName: inviterAuthUser.displayName ?? '',
      email: inviterEmail,
      photoURL: inviterAuthUser.photoURL ?? null,
    });

    const invitedUserEmail = normalizeEmail(invitedAuthUser.email);
    if (invitedUserEmail != null) {
      await upsertCommunityUserProfile({
        userId: invitedAuthUser.uid,
        displayName: invitedAuthUser.displayName ?? '',
        email: invitedUserEmail,
        photoURL: invitedAuthUser.photoURL ?? null,
      });
    }

    await inviteReference.set({
      groupId: resolvedGroup.groupId,
      inviterUid: inviterAuthUser.uid,
      invitedUid: invitedAuthUser.uid,
      invitedEmailLower: invitedEmail,
      status: 'pending',
      tokenHash: hashCommunityInviteToken(inviteToken),
      expiresAt: Timestamp.fromDate(expiresAt),
      acceptedAt: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      sentAt: null,
    });

    await sendCommunityInviteEmail({
      email: invitedEmail,
      groupName: resolvedGroup.groupName,
      inviteLink: buildCommunityInviteLink(inviteReference.id, inviteToken),
      inviterName,
      expiresAt,
    });

    await inviteReference.set(
      {
        sentAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  } catch (error) {
    await inviteReference.delete().catch(() => undefined);
    response.status(500).json({
      ok: false,
      error:
        error instanceof Error ? error.message : 'Could not send the invitation email.',
    });
    return;
  }

  response.json({
    ok: true,
    inviteId: inviteReference.id,
    groupId: resolvedGroup.groupId,
    groupName: resolvedGroup.groupName,
  });
});

export const communityInviteDetails = onRequest(async (request, response) => {
  if (sendFirestoreReadinessErrorResponse(response)) {
    return;
  }

  const inviteId = readInviteId(request);
  const inviteToken = readInviteToken(request);
  if (inviteId == null || inviteToken == null) {
    response.status(400).json({
      ok: false,
      error: 'Missing invitation credentials.',
    });
    return;
  }

  const inviteSnapshot = await firestore
    .collection(communityInvitesCollection)
    .doc(inviteId)
    .get();
  if (!inviteSnapshot.exists) {
    response.status(404).json({
      ok: false,
      error: 'This invitation could not be found.',
    });
    return;
  }

  const inviteData = inviteSnapshot.data() ?? {};
  if (inviteData.tokenHash !== hashCommunityInviteToken(inviteToken)) {
    response.status(403).json({
      ok: false,
      error: 'This invitation link is invalid.',
    });
    return;
  }

  if (inviteData.status !== 'pending') {
    response.status(409).json({
      ok: false,
      error: 'This invitation has already been used.',
    });
    return;
  }

  if (isInviteExpired(inviteData.expiresAt)) {
    await inviteSnapshot.ref.set(
      {
        status: 'expired',
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    response.status(410).json({
      ok: false,
      error: 'This invitation has expired.',
    });
    return;
  }

  const [groupSnapshot, inviterSnapshot] = await Promise.all([
    firestore.collection(communityGroupsCollection).doc(inviteData.groupId as string).get(),
    firestore.collection(usersCollection).doc(inviteData.inviterUid as string).get(),
  ]);

  response.json({
    ok: true,
    groupName: readStringValue(groupSnapshot.data()?.name) ?? 'Care Circle',
    invitedEmail: readStringValue(inviteData.invitedEmailLower) ?? '',
    inviterName:
      readStringValue(inviterSnapshot.data()?.displayName) ?? 'A Carebit member',
    expiresAt: readTimestampIso(inviteData.expiresAt),
  });
});

export const acceptCommunityInvite = onRequest(async (request, response) => {
  let acceptingUserId: string;
  try {
    acceptingUserId = await readAuthenticatedUserId(request);
  } catch (error) {
    response.status(401).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : 'Could not verify your Firebase account.',
    });
    return;
  }

  if (sendFirestoreReadinessErrorResponse(response)) {
    return;
  }

  const inviteId = readInviteId(request);
  const inviteToken = readInviteToken(request);
  if (inviteId == null || inviteToken == null) {
    response.status(400).json({
      ok: false,
      error: 'Missing invitation credentials.',
    });
    return;
  }

  const acceptingAuthUser = await getAuth().getUser(acceptingUserId);
  const acceptingEmail = normalizeEmail(acceptingAuthUser.email);
  if (acceptingEmail == null) {
    response.status(400).json({
      ok: false,
      error: 'Your Firebase account must have a valid email address before accepting invites.',
    });
    return;
  }

  try {
    await upsertCommunityUserProfile({
      userId: acceptingAuthUser.uid,
      displayName: acceptingAuthUser.displayName ?? '',
      email: acceptingEmail,
      photoURL: acceptingAuthUser.photoURL ?? null,
    });
  } catch (_) {}

  try {
    await firestore.runTransaction(async (transaction) => {
      const inviteReference = firestore
        .collection(communityInvitesCollection)
        .doc(inviteId);
      const inviteSnapshot = await transaction.get(inviteReference);
      if (!inviteSnapshot.exists) {
        throw new Error('This invitation could not be found.');
      }

      const inviteData = inviteSnapshot.data() ?? {};
      if (inviteData.tokenHash !== hashCommunityInviteToken(inviteToken)) {
        throw new Error('This invitation link is invalid.');
      }
      if (inviteData.status !== 'pending') {
        throw new Error('This invitation has already been used.');
      }
      if (isInviteExpired(inviteData.expiresAt)) {
        transaction.set(
          inviteReference,
          {
            status: 'expired',
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        throw new Error('This invitation has expired.');
      }
      if (
        inviteData.invitedUid !== acceptingUserId ||
        inviteData.invitedEmailLower !== acceptingEmail
      ) {
        throw new Error(
          'This invitation was sent to a different account. Sign in with the invited email address to accept it.',
        );
      }

      const groupId = readStringValue(inviteData.groupId);
      if (groupId == null) {
        throw new Error('The invitation is missing its community group.');
      }

      const membershipReference = firestore
        .collection(communityMembershipsCollection)
        .doc(buildCommunityMembershipDocumentId(groupId, acceptingUserId));
      const membershipSnapshot = await transaction.get(membershipReference);
      if (membershipSnapshot.exists) {
        throw new Error('You are already a member of this community group.');
      }

      const userReference = firestore.collection(usersCollection).doc(acceptingUserId);
      transaction.set(membershipReference, {
        groupId,
        uid: acceptingUserId,
        displayNameSnapshot:
          readStringValue(acceptingAuthUser.displayName) ??
          emailDisplayFallback(acceptingEmail),
        emailLower: acceptingEmail,
        role: 'member',
        joinedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        userReference,
        {
          ...buildUserProfilePayload({
            displayName: acceptingAuthUser.displayName ?? '',
            email: acceptingEmail,
            photoURL: acceptingAuthUser.photoURL ?? null,
          }),
          groupIds: FieldValue.arrayUnion(groupId),
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      transaction.set(
        inviteReference,
        {
          status: 'accepted',
          acceptedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
  } catch (error) {
    response.status(400).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : 'Could not accept the invitation.',
    });
    return;
  }

  response.json({ ok: true });
});

export const communityMemberMetrics = onRequest(async (request, response) => {
  let callerUserId: string;
  try {
    callerUserId = await readAuthenticatedUserId(request);
  } catch (error) {
    response.status(401).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : 'Could not verify your Firebase account.',
    });
    return;
  }

  if (sendFirestoreReadinessErrorResponse(response)) {
    return;
  }

  const memberUid = readStringValue(request.query.memberUid);
  if (memberUid == null) {
    response.status(400).json({
      ok: false,
      error: 'Missing community member id.',
    });
    return;
  }

  const [callerSnapshot, memberSnapshot] = await Promise.all([
    firestore.collection(usersCollection).doc(callerUserId).get(),
    firestore.collection(usersCollection).doc(memberUid).get(),
  ]);
  const callerGroupIds = readStringList(callerSnapshot.data()?.groupIds);
  const memberGroupIds = readStringList(memberSnapshot.data()?.groupIds);
  const sharedGroupIds = callerGroupIds.filter((groupId) => memberGroupIds.includes(groupId));

  if (sharedGroupIds.length === 0) {
    response.status(403).json({
      ok: false,
      error: 'You can only view Fitbit metrics for members who share a community group with you.',
    });
    return;
  }

  const connectionDoc = await firestore.collection('fitbit_connections').doc(memberUid).get();
  if (!connectionDoc.exists) {
    response.json({
      ok: true,
      hasConnection: false,
      metrics: null,
    });
    return;
  }

  const connectionData = connectionDoc.data() ?? {};
  const accessToken = readStringValue(connectionData.accessToken);
  if (accessToken == null) {
    response.status(400).json({
      ok: false,
      error: 'Fitbit access token missing from the member connection record.',
    });
    return;
  }

  try {
    const targetDateStr =
      typeof request.query.date === 'string' ? request.query.date : undefined;
    const metrics = await fetchFitbitHealthMetrics(accessToken, targetDateStr);
    response.json({
      ok: true,
      hasConnection: true,
      metrics,
    });
  } catch (error) {
    response.status(500).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : 'Failed to fetch Fitbit health metrics.',
    });
  }
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
