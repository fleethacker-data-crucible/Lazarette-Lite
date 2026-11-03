// Shapes from docs/API.md (v5.1). Nothing here ever holds a secret except the explicit
// reveal / history-reveal / wincred-reveal responses, which the UI keeps in memory only.

export type VaultState = 'setup' | 'locked' | 'unlocked';
export type Profile = 'software' | 'smartcard';
export type ItemType = 'login' | 'parameter' | 'api' | 'note' | 'infrastructure';
export const ITEM_TYPES: ItemType[] = ['login', 'parameter', 'api', 'note', 'infrastructure'];

export interface Health {
  ok: boolean;
  product: 'Lazarette';
  version: string;
  state: VaultState;
  profile: Profile;
  starkStreaming: boolean;
  testMode: boolean;
  idleLockMinutes: number;
}

export interface Provider {
  name: Profile | string;
  displayName: string;
  strength: string;
  available: boolean;
  /** Implemented but not yet validated on real hardware; selectable, never recommended. */
  preview?: boolean;
  reason: string;
}

export interface SetupInfo {
  state: VaultState;
  recommended: string;
  providers: Provider[];
  legacyVault: { found: boolean; path: string; records?: number };
  platform: { os: string; isWindows: boolean; psVersion: string; languageMode: string };
}

export interface LegacyImportResult {
  imported: number;
  skipped: number;
  problems: { service: string; issue: string }[];
  totpCarried: boolean;
}

export interface TotpBegin {
  secret: string;
  uri: string;
  issuer: string;
  account: string;
}

export interface SecurityStatus {
  profile: Profile;
  totpEnabled: boolean;
  lease: { active: boolean; remainingH: number };
  recoveryCodesLeft: number;
  idleLockMinutes: number;
  clipboardClearSec: number;
  totpLeaseHours: number;
  lastUnlock: string | null;
  dpapiLayer: boolean;
}

export interface CryptoInfo {
  format: string;
  profile: Profile;
  keyId: string;
  created: string;
  savedAt: string;
  count: number;
  wraps: Record<string, unknown>[];
  cipher: string;
  kdf: string;
  dpapiLayer: boolean;
}

export interface SecurityHealth {
  score: number;
  total: number;
  weak: string[];
  reused: string[][];
  old: string[];
  missingTotp: string[];
  checkedAt: string;
}

export interface Settings {
  totpLeaseHours: number;
  idleLockMinutes: number;
  clipboardClearSec: number;
  starkStreaming: boolean;
  starkBaseUrl: string;
  starkModel: string;
  starkKeyItem: string;
  theme: 'dark' | 'light' | 'system';
  updateManifestUrl: string;
}

/** GET /api/security/expiring: items with an expiry date field coming up, soonest first. Names and dates only. */
export interface ExpiringItem {
  id: string;
  service: string;
  type: ItemType;
  field: string;
  date: string;
  daysLeft: number;
  expired: boolean;
}
export interface ExpiringReport {
  days: number;
  count: number;
  items: ExpiringItem[];
}

/** POST /api/import/preview: what an import file would do. Never contains a secret, note or field value. */
export type ImportAction = 'add' | 'add-renamed' | 'skip-identical' | 'skip-conflict';
export type ImportFormat = 'auto' | 'csv' | 'bitwarden-json' | '1pux' | 'keepass-xml';
export type ExportFormat = 'csv' | 'bitwarden-json' | 'keepass-xml';
export interface ImportPreviewItem {
  index: number;
  service: string;
  user: string;
  type: ItemType;
  tags: string;
  website: string;
  hasTotp: boolean;
  fieldCount: number;
  action: ImportAction;
  reason: string;
}
export interface ImportPreview {
  format: string;
  formatLabel: string;
  total: number;
  counts: { add: number; addRenamed: number; skipIdentical: number; skipConflict: number; invalid: number };
  warnings: string[];
  items: ImportPreviewItem[];
}
/** POST /api/import/commit */
export interface ImportResult {
  added: number;
  addedRenamed: number;
  skippedIdentical: number;
  skippedConflict: number;
  invalid: number;
  format: string;
  warnings: string[];
  count: number;
}
/** POST /api/export: a readable (plaintext) copy of every item; needs the credentials again. */
export interface ExportResult {
  format: ExportFormat;
  name: string;
  mime: string;
  text: string;
  count: number;
  notIncluded: { attachments: number; history: boolean };
}

/** POST /api/assistant/test: outcome of one short non-streaming request. Never contains the key. */
export interface AssistantTestResult {
  ok: boolean;
  /** HTTP status from the endpoint, 0 when it was not reached. */
  status: number;
  /** The chat completions URL that was called. */
  endpoint: string;
  model: string;
  ms: number;
  message: string;
  reply: string;
}

/** Field kinds accepted by the server (lib/vault/Store.ps1 maps anything else to text). */
export type FieldType = 'text' | 'hidden' | 'url' | 'date' | 'number' | 'totp';

export interface FieldSummary {
  name: string;
  type: FieldType;
  hidden: boolean;
}

export interface Field extends FieldSummary {
  value: string;
}

export interface AttachmentMeta {
  id: string;
  name: string;
  size: number;
}

