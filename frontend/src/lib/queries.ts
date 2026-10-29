"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "./api";
import type {
  Activity,
  DashboardSummary,
  Execution,
  ExecutionSummary,
  Integration,
  NodeType,
  NotificationItem,
  Page,
  Provider,
  SessionInfo,
  Template,
  User,
  Workflow,
  WorkflowDefinition,
  WorkflowStatus,
  WorkflowSummary,
} from "./types";

export const keys = {
  dashboard: ["dashboard"] as const,
  workflows: (params?: object) => ["workflows", params ?? {}] as const,
  workflow: (id: string) => ["workflow", id] as const,
  executions: (params?: object) => ["executions", params ?? {}] as const,
  execution: (id: string) => ["execution", id] as const,
  nodeTypes: ["node-types"] as const,
  templates: ["templates"] as const,
  providers: ["providers"] as const,
  integrations: ["integrations"] as const,
  notifications: ["notifications"] as const,
  sessions: ["sessions"] as const,
  activity: (page: number) => ["activity", page] as const,
};

const ACTIVE = new Set(["queued", "running"]);

export function useDashboard() {
  return useQuery({
    queryKey: keys.dashboard,
    queryFn: () => api<DashboardSummary>("/dashboard/summary"),
    refetchInterval: (q) => (q.state.data && q.state.data.health.in_progress > 0 ? 3000 : 30_000),
  });
}

export interface WorkflowListParams {
  q?: string;
  status?: WorkflowStatus | "";
  sort?: string;
  page?: number;
  page_size?: number;
}

export function useWorkflows(params: WorkflowListParams = {}) {
  return useQuery({
    queryKey: keys.workflows(params),
    queryFn: () => api<Page<WorkflowSummary>>("/workflows", { query: { ...params } }),
    placeholderData: keepPreviousData,
  });
}

export function useWorkflow(id: string) {
  return useQuery({ queryKey: keys.workflow(id), queryFn: () => api<Workflow>(`/workflows/${id}`) });
}

export interface ExecutionListParams {
  q?: string;
  status?: string;
  workflow_id?: string;
  from?: string;
  to?: string;
  page?: number;
  page_size?: number;
}

export function useExecutions(params: ExecutionListParams = {}) {
  return useQuery({
    queryKey: keys.executions(params),
    queryFn: () => api<Page<ExecutionSummary>>("/executions", { query: { ...params } }),
    placeholderData: keepPreviousData,
    refetchInterval: (q) => (q.state.data?.items.some((e) => ACTIVE.has(e.status)) ? 2500 : false),
  });
}

export function useExecution(id: string | null) {
  return useQuery({
    queryKey: keys.execution(id ?? "none"),
    queryFn: () => api<Execution>(`/executions/${id}`),
    enabled: Boolean(id),
    refetchInterval: (q) => (q.state.data && ACTIVE.has(q.state.data.status) ? 1000 : false),
  });
}

export function useNodeTypes() {
  return useQuery({ queryKey: keys.nodeTypes, queryFn: () => api<NodeType[]>("/node-types", { auth: false }), staleTime: Infinity });
}

export function useTemplates() {
  return useQuery({ queryKey: keys.templates, queryFn: () => api<Template[]>("/templates", { auth: false }), staleTime: 300_000 });
}

export function useProviders() {
  return useQuery({ queryKey: keys.providers, queryFn: () => api<Provider[]>("/integrations/providers", { auth: false }), staleTime: 300_000 });
}

export function useIntegrations() {
  return useQuery({ queryKey: keys.integrations, queryFn: () => api<Integration[]>("/integrations") });
}

export function useNotifications() {
  return useQuery({
    queryKey: keys.notifications,
    queryFn: () => api<{ items: NotificationItem[]; unread: number }>("/notifications"),
    refetchInterval: 30_000,
  });
}

export function useSessions() {
  return useQuery({ queryKey: keys.sessions, queryFn: () => api<SessionInfo[]>("/auth/sessions") });
}

export function useActivity(page: number) {
  return useQuery({
    queryKey: keys.activity(page),
    queryFn: () => api<Page<Activity>>("/activity", { query: { page, page_size: 10 } }),
    placeholderData: keepPreviousData,
  });
}

/* ---------- Mutations ---------- */

function useInvalidateWorkflows() {
  const qc = useQueryClient();
  return (workflow?: Workflow) => {
    qc.invalidateQueries({ queryKey: ["workflows"] });
    qc.invalidateQueries({ queryKey: keys.dashboard });
    if (workflow) qc.setQueryData(keys.workflow(workflow.id), workflow);
  };
}

