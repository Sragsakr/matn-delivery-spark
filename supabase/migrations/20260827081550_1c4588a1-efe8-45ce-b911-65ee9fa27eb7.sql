DROP TRIGGER IF EXISTS immutable_identity ON public.core_projects;
CREATE TRIGGER immutable_identity
  BEFORE UPDATE ON public.core_projects
  FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change('tenant_id', 'organization_id', 'azure_project_id');