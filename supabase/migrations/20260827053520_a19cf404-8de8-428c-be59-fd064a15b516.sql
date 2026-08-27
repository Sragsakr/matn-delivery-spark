-- =====================================================================
-- Phase 3 migration 14 — global KPI catalog + development seed support
-- Rollback: DELETE FROM an_kpi_definitions WHERE calculation_version = 1;
--           SELECT public.remove_demo_tenant();
-- =====================================================================

INSERT INTO public.an_kpi_definitions
  (kpi_id, calculation_version, name_en, name_ar, category, unit, direction, formula, default_configuration)
VALUES
 ('sprint_confidence',1,'Sprint Confidence','ثقة السبرنت','overview','percent','higherIsBetter','weighted sum of nine normalized components','{"healthy":75,"warning":50}'),
 ('scope_completion',1,'Scope Completion','إنجاز النطاق','overview','percent','higherIsBetter','completedCommittedEstimate / currentCommittedEstimate * 100','{"healthy":90,"warning":70}'),
 ('expected_completion',1,'Expected Completion','الإنجاز المتوقع','overview','percent','targetBand','elapsedWorkingDays / totalWorkingDays * 100','{"tolerance":10}'),
 ('scope_change',1,'Scope Change','تغيّر النطاق','overview','percent','lowerIsBetter','(currentScopeEstimate - originalScopeEstimate) / originalScopeEstimate * 100','{"healthy":5,"warning":15}'),
 ('critical_blockers',1,'Critical Blockers','العوائق الحرجة','overview','count','lowerIsBetter','count(blocked AND inProgress AND severity in (critical,high))','{"healthy":0,"warning":2}'),
 ('release_readiness',1,'Release Readiness','جاهزية الإصدار','overview','percent','higherIsBetter','weighted gate composite','{"healthy":85,"warning":60}'),
 ('forecasted_completion',1,'Forecasted Completion','الإنجاز المتوقع نهاية السبرنت','flow','percent','higherIsBetter','completedEstimate + avgDailyCompletion * remainingWorkingDays','{"healthy":95,"warning":80}'),
 ('velocity',1,'Velocity','السرعة','flow','points','higherIsBetter','mean(completedEstimate) over last N iterations','{"window":3}'),
 ('burndown',1,'Burndown','مخطط الإنجاز المتناقص','flow','series','lowerIsBetter','remainingEstimate per working day vs ideal','{}'),
 ('burnup',1,'Burnup','مخطط الإنجاز المتزايد','flow','series','higherIsBetter','completedEstimate and scopeEstimate per working day','{}'),
 ('cycle_time',1,'Cycle Time','زمن الدورة','flow','days','lowerIsBetter','median(closedDate - activatedDate)','{"healthy":5,"warning":10}'),
 ('lead_time',1,'Lead Time','زمن التسليم','flow','days','lowerIsBetter','median(closedDate - createdAtSource)','{"healthy":15,"warning":30}'),
 ('throughput',1,'Throughput','معدل الإنجاز','flow','count','higherIsBetter','count(items completed) / weeks','{}'),
 ('work_in_progress',1,'Work In Progress','العمل الجاري','flow','count','lowerIsBetter','count(items inProgress)','{"perMemberHealthy":2,"perMemberWarning":3}'),
 ('flow_efficiency',1,'Flow Efficiency','كفاءة التدفق','flow','percent','higherIsBetter','activeTime / (activeTime + waitTime) * 100','{"healthy":40,"warning":25}'),
 ('blocked_work_age',1,'Blocked Work Age','عمر العمل المعطّل','flow','days','lowerIsBetter','now - blockedTransitionTimestamp','{"healthy":2,"warning":5}'),
 ('scope_added',1,'Scope Added','نطاق مضاف','scope','percent','lowerIsBetter','sum(estimateAtChange where added after start)','{"healthy":5,"warning":15}'),
 ('scope_removed',1,'Scope Removed','نطاق مُزال','scope','percent','lowerIsBetter','sum(estimateAtChange where removed after start)','{"healthy":5,"warning":15}'),
 ('planned_vs_completed_points',1,'Planned vs Completed','المخطط مقابل المنجز','scope','percent','higherIsBetter','completedEstimate vs originalCommittedEstimate','{"healthy":90,"warning":70}'),
 ('capacity_utilization',1,'Capacity Utilization','استغلال الطاقة','team','percent','targetBand','assignedRemainingHours / availableCapacityHours * 100','{"bandLow":71,"bandHigh":95,"warnHigh":110}'),
 ('pr_review_time',1,'PR Review Time','زمن مراجعة الطلبات','engineering','hours','lowerIsBetter','median(firstMeaningfulReviewAt - createdAtSource)','{"healthy":8,"warning":24}'),
 ('stale_pull_requests',1,'Stale Pull Requests','طلبات دمج راكدة','engineering','count','lowerIsBetter','count(PRs matching stale policy)','{"healthy":1,"warning":4}'),
 ('build_success_rate',1,'Build Success Rate','نجاح البناء','engineering','percent','higherIsBetter','successfulCompletedBuilds / completedBuilds * 100','{"healthy":90,"warning":75}'),
 ('deployment_frequency',1,'Deployment Frequency','تكرار النشر','engineering','count','higherIsBetter','count(successful production deployments) / weeks','{"healthy":3,"warning":1}'),
 ('deployment_failure_rate',1,'Deployment Failure Rate','نسبة فشل النشر','engineering','percent','lowerIsBetter','failedDeployments / totalDeployments * 100','{"healthy":10,"warning":25}'),
 ('failed_tests',1,'Failed Tests','اختبارات فاشلة','engineering','count','lowerIsBetter','sum(failedTests) in window','{"healthy":0,"warning":5}'),
 ('test_pass_rate',1,'Test Pass Rate','نسبة نجاح الاختبارات','engineering','percent','higherIsBetter','passedTests / executedTests * 100','{"healthy":98,"warning":90}'),
 ('items_without_owner',1,'Items Without Owner','عناصر بلا مسؤول','quality','count','lowerIsBetter','count(active items where assignee is null)','{"healthy":0,"warning":3}'),
 ('items_without_estimate',1,'Items Without Estimate','عناصر بلا تقدير','quality','percent','lowerIsBetter','count(committed items where estimate is null)','{"healthy":5,"warning":20}'),
 ('reopened_bugs',1,'Reopened Bugs','أخطاء أُعيد فتحها','quality','count','lowerIsBetter','count(bugs with reopen transitions)','{"healthy":0,"warning":3}'),
 ('bug_age',1,'Bug Age','عمر الأخطاء','quality','days','lowerIsBetter','median(now - createdAtSource) for open bugs','{"healthy":14,"warning":30}'),
 ('escaped_defects',1,'Escaped Defects','عيوب متسرّبة','quality','count','lowerIsBetter','count(bugs created after release in window)','{"healthy":0,"warning":2}'),
 ('data_freshness',1,'Data Freshness','حداثة البيانات','governance','minutes','lowerIsBetter','now - lastSuccessfulSyncAt','{"healthy":60,"warning":240}'),
 ('sync_health',1,'Sync Health','سلامة المزامنة','governance','percent','higherIsBetter','successfulRuns / totalRuns * 100','{"healthy":95,"warning":80}')