export function useCreateWorkflow() {
  const invalidate = useInvalidateWorkflows();
  return useMutation({
    mutationFn: (body: { name: string; description?: string; definition?: WorkflowDefinition }) =>
      api<Workflow>("/workflows", { method: "POST", body }),
    onSuccess: invalidate,
  });
}

export function useUpdateWorkflow(id: string) {
  const invalidate = useInvalidateWorkflows();
  return useMutation({
    mutationFn: (body: { name?: string; description?: string; definition?: WorkflowDefinition; expected_version?: number }) =>
      api<Workflow>(`/workflows/${id}`, { method: "PATCH", body }),
    onSuccess: invalidate,
  });
}

export function useSetWorkflowStatus() {
  const invalidate = useInvalidateWorkflows();
  return useMutation({
    mutationFn: ({ id, status }: { id: string; status: WorkflowStatus }) =>
      api<Workflow>(`/workflows/${id}/status`, { method: "POST", body: { status } }),
    onSuccess: invalidate,
  });
}

export function useDuplicateWorkflow() {
  const invalidate = useInvalidateWorkflows();
  return useMutation({
    mutationFn: (id: string) => api<Workflow>(`/workflows/${id}/duplicate`, { method: "POST" }),
    onSuccess: invalidate,
  });
}

export function useDeleteWorkflow() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api(`/workflows/${id}`, { method: "DELETE" }),
    onSuccess: (_data, id) => {
      qc.removeQueries({ queryKey: keys.workflow(id) });
      qc.invalidateQueries({ queryKey: ["workflows"] });
      qc.invalidateQueries({ queryKey: ["executions"] });
      qc.invalidateQueries({ queryKey: keys.dashboard });
    },
  });
}

export function useRunWorkflow() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload?: Record<string, unknown> }) =>
      api<ExecutionSummary>(`/workflows/${id}/run`, { method: "POST", body: { payload: payload ?? {} } }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["executions"] });
      qc.invalidateQueries({ queryKey: keys.dashboard });
    },
  });
}

export function useRotateWebhook() {
  const invalidate = useInvalidateWorkflows();
  return useMutation({
    mutationFn: (id: string) => api<Workflow>(`/workflows/${id}/webhook/rotate`, { method: "POST" }),
    onSuccess: invalidate,
  });
}

export function useExecutionAction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, action }: { id: string; action: "cancel" | "rerun" }) =>
      api<ExecutionSummary>(`/executions/${id}/${action}`, { method: "POST" }),
    onSuccess: (_d, { id }) => {
      qc.invalidateQueries({ queryKey: ["executions"] });
      qc.invalidateQueries({ queryKey: keys.execution(id) });
      qc.invalidateQueries({ queryKey: keys.dashboard });
    },
  });
}

export function useUseTemplate() {
  const invalidate = useInvalidateWorkflows();
  return useMutation({
    mutationFn: ({ slug, name }: { slug: string; name?: string }) =>
      api<Workflow>(`/templates/${slug}/use`, { method: "POST", body: { name } }),
    onSuccess: invalidate,
  });
}

export function useConnectIntegration() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { provider: string; name: string; config: Record<string, unknown> }) =>
      api<Integration>("/integrations", { method: "POST", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: keys.integrations }),
  });
}

export function useIntegrationAction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, action }: { id: string; action: "test" | "delete" }) =>
      action === "test"
        ? api<Integration>(`/integrations/${id}/test`, { method: "POST" })
        : api(`/integrations/${id}`, { method: "DELETE" }),
    onSettled: () => qc.invalidateQueries({ queryKey: keys.integrations }),
  });
}

export function useMarkNotifications() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string | "all") =>
      api(id === "all" ? "/notifications/read-all" : `/notifications/${id}/read`, { method: "POST" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: keys.notifications }),
  });
}

export function useUpdateProfile() {
  return useMutation({
    mutationFn: (body: Partial<Omit<User, "id" | "email" | "created_at" | "password_changed_at">>) =>
      api<User>("/users/me", { method: "PATCH", body }),
  });
}

export function useSessionAction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (target: string | "others") =>
      target === "others"
        ? api<{ message: string }>("/auth/sessions/revoke-others", { method: "POST" })
        : api<{ message: string }>(`/auth/sessions/${target}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: keys.sessions }),
  });
}

export function useChangePassword() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { current_password: string; new_password: string }) =>
      api<{ message: string }>("/auth/change-password", { method: "POST", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: keys.sessions }),
  });
}
