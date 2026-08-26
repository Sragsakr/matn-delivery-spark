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
      az_work_item_relations: {
        Row: {
          access_revoked_at: string | null
          azure_relation_name: string
          created_at: string
          deleted_at_source: string | null
          id: string
          is_cross_project: boolean
          is_deleted: boolean
          last_seen_at: string | null
          relation_type: string
          source_status: Database["public"]["Enums"]["source_status"]
          source_work_item_id: string
          target_azure_work_item_id: number
          target_work_item_id: string | null
          tenant_id: string
          updated_at: string
        }
        Insert: {
          access_revoked_at?: string | null
          azure_relation_name: string
          created_at?: string
          deleted_at_source?: string | null
          id?: string
          is_cross_project?: boolean
          is_deleted?: boolean
          last_seen_at?: string | null
          relation_type: string
          source_status?: Database["public"]["Enums"]["source_status"]
          source_work_item_id: string
          target_azure_work_item_id: number
          target_work_item_id?: string | null
          tenant_id: string
          updated_at?: string
        }
        Update: {
          access_revoked_at?: string | null
          azure_relation_name?: string
          created_at?: string
          deleted_at_source?: string | null
          id?: string
          is_cross_project?: boolean
          is_deleted?: boolean
          last_seen_at?: string | null
          relation_type?: string
          source_status?: Database["public"]["Enums"]["source_status"]
          source_work_item_id?: string
          target_azure_work_item_id?: number
          target_work_item_id?: string | null
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "az_work_item_relations_source_fk"
            columns: ["tenant_id", "source_work_item_id"]
            isOneToOne: false
            referencedRelation: "az_work_items"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "az_work_item_relations_target_fk"
            columns: ["tenant_id", "target_work_item_id"]
            isOneToOne: false
            referencedRelation: "az_work_items"
            referencedColumns: ["tenant_id", "id"]
          },
        ]
      }
      az_work_items: {
        Row: {
          access_revoked_at: string | null
          activated_date: string | null
          alias: Database["public"]["Enums"]["work_item_alias"]
          area_path: string
          assigned_to_member_id: string | null
          azure_rev: number
          azure_severity_raw: string | null
          azure_url: string | null
          azure_work_item_id: number
          azure_work_item_type: string
          blocked_since: string | null
          blocked_source_field: string | null
          changed_at_source: string
          changed_by_member_id: string | null
          closed_date: string | null
          completed_work: number | null
          counts_toward_scope: boolean
          created_at: string
          created_at_source: string
          created_by_member_id: string | null
          custom_fields: Json
          deleted_at_source: string | null
          description: string | null
          estimate: number | null
          estimate_source_field: string | null
          estimate_unit: string | null
          hierarchy_depth: number | null
          id: string
          is_blocked: boolean
          is_deleted: boolean
          is_leaf: boolean
          iteration_id: string | null
          iteration_path: string
          last_seen_at: string | null
          last_synced_at: string | null
          organization_id: string
          original_estimate: number | null
          parent_azure_work_item_id: number | null
          parent_work_item_id: string | null
          priority: number | null
          project_id: string
          reason: string | null
          remaining_work: number | null
          resolved_date: string | null
          severity: Database["public"]["Enums"]["severity_level"] | null
          source_status: Database["public"]["Enums"]["source_status"]
          state: string
          state_category: Database["public"]["Enums"]["state_category"]
          state_change_date: string | null
          tags: string[]
          team_id: string | null
          team_iteration_id: string | null
          tenant_id: string
          title: string
          updated_at: string
        }
        Insert: {
          access_revoked_at?: string | null
          activated_date?: string | null
          alias?: Database["public"]["Enums"]["work_item_alias"]
          area_path?: string
          assigned_to_member_id?: string | null
          azure_rev?: number
          azure_severity_raw?: string | null
          azure_url?: string | null
          azure_work_item_id: number
          azure_work_item_type: string
          blocked_since?: string | null
          blocked_source_field?: string | null
          changed_at_source?: string
          changed_by_member_id?: string | null
          closed_date?: string | null
          completed_work?: number | null
          counts_toward_scope?: boolean
          created_at?: string
          created_at_source?: string
          created_by_member_id?: string | null
          custom_fields?: Json
          deleted_at_source?: string | null
          description?: string | null
          estimate?: number | null
          estimate_source_field?: string | null
          estimate_unit?: string | null
          hierarchy_depth?: number | null
          id?: string
          is_blocked?: boolean
          is_deleted?: boolean
          is_leaf?: boolean
          iteration_id?: string | null
          iteration_path?: string
          last_seen_at?: string | null
          last_synced_at?: string | null
          organization_id: string
          original_estimate?: number | null
          parent_azure_work_item_id?: number | null
          parent_work_item_id?: string | null
          priority?: number | null
          project_id: string
          reason?: string | null
          remaining_work?: number | null
          resolved_date?: string | null
          severity?: Database["public"]["Enums"]["severity_level"] | null
          source_status?: Database["public"]["Enums"]["source_status"]
          state: string
          state_category?: Database["public"]["Enums"]["state_category"]
          state_change_date?: string | null
          tags?: string[]
          team_id?: string | null
          team_iteration_id?: string | null
          tenant_id: string
          title: string
          updated_at?: string
        }
        Update: {
          access_revoked_at?: string | null
          activated_date?: string | null
          alias?: Database["public"]["Enums"]["work_item_alias"]
          area_path?: string
          assigned_to_member_id?: string | null
          azure_rev?: number
          azure_severity_raw?: string | null
          azure_url?: string | null
          azure_work_item_id?: number
          azure_work_item_type?: string
          blocked_since?: string | null
          blocked_source_field?: string | null
          changed_at_source?: string
          changed_by_member_id?: string | null
          closed_date?: string | null
          completed_work?: number | null
          counts_toward_scope?: boolean
          created_at?: string
          created_at_source?: string
          created_by_member_id?: string | null
          custom_fields?: Json
          deleted_at_source?: string | null
          description?: string | null
          estimate?: number | null
          estimate_source_field?: string | null
          estimate_unit?: string | null
          hierarchy_depth?: number | null
          id?: string
          is_blocked?: boolean
          is_deleted?: boolean
          is_leaf?: boolean
          iteration_id?: string | null
          iteration_path?: string
          last_seen_at?: string | null
          last_synced_at?: string | null
          organization_id?: string
          original_estimate?: number | null
          parent_azure_work_item_id?: number | null
          parent_work_item_id?: string | null
          priority?: number | null
          project_id?: string
          reason?: string | null
          remaining_work?: number | null
          resolved_date?: string | null
          severity?: Database["public"]["Enums"]["severity_level"] | null
          source_status?: Database["public"]["Enums"]["source_status"]
          state?: string
          state_category?: Database["public"]["Enums"]["state_category"]
          state_change_date?: string | null
          tags?: string[]
          team_id?: string | null
          team_iteration_id?: string | null
          tenant_id?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "az_work_items_assignee_fk"
            columns: ["tenant_id", "assigned_to_member_id"]
            isOneToOne: false
            referencedRelation: "core_members"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "az_work_items_iteration_fk"
            columns: ["tenant_id", "project_id", "iteration_id"]
            isOneToOne: false
            referencedRelation: "core_iterations"
            referencedColumns: ["tenant_id", "project_id", "id"]
          },
          {
            foreignKeyName: "az_work_items_parent_fk"
            columns: ["tenant_id", "parent_work_item_id"]
            isOneToOne: false
            referencedRelation: "az_work_items"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "az_work_items_project_fk"
            columns: ["tenant_id", "project_id"]
            isOneToOne: false
            referencedRelation: "core_projects"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "az_work_items_team_fk"
            columns: ["tenant_id", "project_id", "team_id"]
            isOneToOne: false
            referencedRelation: "core_teams"
            referencedColumns: ["tenant_id", "project_id", "id"]
          },
          {
            foreignKeyName: "az_work_items_team_iteration_fk"
            columns: ["tenant_id", "project_id", "team_iteration_id"]
            isOneToOne: false
            referencedRelation: "core_team_iterations"
            referencedColumns: ["tenant_id", "project_id", "id"]
          },
        ]
      }
      core_iterations: {
        Row: {
          access_revoked_at: string | null
          azure_iteration_id: string
          azure_iteration_path: string
          created_at: string
          deleted_at_source: string | null
          finish_date: string | null
          id: string
          is_deleted: boolean
          last_seen_at: string | null
          last_synced_at: string | null
          name_ar: string
          name_en: string
          organization_id: string
          phase: Database["public"]["Enums"]["iteration_phase"]
          project_id: string
          source_status: Database["public"]["Enums"]["source_status"]
          start_date: string | null
          tenant_id: string
          updated_at: string
        }
        Insert: {
          access_revoked_at?: string | null
          azure_iteration_id: string
          azure_iteration_path: string
          created_at?: string
          deleted_at_source?: string | null
          finish_date?: string | null
          id?: string
          is_deleted?: boolean
          last_seen_at?: string | null
          last_synced_at?: string | null
          name_ar: string
          name_en: string
          organization_id: string
          phase?: Database["public"]["Enums"]["iteration_phase"]
          project_id: string
          source_status?: Database["public"]["Enums"]["source_status"]
          start_date?: string | null
          tenant_id: string
          updated_at?: string
        }
        Update: {
          access_revoked_at?: string | null
          azure_iteration_id?: string
          azure_iteration_path?: string
          created_at?: string
          deleted_at_source?: string | null
          finish_date?: string | null
          id?: string
          is_deleted?: boolean
          last_seen_at?: string | null
          last_synced_at?: string | null
          name_ar?: string
          name_en?: string
          organization_id?: string
          phase?: Database["public"]["Enums"]["iteration_phase"]
          project_id?: string
          source_status?: Database["public"]["Enums"]["source_status"]
          start_date?: string | null
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_iterations_org_fk"
            columns: ["tenant_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "core_organizations"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "core_iterations_project_fk"
            columns: ["tenant_id", "project_id"]
            isOneToOne: false
            referencedRelation: "core_projects"
            referencedColumns: ["tenant_id", "id"]
          },
        ]
      }
      core_member_capacity: {
        Row: {
          access_revoked_at: string | null
          activity: string | null
          capacity_per_day: number
          created_at: string
          days_off: Json
          deleted_at_source: string | null
          id: string
          is_deleted: boolean
          last_seen_at: string | null
          member_id: string
          net_capacity_hours: number | null
          project_id: string
          source_status: Database["public"]["Enums"]["source_status"]
          team_iteration_id: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          access_revoked_at?: string | null
          activity?: string | null
          capacity_per_day?: number
          created_at?: string
          days_off?: Json
          deleted_at_source?: string | null
          id?: string
          is_deleted?: boolean
          last_seen_at?: string | null
          member_id: string
          net_capacity_hours?: number | null
          project_id: string
          source_status?: Database["public"]["Enums"]["source_status"]
          team_iteration_id: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          access_revoked_at?: string | null
          activity?: string | null
          capacity_per_day?: number
          created_at?: string
          days_off?: Json
          deleted_at_source?: string | null
          id?: string
          is_deleted?: boolean
          last_seen_at?: string | null
          member_id?: string
          net_capacity_hours?: number | null
          project_id?: string
          source_status?: Database["public"]["Enums"]["source_status"]
          team_iteration_id?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_member_capacity_member_fk"
            columns: ["tenant_id", "member_id"]
            isOneToOne: false
            referencedRelation: "core_members"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "core_member_capacity_ti_fk"
            columns: ["tenant_id", "project_id", "team_iteration_id"]
            isOneToOne: false
            referencedRelation: "core_team_iterations"
            referencedColumns: ["tenant_id", "project_id", "id"]
          },
        ]
      }
      core_members: {
        Row: {
          access_revoked_at: string | null
          azure_descriptor: string
          azure_unique_name: string | null
          created_at: string
          deleted_at_source: string | null
          display_name: string
          email: string | null
          id: string
          image_url: string | null
          is_active: boolean
          is_deleted: boolean
          last_seen_at: string | null
          last_synced_at: string | null
          organization_id: string
          source_status: Database["public"]["Enums"]["source_status"]
          tenant_id: string
          updated_at: string
        }
        Insert: {
          access_revoked_at?: string | null
          azure_descriptor: string
          azure_unique_name?: string | null
          created_at?: string
          deleted_at_source?: string | null
          display_name: string
          email?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean
          is_deleted?: boolean
          last_seen_at?: string | null
          last_synced_at?: string | null
          organization_id: string
          source_status?: Database["public"]["Enums"]["source_status"]
          tenant_id: string
          updated_at?: string
        }
        Update: {
          access_revoked_at?: string | null
          azure_descriptor?: string
          azure_unique_name?: string | null
          created_at?: string
          deleted_at_source?: string | null
          display_name?: string
          email?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean
          is_deleted?: boolean
          last_seen_at?: string | null
          last_synced_at?: string | null
          organization_id?: string
          source_status?: Database["public"]["Enums"]["source_status"]
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_members_org_fk"
            columns: ["tenant_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "core_organizations"
            referencedColumns: ["tenant_id", "id"]
          },
        ]
      }
      core_organizations: {
        Row: {
          access_revoked_at: string | null
          azure_organization_id: string | null
          azure_organization_name: string
          base_url: string
          created_at: string
          deleted_at_source: string | null
          id: string
          is_deleted: boolean
          last_seen_at: string | null
          last_synced_at: string | null
          name_ar: string
          name_en: string
          source_status: Database["public"]["Enums"]["source_status"]
          tenant_id: string
          updated_at: string
        }
        Insert: {
          access_revoked_at?: string | null
          azure_organization_id?: string | null
          azure_organization_name: string
          base_url: string
          created_at?: string
          deleted_at_source?: string | null
          id?: string
          is_deleted?: boolean
          last_seen_at?: string | null
          last_synced_at?: string | null
          name_ar: string
          name_en: string
          source_status?: Database["public"]["Enums"]["source_status"]
          tenant_id: string
          updated_at?: string
        }
        Update: {
          access_revoked_at?: string | null
          azure_organization_id?: string | null
          azure_organization_name?: string
          base_url?: string
          created_at?: string
          deleted_at_source?: string | null
          id?: string
          is_deleted?: boolean
          last_seen_at?: string | null
          last_synced_at?: string | null
          name_ar?: string
          name_en?: string
          source_status?: Database["public"]["Enums"]["source_status"]
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_organizations_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "core_tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      core_process_mappings: {
        Row: {
          active_states: string[]
          blocked_fields: string[]
          bug_handling_mode: Database["public"]["Enums"]["bug_handling_mode"]
          created_at: string
          done_states: string[]
          estimate_fields: string[]
          hierarchy_rules: Json
          id: string
          kind: Database["public"]["Enums"]["process_template_kind"]
          notes: Json
          project_id: string
          rollup_mode: Database["public"]["Enums"]["rollup_mode"]
          severity_field: string | null
          state_category_map: Json
          team_id: string | null
          tenant_id: string
          updated_at: string
          work_item_type_aliases: Json
        }
        Insert: {
          active_states?: string[]
          blocked_fields?: string[]
          bug_handling_mode?: Database["public"]["Enums"]["bug_handling_mode"]
          created_at?: string
          done_states?: string[]
          estimate_fields?: string[]
          hierarchy_rules?: Json
          id?: string
          kind?: Database["public"]["Enums"]["process_template_kind"]
          notes?: Json
          project_id: string
          rollup_mode?: Database["public"]["Enums"]["rollup_mode"]
          severity_field?: string | null
          state_category_map?: Json
          team_id?: string | null
          tenant_id: string
          updated_at?: string
          work_item_type_aliases?: Json
        }
        Update: {
          active_states?: string[]
          blocked_fields?: string[]
          bug_handling_mode?: Database["public"]["Enums"]["bug_handling_mode"]
          created_at?: string
          done_states?: string[]
          estimate_fields?: string[]
          hierarchy_rules?: Json
          id?: string
          kind?: Database["public"]["Enums"]["process_template_kind"]
          notes?: Json
          project_id?: string
          rollup_mode?: Database["public"]["Enums"]["rollup_mode"]
          severity_field?: string | null
          state_category_map?: Json
          team_id?: string | null
          tenant_id?: string
          updated_at?: string
          work_item_type_aliases?: Json
        }
        Relationships: [
          {
            foreignKeyName: "core_process_mappings_project_fk"
            columns: ["tenant_id", "project_id"]
            isOneToOne: false
            referencedRelation: "core_projects"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "core_process_mappings_team_fk"
            columns: ["tenant_id", "project_id", "team_id"]
            isOneToOne: false
            referencedRelation: "core_teams"
            referencedColumns: ["tenant_id", "project_id", "id"]
          },
        ]
      }
      core_projects: {
        Row: {
          access_revoked_at: string | null
          azure_project_id: string
          azure_project_name: string
          created_at: string
          custom_fields: Json
          deleted_at_source: string | null
          description: string | null
          id: string
          is_deleted: boolean
          last_seen_at: string | null
          last_synced_at: string | null
          name_ar: string
          name_en: string
          organization_id: string
          process_template_kind: Database["public"]["Enums"]["process_template_kind"]
          process_template_name: string | null
          source_status: Database["public"]["Enums"]["source_status"]
          state: string
          tenant_id: string
          updated_at: string
          visibility: string | null
        }
        Insert: {
          access_revoked_at?: string | null
          azure_project_id: string
          azure_project_name: string
          created_at?: string
          custom_fields?: Json
          deleted_at_source?: string | null
          description?: string | null
          id?: string
          is_deleted?: boolean
          last_seen_at?: string | null
          last_synced_at?: string | null
          name_ar: string
          name_en: string
          organization_id: string
          process_template_kind?: Database["public"]["Enums"]["process_template_kind"]
          process_template_name?: string | null
          source_status?: Database["public"]["Enums"]["source_status"]
          state?: string
          tenant_id: string
          updated_at?: string
          visibility?: string | null
        }
        Update: {
          access_revoked_at?: string | null
          azure_project_id?: string
          azure_project_name?: string
          created_at?: string
          custom_fields?: Json
          deleted_at_source?: string | null
          description?: string | null
          id?: string
          is_deleted?: boolean
          last_seen_at?: string | null
          last_synced_at?: string | null
          name_ar?: string
          name_en?: string
          organization_id?: string
          process_template_kind?: Database["public"]["Enums"]["process_template_kind"]
          process_template_name?: string | null
          source_status?: Database["public"]["Enums"]["source_status"]
          state?: string
          tenant_id?: string
          updated_at?: string
          visibility?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "core_projects_org_fk"
            columns: ["tenant_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "core_organizations"
            referencedColumns: ["tenant_id", "id"]
          },
        ]
      }
      core_team_iterations: {
        Row: {
          access_revoked_at: string | null
          created_at: string
          deleted_at_source: string | null
          id: string
          is_current: boolean
          is_deleted: boolean
          iteration_id: string
          last_seen_at: string | null
          last_synced_at: string | null
          non_working_days: Json
          organization_id: string
          phase: Database["public"]["Enums"]["iteration_phase"]
          project_id: string
          selected_for_sync: boolean
          source_status: Database["public"]["Enums"]["source_status"]
          team_id: string
          tenant_id: string
          time_zone: string
          updated_at: string
          working_weekdays: number[]
        }
        Insert: {
          access_revoked_at?: string | null
          created_at?: string
          deleted_at_source?: string | null
          id?: string
          is_current?: boolean
          is_deleted?: boolean
          iteration_id: string
          last_seen_at?: string | null
          last_synced_at?: string | null
          non_working_days?: Json
          organization_id: string
          phase?: Database["public"]["Enums"]["iteration_phase"]
          project_id: string
          selected_for_sync?: boolean
          source_status?: Database["public"]["Enums"]["source_status"]
          team_id: string
          tenant_id: string
          time_zone?: string
          updated_at?: string
          working_weekdays?: number[]
        }
        Update: {
          access_revoked_at?: string | null
          created_at?: string
          deleted_at_source?: string | null
          id?: string
          is_current?: boolean
          is_deleted?: boolean
          iteration_id?: string
          last_seen_at?: string | null
          last_synced_at?: string | null
          non_working_days?: Json
          organization_id?: string
          phase?: Database["public"]["Enums"]["iteration_phase"]
          project_id?: string
          selected_for_sync?: boolean
          source_status?: Database["public"]["Enums"]["source_status"]
          team_id?: string
          tenant_id?: string
          time_zone?: string
          updated_at?: string
          working_weekdays?: number[]
        }
        Relationships: [
          {
            foreignKeyName: "core_team_iterations_iteration_fk"
            columns: ["tenant_id", "project_id", "iteration_id"]
            isOneToOne: false
            referencedRelation: "core_iterations"
            referencedColumns: ["tenant_id", "project_id", "id"]
          },
          {
            foreignKeyName: "core_team_iterations_team_fk"
            columns: ["tenant_id", "project_id", "team_id"]
            isOneToOne: false
            referencedRelation: "core_teams"
            referencedColumns: ["tenant_id", "project_id", "id"]
          },
        ]
      }
      core_team_memberships: {
        Row: {
          access_revoked_at: string | null
          created_at: string
          deleted_at_source: string | null
          id: string
          is_active: boolean
          is_deleted: boolean
          joined_at: string | null
          last_seen_at: string | null
          left_at: string | null
          member_id: string
          project_id: string
          role: string
          source_status: Database["public"]["Enums"]["source_status"]
          team_id: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          access_revoked_at?: string | null
          created_at?: string
          deleted_at_source?: string | null
          id?: string
          is_active?: boolean
          is_deleted?: boolean
          joined_at?: string | null
          last_seen_at?: string | null
          left_at?: string | null
          member_id: string
          project_id: string
          role?: string
          source_status?: Database["public"]["Enums"]["source_status"]
          team_id: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          access_revoked_at?: string | null
          created_at?: string
          deleted_at_source?: string | null
          id?: string
          is_active?: boolean
          is_deleted?: boolean
          joined_at?: string | null
          last_seen_at?: string | null
          left_at?: string | null
          member_id?: string
          project_id?: string
          role?: string
          source_status?: Database["public"]["Enums"]["source_status"]
          team_id?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_team_memberships_member_fk"
            columns: ["tenant_id", "member_id"]
            isOneToOne: false
            referencedRelation: "core_members"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "core_team_memberships_team_fk"
            columns: ["tenant_id", "project_id", "team_id"]
            isOneToOne: false
            referencedRelation: "core_teams"
            referencedColumns: ["tenant_id", "project_id", "id"]
          },
        ]
      }
      core_teams: {
        Row: {
          access_revoked_at: string | null
          area_paths: string[]
          azure_team_id: string
          azure_team_name: string
          created_at: string
          default_iteration_path: string | null
          deleted_at_source: string | null
          description: string | null
          id: string
          is_deleted: boolean
          last_seen_at: string | null
          last_synced_at: string | null
          name_ar: string
          name_en: string
          organization_id: string
          process_mapping_id: string | null
          project_id: string
          source_status: Database["public"]["Enums"]["source_status"]
          tenant_id: string
          updated_at: string
        }
        Insert: {
          access_revoked_at?: string | null
          area_paths?: string[]
          azure_team_id: string
          azure_team_name: string
          created_at?: string
          default_iteration_path?: string | null
          deleted_at_source?: string | null
          description?: string | null
          id?: string
          is_deleted?: boolean
          last_seen_at?: string | null
          last_synced_at?: string | null
          name_ar: string
          name_en: string
          organization_id: string
          process_mapping_id?: string | null
          project_id: string
          source_status?: Database["public"]["Enums"]["source_status"]
          tenant_id: string
          updated_at?: string
        }
        Update: {
          access_revoked_at?: string | null
          area_paths?: string[]
          azure_team_id?: string
          azure_team_name?: string
          created_at?: string
          default_iteration_path?: string | null
          deleted_at_source?: string | null
          description?: string | null
          id?: string
          is_deleted?: boolean
          last_seen_at?: string | null
          last_synced_at?: string | null
          name_ar?: string
          name_en?: string
          organization_id?: string
          process_mapping_id?: string | null
          project_id?: string
          source_status?: Database["public"]["Enums"]["source_status"]
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_teams_org_fk"
            columns: ["tenant_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "core_organizations"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "core_teams_project_fk"
            columns: ["tenant_id", "project_id"]
            isOneToOne: false
            referencedRelation: "core_projects"
            referencedColumns: ["tenant_id", "id"]
          },
        ]
      }
      core_tenant_retention_settings: {
        Row: {
          created_at: string
          id: string
          legal_hold: boolean
          minimum_days: number
          notes: string | null
          retention_days: number
          rule_key: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          legal_hold?: boolean
          minimum_days: number
          notes?: string | null
          retention_days: number
          rule_key: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          legal_hold?: boolean
          minimum_days?: number
          notes?: string | null
          retention_days?: number
          rule_key?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_tenant_retention_settings_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "core_tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      core_tenants: {
        Row: {
          created_at: string
          default_time_zone: string
          id: string
          is_active: boolean
          is_demo: boolean
          legal_hold: boolean
          name_ar: string
          name_en: string
          settings: Json
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          default_time_zone?: string
          id?: string
          is_active?: boolean
          is_demo?: boolean
          legal_hold?: boolean
          name_ar: string
          name_en: string
          settings?: Json
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          default_time_zone?: string
          id?: string
          is_active?: boolean
          is_demo?: boolean
          legal_hold?: boolean
          name_ar?: string
          name_en?: string
          settings?: Json
          slug?: string
          updated_at?: string
        }
        Relationships: []
      }
      core_user_project_scopes: {
        Row: {
          closed_reason: string | null
          created_at: string
          expires_at: string | null
          granted_at: string
          granted_by_user_id: string | null
          id: string
          idempotency_key: string | null
          project_id: string
          reason: string | null
          revoked_at: string | null
          tenant_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          closed_reason?: string | null
          created_at?: string
          expires_at?: string | null
          granted_at?: string
          granted_by_user_id?: string | null
          id?: string
          idempotency_key?: string | null
          project_id: string
          reason?: string | null
          revoked_at?: string | null
          tenant_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          closed_reason?: string | null
          created_at?: string
          expires_at?: string | null
          granted_at?: string
          granted_by_user_id?: string | null
          id?: string
          idempotency_key?: string | null
          project_id?: string
          reason?: string | null
          revoked_at?: string | null
          tenant_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_user_project_scopes_granted_by_fk"
            columns: ["tenant_id", "granted_by_user_id"]
            isOneToOne: false
            referencedRelation: "core_users"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "core_user_project_scopes_project_fk"
            columns: ["tenant_id", "project_id"]
            isOneToOne: false
            referencedRelation: "core_projects"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "core_user_project_scopes_user_fk"
            columns: ["tenant_id", "user_id"]
            isOneToOne: false
            referencedRelation: "core_users"
            referencedColumns: ["tenant_id", "id"]
          },
        ]
      }
      core_user_roles: {
        Row: {
          created_at: string
          granted_at: string
          granted_by_user_id: string | null
          id: string
          revoked_at: string | null
          role: Database["public"]["Enums"]["app_role"]
          tenant_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          granted_at?: string
          granted_by_user_id?: string | null
          id?: string
          revoked_at?: string | null
          role: Database["public"]["Enums"]["app_role"]
          tenant_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          granted_at?: string
          granted_by_user_id?: string | null
          id?: string
          revoked_at?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          tenant_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_user_roles_granted_by_fk"
            columns: ["tenant_id", "granted_by_user_id"]
            isOneToOne: false
            referencedRelation: "core_users"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "core_user_roles_user_fk"
            columns: ["tenant_id", "user_id"]
            isOneToOne: false
            referencedRelation: "core_users"
            referencedColumns: ["tenant_id", "id"]
          },
        ]
      }
      core_user_team_scopes: {
        Row: {
          closed_reason: string | null
          created_at: string
          expires_at: string | null
          granted_at: string
          granted_by_user_id: string | null
          id: string
          idempotency_key: string | null
          reason: string | null
          revoked_at: string | null
          team_id: string
          tenant_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          closed_reason?: string | null
          created_at?: string
          expires_at?: string | null
          granted_at?: string
          granted_by_user_id?: string | null
          id?: string
          idempotency_key?: string | null
          reason?: string | null
          revoked_at?: string | null
          team_id: string
          tenant_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          closed_reason?: string | null
          created_at?: string
          expires_at?: string | null
          granted_at?: string
          granted_by_user_id?: string | null
          id?: string
          idempotency_key?: string | null
          reason?: string | null
          revoked_at?: string | null
          team_id?: string
          tenant_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_user_team_scopes_granted_by_fk"
            columns: ["tenant_id", "granted_by_user_id"]
            isOneToOne: false
            referencedRelation: "core_users"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "core_user_team_scopes_team_fk"
            columns: ["tenant_id", "team_id"]
            isOneToOne: false
            referencedRelation: "core_teams"
            referencedColumns: ["tenant_id", "id"]
          },
          {
            foreignKeyName: "core_user_team_scopes_user_fk"
            columns: ["tenant_id", "user_id"]
            isOneToOne: false
            referencedRelation: "core_users"
            referencedColumns: ["tenant_id", "id"]
          },
        ]
      }
      core_users: {
        Row: {
          auth_user_id: string
          created_at: string
          display_name: string
          email: string
          id: string
          is_active: boolean
          last_seen_at: string | null
          locale: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          auth_user_id: string
          created_at?: string
          display_name: string
          email: string
          id?: string
          is_active?: boolean
          last_seen_at?: string | null
          locale?: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          auth_user_id?: string
          created_at?: string
          display_name?: string
          email?: string
          id?: string
          is_active?: boolean
          last_seen_at?: string | null
          locale?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "core_users_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "core_tenants"
            referencedColumns: ["id"]
          },
        ]
      }
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
