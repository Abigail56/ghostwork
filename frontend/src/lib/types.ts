// Mirrors the FastAPI response models (backend/app/schemas).

export type WorkflowStatus = "draft" | "active" | "paused";
export type ExecutionStatus = "queued" | "running" | "succeeded" | "failed" | "cancelled";
export type StepStatus = "pending" | "running" | "succeeded" | "failed" | "skipped";

export interface User {
  id: string;
  email: string;
  full_name: string;
  notify_on_failure: boolean;
  notify_on_success: boolean;
  email_on_failure: boolean;
  reduce_motion: "system" | "reduce" | "full";
  density: "comfortable" | "compact";
  created_at: string;
  password_changed_at: string | null;
  terms_version: string | null;
  terms_accepted_at: string | null;
}

export interface TokenResponse {
  access_token: string;
  token_type: "bearer";
  expires_at: string;
  user: User;
}

export interface Page<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
}

export interface SessionInfo {
  id: string;
  user_agent: string | null;
  ip_address: string | null;
  created_at: string;
  last_used_at: string;
  expires_at: string;
  current: boolean;
}

export interface NodeDefinition {
  id: string;
  type: string;
  name: string;
  position: { x: number; y: number };
  config: Record<string, unknown>;
}

export interface EdgeDefinition {
  id: string;
  source: string;
  target: string;
  source_handle: string;
}

export interface WorkflowDefinition {
  nodes: NodeDefinition[];
  edges: EdgeDefinition[];
}

export interface ValidationIssue {
  message: string;
  node_id: string | null;
  field: string | null;
}

export interface LastExecution {
  id: string;
  status: ExecutionStatus;
  created_at: string;
  finished_at: string | null;
}

export interface WorkflowSummary {
  id: string;
  name: string;
  description: string;
  status: WorkflowStatus;
  trigger_type: string | null;
  step_count: number;
  last_run_at: string | null;
  next_run_at: string | null;
  created_at: string;
  updated_at: string;
  last_execution: LastExecution | null;
}

export interface Workflow extends WorkflowSummary {
  definition: WorkflowDefinition;
  version: number;
  webhook_url: string | null;
  webhook_signing_enabled: boolean;
  validation: ValidationIssue[];
}

export interface ExecutionSummary {
  id: string;
  workflow_id: string;
  workflow_name: string;
  status: ExecutionStatus;
  trigger_type: string;
  error_message: string | null;
  created_at: string;
  started_at: string | null;
  finished_at: string | null;
  duration_ms: number | null;
}

export interface ExecutionStep {
  id: string;
  node_id: string;
  node_type: string;
  node_name: string;
  position: number;
  status: StepStatus;
  attempts: number;
  output: Record<string, unknown> | null;
  error_message: string | null;
  started_at: string | null;
  finished_at: string | null;
  duration_ms: number | null;
}

export interface Execution extends ExecutionSummary {
  trigger_payload: Record<string, unknown>;
  definition_snapshot: WorkflowDefinition;
  workflow_version: number;
  steps: ExecutionStep[];
}

export interface NodeType {
  type: string;
  kind: "trigger" | "action" | "condition";
  label: string;
  description: string;
  integration_provider: string | null;
  outputs: string[];
  default_config: Record<string, unknown>;
}

export interface Template {
  slug: string;
  name: string;
  description: string;
  category: string;
  requires: string[];
  definition: WorkflowDefinition;
}

export interface Provider {
  key: string;
  label: string;
  available: boolean;
  description: string;
  verifiable: boolean;
}

export interface Integration {
  id: string;
  provider: string;
  name: string;
  status: "connected" | "error";
  last_error: string | null;
  last_verified_at: string | null;
  created_at: string;
  details: Record<string, unknown>;
}

export interface NotificationItem {
  id: string;
  kind: string;
  title: string;
  body: string;
  link: string | null;
  read_at: string | null;
  created_at: string;
}

export interface Activity {
  id: string;
  kind: string;
  message: string;
  workflow_id: string | null;
  created_at: string;
}

export interface DashboardSummary {
  total_workflows: number;
  active_workflows: number;
  total_executions: number;
  executions_30d: number;
  success_rate_30d: number | null;
  trend: { date: string; succeeded: number; failed: number; other: number }[];
  recent_executions: ExecutionSummary[];
  recent_activity: Activity[];
  health: {
    failures_24h: number;
    successes_24h: number;
    in_progress: number;
    last_execution_at: string | null;
    attention: { workflow_id: string; workflow_name: string; reason: string }[];
  };
}