ON CONFLICT (kpi_id, calculation_version) DO NOTHING;

-- ---------------------------------------------------------------------
-- Development seed. Clearly fake data only. Production stays empty:
-- the routine refuses to run when any non-demo tenant already exists.
-- Placeholder auth uuids are documented fakes; no real sign-in account
-- exists for them until a developer links one.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seed_demo_tenant()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  t_id  uuid := '11111111-1111-4111-8111-111111111111';
  org_id uuid := '11111111-1111-4111-8111-111111111112';
  proj_id uuid := '11111111-1111-4111-8111-111111111113';
  team_id uuid := '11111111-1111-4111-8111-111111111114';
  iter_id uuid := '11111111-1111-4111-8111-111111111115';
  ti_id   uuid := '11111111-1111-4111-8111-111111111116';
  admin_id uuid := '11111111-1111-4111-8111-111111111121';
  dm_id    uuid := '11111111-1111-4111-8111-111111111122';
  exec_id  uuid := '11111111-1111-4111-8111-111111111123';
BEGIN
  IF EXISTS (SELECT 1 FROM public.core_tenants WHERE is_demo = false) THEN
    RAISE NOTICE 'real tenant present; demo seed skipped';
    RETURN NULL;
  END IF;

  INSERT INTO public.core_tenants (id, slug, name_en, name_ar, is_demo)
  VALUES (t_id, 'matn-demo', 'MATN Demo (sample data)', 'متن التجريبي — بيانات تجريبية', true)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.core_tenant_retention_settings (tenant_id, rule_key, retention_days, minimum_days)
  VALUES
    (t_id,'work_item_revisions',1095,1095),
    (t_id,'daily_project_snapshots',1095,1095),
    (t_id,'daily_team_snapshots',1095,1095),
    (t_id,'daily_iteration_snapshots',1095,1095),
    (t_id,'daily_member_snapshots',548,365),
    (t_id,'raw_payloads',30,7),
    (t_id,'sync_runs',180,30),
    (t_id,'audit_events',730,730),
    (t_id,'copilot_answers',180,30)
  ON CONFLICT (tenant_id, rule_key) DO NOTHING;

  INSERT INTO public.core_organizations (id, tenant_id, azure_organization_name, base_url, name_en, name_ar)
  VALUES (org_id, t_id, 'demo-org', 'https://dev.azure.invalid/demo-org', 'Demo Organization', 'المنظمة التجريبية')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.core_projects (id, tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar, process_template_kind)
  VALUES (proj_id, t_id, org_id, 'demo-project-0001', 'Demo Delivery', 'Demo Delivery', 'التسليم التجريبي', 'agile')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.core_teams (id, tenant_id, organization_id, project_id, azure_team_id, azure_team_name, name_en, name_ar, area_paths)
  VALUES (team_id, t_id, org_id, proj_id, 'demo-team-0001', 'Demo Team', 'Demo Team', 'الفريق التجريبي', ARRAY['Demo Delivery\\Team'])
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.core_iterations (id, tenant_id, organization_id, project_id, azure_iteration_id, azure_iteration_path, name_en, name_ar, start_date, finish_date, phase)
  VALUES (iter_id, t_id, org_id, proj_id, 'demo-iteration-0001', 'Demo Delivery\\Sprint 1', 'Sprint 1', 'السبرنت الأول',
          (current_date - 6), (current_date + 7), 'current')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.core_team_iterations (id, tenant_id, organization_id, project_id, team_id, iteration_id, is_current, phase)
  VALUES (ti_id, t_id, org_id, proj_id, team_id, iter_id, true, 'current')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.core_members (id, tenant_id, organization_id, azure_descriptor, display_name, email)
  VALUES
    ('11111111-1111-4111-8111-111111111131', t_id, org_id, 'demo.descriptor.one', 'Demo Member One', 'member.one@example.invalid'),
    ('11111111-1111-4111-8111-111111111132', t_id, org_id, 'demo.descriptor.two', 'Demo Member Two', 'member.two@example.invalid')
  ON CONFLICT (id) DO NOTHING;

  -- Placeholder application users. auth_user_id values are fake and must be
  -- replaced with a real auth uuid before a developer can sign in as them.
  INSERT INTO public.core_users (id, tenant_id, auth_user_id, email, display_name)
  VALUES
    (admin_id, t_id, '11111111-1111-4111-8111-1111111111a1', 'demo.admin@example.invalid', 'Demo Tenant Admin'),
    (dm_id,    t_id, '11111111-1111-4111-8111-1111111111a2', 'demo.dm@example.invalid',    'Demo Delivery Manager'),
    (exec_id,  t_id, '11111111-1111-4111-8111-1111111111a3', 'demo.exec@example.invalid',  'Demo Executive Viewer')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.core_user_roles (tenant_id, user_id, role)
  VALUES
    (t_id, admin_id, 'tenant_admin'),
    (t_id, dm_id,    'delivery_manager'),
    (t_id, exec_id,  'executive_viewer')
  ON CONFLICT (tenant_id, user_id, role) DO NOTHING;

  INSERT INTO public.core_user_project_scopes (tenant_id, user_id, project_id, granted_by_user_id, reason)
  VALUES (t_id, dm_id, proj_id, admin_id, 'demo seed')
  ON CONFLICT DO NOTHING;

  PERFORM public.write_audit_event(t_id, NULL, 'seed.demo_tenant', 'core_tenants', t_id,
    'success'::public.audit_outcome, 'seed-demo-v1', '{"labelled":"demo"}'::jsonb);

  RETURN t_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_demo_tenant()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  DELETE FROM public.core_tenants WHERE is_demo = true;
$$;

REVOKE ALL ON FUNCTION public.seed_demo_tenant() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.remove_demo_tenant() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.seed_demo_tenant() TO service_role;
GRANT EXECUTE ON FUNCTION public.remove_demo_tenant() TO service_role;

-- Development environment: create the demo tenant now.
SELECT public.seed_demo_tenant();