/** Safe record: never contains secret values. */
export interface VaultItem {
  id: string;
  service: string;
  user: string;
  type: ItemType;
  tags: string;
  website: string;
  updated: string;
  created: string;
  version: number;
  hasTotp: boolean;
  hasNotes: boolean;
  fieldSummary: FieldSummary[];
  winCredTarget: string;
  winCredRequested: boolean;
  attachments: AttachmentMeta[];
  /** Names this item is shared with Fairlead under (docs/FAIRLEAD.md). Names only, never a value. */
  fairleadShares?: { name: string; field: string }[];
}

export interface RecordInput {
  service?: string;
  user?: string;
  secret?: string;
  type?: ItemType;
  tags?: string;
  website?: string;
  notes?: string;
  totpSecret?: string;
  fields?: Field[];
  storeInWinCred?: boolean;
  version?: number;
}

export interface Revealed {
  secret: string;
  notes: string;
  totpSecret: string;
  totpCode: string | null;
  totpExpiresIn: number | null;
  fields: Field[];
}

export interface HistoryVersion {
  version: number;
  updated: string;
  changed: string[];
}

export interface HistoryRevealed {
  secret: string;
  user: string;
  notes: string;
  website: string;
}

export interface WinCredTarget {
  target: string;
  linkedRecordId: string | null;
}

export interface UpdateStatus {
  current: string;
  signer: { pinned: boolean; thumbprint?: string };
  manifestUrl?: string;
  latest?: string;
  available?: boolean;
}

export type StarkEvent =
  | { type: 'start' }
  | { type: 'status'; text: string }
  | { type: 'delta'; text: string }
  | { type: 'done' }
  | { type: 'error'; message: string };

// ---- Access packages (lib/12-access-packages.ps1) ----
export type RequirementKind = 'form' | 'agreement' | 'certification' | 'training' | 'approval' | 'other';
export const REQUIREMENT_KINDS: RequirementKind[] = ['form', 'agreement', 'certification', 'training', 'approval', 'other'];
export const REQUEST_STATUSES = ['draft', 'in-progress', 'submitted', 'awaiting-approval', 'access-granted', 'rejected', 'revoked', 'archived'] as const;
export type RequestStatus = (typeof REQUEST_STATUSES)[number];
export const REQUIREMENT_STATUSES = ['pending', 'evidence-available', 'submitted', 'reviewed', 'waived'] as const;
export type RequirementStatus = (typeof REQUIREMENT_STATUSES)[number];
export const PROFILE_KEYS = ['fullName', 'organization', 'email', 'phone', 'title', 'supervisor', 'supervisorEmail'] as const;
export type ProfileKey = (typeof PROFILE_KEYS)[number];

export interface PkgTemplateRequirement {
  id: string;
  kind: RequirementKind;
  name: string;
  required: boolean;
}
export interface PkgTemplate {
  id: string;
  name: string;
  description: string;
  requirements: PkgTemplateRequirement[];
  created: string;
  revision: number;
}
export interface PkgRequirement {
  id: string;
  sourceId: string;
  kind: RequirementKind;
  name: string;
  required: boolean;
  status: RequirementStatus;
  evidenceIds: string[];
  credentialId?: string;
  note: string;
  updated: string;
}
export interface PkgRequest {
  id: string;
  templateId: string;
  templateRevision: number;
  label: string;
  profileId: string;
  vaultId: string;
  status: RequestStatus;
  requirements: PkgRequirement[];
  created: string;
  updated: string;
  reviewAt: string;
  owner: string;
}
export interface PkgDocument {
  id: string;
  requestId: string;
  templateId: string;
  requirementId: string;
  name: string;
  mime: string;
  size: number;
  sha256: string;
  version: number;
  created: string;
  source: string;
}
export interface PkgProfile {
  id: string;
  name: string;
  fields: Partial<Record<ProfileKey, string>>;
  sources?: Record<string, { kind: string; document: string; field: string; recordedAt: string }>;
  version: number;
  created: string;
  updated: string;
}
export interface PkgCredential {
  id: string;
  name: string;
  authority: string;
  expiry: string;
  origin: string;
  verification: string;
  created: string;
  updated: string;
}
export interface PkgMapping {
  id: string;
  name: string;
  fields: Record<string, ProfileKey | 'none'>;
  overlays: PdfOverlay[];
  created: string;
}
export interface PkgRenewal {
  id: string;
  kind: 'credential' | 'access-review';
  name: string;
  days: number;
  expires: string;
  status: string;
}
export interface PkgEvent {
  id: string;
  at: string;
  kind: string;
  target: string;
  detail: string;
}
export interface PkgBootstrap {
  version: number;
  templates: PkgTemplate[];
  requests: PkgRequest[];
  documents: PkgDocument[];
  profiles: PkgProfile[];
  credentials: PkgCredential[];
  mappings: PkgMapping[];
  events: PkgEvent[];
  renewals: PkgRenewal[];
}
export interface PdfOverlay {
  page: number;
  x: number;
  y: number;
  size: number;
  profileKey: ProfileKey;
}

// ---- Fairlead (docs/FAIRLEAD.md): pairing and secrets shared by name. Never a value.
export interface FairleadShare {
  name: string;
  recordId: string;
  service: string;
  type: ItemType | '';
  field: string;
  hasValue: boolean;
  created: string;
  lastRead: string | null;
}
export interface FairleadStatus {
  paired: boolean;
  pairing: { id: string; created: string; lastUsed: string | null; uses: number } | null;
  shares: FairleadShare[];
  port: number;
}
