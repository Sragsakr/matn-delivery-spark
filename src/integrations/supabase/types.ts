export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.17"
  }
  public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      actor_type: "user" | "service" | "system" | "scheduler"
      app_role:
        | "platform_admin"
        | "tenant_admin"
        | "executive_viewer"
        | "delivery_manager"
        | "team_lead"
        | "contributor"
        | "qa_release_owner"
        | "readonly_viewer"
      audit_outcome: "success" | "failure" | "denied" | "noop"
      bug_handling_mode: "as_requirement" | "as_task" | "excluded"
      connection_status:
        | "unconfigured"
        | "pending"
        | "connected"
        | "error"
        | "disabled"
      content_origin: "deterministic" | "ai_generated" | "human"
      health_status: "good" | "watch" | "risk" | "critical" | "unknown"
      issue_status: "open" | "acknowledged" | "resolved" | "ignored"
      iteration_phase: "future" | "current" | "completed" | "undated"
      kpi_direction: "higherIsBetter" | "lowerIsBetter" | "targetBand"
      kpi_scope_level: "global" | "tenant" | "project" | "team"
      process_template_kind: "agile" | "scrum" | "cmmi" | "basic" | "custom"
      pull_request_status:
        | "active"
        | "abandoned"
        | "completed"
        | "notSet"
        | "unknown"
      recommendation_status:
        | "proposed"
        | "accepted"
        | "rejected"
        | "deferred"
        | "completed"
      review_vote:
        | "approved"
        | "approvedWithSuggestions"
        | "noVote"
        | "waitingForAuthor"
        | "rejected"
      risk_status: "open" | "mitigating" | "resolved" | "dismissed"
      rollup_mode:
        | "leaf_only"
        | "parent_only"
        | "process_mapping"
        | "story_level"
      run_result:
        | "succeeded"
        | "partiallySucceeded"
        | "failed"
        | "canceled"
        | "none"
        | "unknown"
      run_state:
        | "notStarted"
        | "inProgress"
        | "completed"
        | "canceling"
        | "postponed"
        | "unknown"
      scope_target: "project" | "team"
      severity_level: "critical" | "high" | "medium" | "low" | "unknown"
      source_status: "active" | "deleted" | "inaccessible" | "unknown"
      state_category:
        | "proposed"
        | "inProgress"
        | "resolved"
        | "completed"
        | "removed"
        | "unknown"
      sync_auth_mode: "pat" | "oauth" | "managed_identity" | "none"
      sync_run_status:
        | "queued"
        | "running"
        | "succeeded"
        | "partial"
        | "failed"
        | "skipped"
      work_item_alias:
        | "epic"
        | "feature"
        | "story"
        | "requirement"
        | "issue"
        | "bug"
        | "task"
        | "testCase"
        | "custom"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      actor_type: ["user", "service", "system", "scheduler"],
      app_role: [
        "platform_admin",
        "tenant_admin",
        "executive_viewer",
        "delivery_manager",
        "team_lead",
        "contributor",
        "qa_release_owner",
        "readonly_viewer",
      ],
      audit_outcome: ["success", "failure", "denied", "noop"],
      bug_handling_mode: ["as_requirement", "as_task", "excluded"],
      connection_status: [
        "unconfigured",
        "pending",
        "connected",
        "error",
        "disabled",
      ],
      content_origin: ["deterministic", "ai_generated", "human"],
      health_status: ["good", "watch", "risk", "critical", "unknown"],
      issue_status: ["open", "acknowledged", "resolved", "ignored"],
      iteration_phase: ["future", "current", "completed", "undated"],
      kpi_direction: ["higherIsBetter", "lowerIsBetter", "targetBand"],
      kpi_scope_level: ["global", "tenant", "project", "team"],
      process_template_kind: ["agile", "scrum", "cmmi", "basic", "custom"],
      pull_request_status: [
        "active",
        "abandoned",
        "completed",
        "notSet",
        "unknown",
      ],
      recommendation_status: [
        "proposed",
        "accepted",
        "rejected",
        "deferred",
        "completed",
      ],
      review_vote: [
        "approved",
        "approvedWithSuggestions",
        "noVote",
        "waitingForAuthor",
        "rejected",
      ],
      risk_status: ["open", "mitigating", "resolved", "dismissed"],
      rollup_mode: [
        "leaf_only",
        "parent_only",
        "process_mapping",
        "story_level",
      ],
      run_result: [
        "succeeded",
        "partiallySucceeded",
        "failed",
        "canceled",
        "none",
        "unknown",
      ],
      run_state: [
        "notStarted",
        "inProgress",
        "completed",
        "canceling",
        "postponed",
        "unknown",
      ],
      scope_target: ["project", "team"],
      severity_level: ["critical", "high", "medium", "low", "unknown"],
      source_status: ["active", "deleted", "inaccessible", "unknown"],
      state_category: [
        "proposed",
        "inProgress",
        "resolved",
        "completed",
        "removed",
        "unknown",
      ],
      sync_auth_mode: ["pat", "oauth", "managed_identity", "none"],
      sync_run_status: [
        "queued",
        "running",
        "succeeded",
        "partial",
        "failed",
        "skipped",
      ],
      work_item_alias: [
        "epic",
        "feature",
        "story",
        "requirement",
        "issue",
        "bug",
        "task",
        "testCase",
        "custom",
      ],
    },
  },
} as const
