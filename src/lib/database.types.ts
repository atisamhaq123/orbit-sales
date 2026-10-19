// Generated from tested Orbit Sales migrations. Regenerate with npm test.
export type Json = string | number | boolean | null | {[key:string]:Json|undefined} | Json[];
export type Database = { public: { Tables: {
  activity: { Row: {
    id: string;
    workspace_id: string;
    lead_id: string | null;
    actor_id: string | null;
    message: string;
    created_at: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  audit: { Row: {
    id: string;
    workspace_id: string;
    actor_id: string | null;
    event: string;
    created_at: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  billing_locks: { Row: {
    workspace_id: string;
    token: string;
    expires_at: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  chunks: { Row: {
    id: string;
    workspace_id: string;
    document_id: string;
    version_id: string;
    ordinal: number;
    content: string;
    location: string;
    embedding: string;
    embedding_model: string;
    search: string | null;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  conversations: { Row: {
    id: string;
    workspace_id: string;
    user_id: string;
    title: string;
    created_at: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  document_versions: { Row: {
    id: string;
    workspace_id: string;
    document_id: string;
    path: string;
    size: number;
    mime: string;
    version: number;
    created_at: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  documents: { Row: {
    id: string;
    workspace_id: string;
    title: string;
    size: number;
    version: number;
    status: string;
    error: string | null;
    uploader_id: string;
    active_version_id: string | null;
    indexed_at: string | null;
    deleted_at: string | null;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  generations: { Row: {
    id: string;
    workspace_id: string;
    user_id: string;
    lead_id: string | null;
    conversation_id: string | null;
    operation: string;
    question: string;
    output: string;
    citations: Json;
    provider: string;
    model: string;
    prompt_version: string;
    status: string;
    latency: number | null;
    usage: Json | null;
    period_start: string;
    expires_at: string;
    created_at: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  ingestion_jobs: { Row: {
    id: string;
    workspace_id: string;
    document_id: string;
    version_id: string;
    requested_by: string;
    status: string;
    attempts: number;
    available_at: string;
    lease_until: string | null;
    lease_token: string | null;
    error: string | null;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  invitations: { Row: {
    id: string;
    workspace_id: string;
    email: string;
    token_hash: string;
    status: string;
    expires_at: string;
    accepted_by: string | null;
    created_at: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  leads: { Row: {
    id: string;
    workspace_id: string;
    name: string;
    company: string;
    email: string;
    phone: string;
    source: string;
    stage: string;
    assignee_id: string | null;
    value: number;
    notes: string;
    archived: boolean;
    version: number;
    created_at: string;
    updated_at: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  memberships: { Row: {
    workspace_id: string;
    user_id: string;
    role: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  notifications: { Row: {
    id: string;
    workspace_id: string | null;
    recipient_id: string | null;
    recipient_email: string | null;
    invitation_id: string | null;
    title: string;
    body: string;
    href: string;
    read_at: string | null;
    created_at: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  plan_limits: { Row: {
    id: string;
    limits: Json;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  profiles: { Row: {
    id: string;
    name: string;
    email: string;
    timezone: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  rate_limits: { Row: {
    key: string;
    bucket: string;
    count: number;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  stripe_events: { Row: {
    id: string;
    created_at: string;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  tasks: { Row: {
    id: string;
    workspace_id: string;
    lead_id: string;
    title: string;
    assignee_id: string | null;
    due_at: string;
    priority: string;
    completed: boolean;
    version: number;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
  workspaces: { Row: {
    id: string;
    owner_id: string;
    name: string;
    creation_key: string;
    plan: string | null;
    subscription_status: string;
    stripe_customer_id: string | null;
    stripe_subscription_id: string | null;
    period_start: string | null;
    period_end: string | null;
    cancel_at_period_end: boolean;
    billing_synced_at: string | null;
  }; Insert: Record<string, unknown>; Update: Record<string, unknown>; Relationships: [] };
}; Views: Record<string, never>; Functions: Record<string, {Args:Record<string, unknown>; Returns:Json}>; Enums: Record<string, never>; CompositeTypes: Record<string, never> } };
