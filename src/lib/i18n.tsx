import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

export type Locale = "ar" | "en";

type Dict = Record<string, { ar: string; en: string }>;

export const dictionary = {
  "brand.name": { ar: "متن", en: "MATN" },
  "brand.tagline": { ar: "ذكاء التسليم", en: "Delivery Intelligence" },
  "brand.workspace": { ar: "مساحة العمل", en: "Workspace" },

  "nav.overview": { ar: "النظرة العامة", en: "Overview" },
  "nav.delivery": { ar: "التسليم", en: "Delivery" },
  "nav.team": { ar: "الفريق", en: "Team" },
  "nav.engineering": { ar: "الهندسة", en: "Engineering" },
  "nav.intelligence": { ar: "الذكاء التحليلي", en: "Intelligence" },

  "shell.collapse": { ar: "طيّ القائمة", en: "Collapse sidebar" },
  "shell.expand": { ar: "توسيع القائمة", en: "Expand sidebar" },
  "shell.organization": { ar: "المؤسسة", en: "Organization" },
  "shell.project": { ar: "المشروع", en: "Project" },
  "shell.team": { ar: "الفريق", en: "Team" },
  "shell.sprint": { ar: "السبرنت", en: "Sprint" },
  "shell.language": { ar: "اللغة", en: "Language" },
  "shell.theme": { ar: "المظهر", en: "Theme" },
  "shell.theme.light": { ar: "فاتح", en: "Light" },
  "shell.theme.dark": { ar: "داكن", en: "Dark" },
  "shell.refresh": { ar: "تحديث البيانات", en: "Refresh data" },
  "shell.lastSync": { ar: "آخر مزامنة", en: "Last sync" },
  "shell.freshness.fresh": { ar: "البيانات محدّثة", en: "Data is current" },
  "shell.freshness.stale": { ar: "البيانات قديمة", en: "Data is stale" },
  "shell.freshness.partial": { ar: "بيانات جزئية", en: "Partial data" },
  "shell.freshness.error": { ar: "تعذّرت المزامنة", en: "Sync failed" },
  "shell.profile": { ar: "الملف الشخصي", en: "Profile" },
  "shell.settings": { ar: "الإعدادات", en: "Settings" },
  "shell.signout": { ar: "تسجيل الخروج", en: "Sign out" },
  "shell.filters": { ar: "عوامل التصفية", en: "Filters" },
  "shell.menu": { ar: "القائمة", en: "Menu" },

  "overview.title": { ar: "النظرة التنفيذية على التسليم", en: "Delivery Command Overview" },
  "overview.subtitle": {
    ar: "قراءة واحدة لحالة السبرنت والمخاطر والإجراءات المطلوبة اليوم.",
    en: "One read on sprint health, risks, and the actions that matter today.",
  },
  "overview.sprintDay": { ar: "اليوم {a} من {b}", en: "Day {a} of {b}" },
  "overview.askCopilot": { ar: "اسأل مساعد التسليم", en: "Ask Delivery Copilot" },
  "overview.copilotSoon": {
    ar: "مساعد التسليم سيتوفّر في المرحلة القادمة بعد ربط Azure DevOps.",
    en: "Delivery Copilot arrives in the next phase, after Azure DevOps is connected.",
  },

  "kpi.confidence": { ar: "ثقة السبرنت", en: "Sprint Confidence" },
  "kpi.confidence.help": {
    ar: "احتمال إغلاق نطاق السبرنت في موعده اعتماداً على السرعة والمخاطر المفتوحة.",
    en: "Likelihood the sprint scope closes on time, based on velocity and open risks.",
  },
  "kpi.confidence.explain": {
    ar: "الثقة منخفضة بسبب تغيّر النطاق والمعوّقات المفتوحة.",
    en: "Confidence is down due to scope change and open blockers.",
  },
  "kpi.scope": { ar: "إنجاز النطاق", en: "Scope Completion" },
  "kpi.scope.help": {
    ar: "نسبة نقاط العمل المكتملة من إجمالي النطاق الحالي.",
    en: "Share of story points completed against the current committed scope.",
  },
  "kpi.scope.explain": {
    ar: "الإنجاز متأخر ١١ نقطة عن المسار المتوقع لليوم السابع.",
    en: "Delivery is 11 points behind the expected line for day 7.",
  },
  "kpi.expected": { ar: "الإنجاز المتوقّع اليوم", en: "Expected Completion" },
  "kpi.expected.help": {
    ar: "النسبة التي كان يفترض بلوغها في هذا اليوم من السبرنت.",
    en: "The completion level the sprint should have reached by today.",
  },
  "kpi.expected.explain": {
    ar: "خط مرجعي محسوب من خطة السبرنت وسعة الفريق.",
    en: "Baseline derived from the sprint plan and team capacity.",
  },
  "kpi.scopeChange": { ar: "تغيّر النطاق", en: "Scope Change" },
  "kpi.scopeChange.help": {
    ar: "حجم العمل المضاف أو المزال بعد بدء السبرنت.",
    en: "Work added or removed after the sprint started.",
  },
  "kpi.scopeChange.explain": {
    ar: "أُضيفت ثلاثة عناصر بعد بدء السبرنت دون إزالة ما يقابلها.",
    en: "Three items were added mid-sprint with nothing traded out.",
  },
  "kpi.blockers": { ar: "المعوّقات الحرجة", en: "Critical Blockers" },
  "kpi.blockers.help": {
    ar: "عناصر عمل متوقفة وتؤثر مباشرة على مسار السبرنت.",
    en: "Stopped work items that directly threaten the sprint outcome.",
  },
  "kpi.blockers.explain": {
    ar: "معوّقان منهما مفتوحان لأكثر من أربعة أيام.",
    en: "Two of them have been open for more than four days.",
  },
  "kpi.release": { ar: "جاهزية الإصدار", en: "Release Readiness" },
  "kpi.release.help": {
    ar: "مؤشر مركّب من الاختبارات والنشر والتوثيق وقبول الأعمال.",
    en: "Composite of testing, deployment, documentation, and business sign-off.",
  },
  "kpi.release.explain": {
    ar: "الاختبار التنظيمي والتوثيق ما زالا غير مكتملين.",
    en: "Regression testing and release notes are still incomplete.",
  },
  "kpi.vsPrevious": { ar: "مقارنة بالسبرنت السابق", en: "vs previous sprint" },
  "kpi.target": { ar: "المستهدف", en: "Target" },
  "kpi.openDetails": { ar: "عرض التفاصيل", en: "View details" },
  "kpi.whatChanged": { ar: "ما الذي تغيّر", en: "What changed" },
  "kpi.howCalculated": { ar: "طريقة الاحتساب", en: "How it is calculated" },
  "kpi.relatedItems": { ar: "عناصر العمل المرتبطة", en: "Related work items" },
  "kpi.trend": { ar: "اتجاه آخر خمسة سبرنتات", en: "Last five sprints" },

  "status.healthy": { ar: "سليم", en: "Healthy" },
  "status.atRisk": { ar: "معرّض للخطر", en: "At risk" },
  "status.critical": { ar: "حرج", en: "Critical" },
  "status.neutral": { ar: "محايد", en: "Neutral" },
  "status.onTrack": { ar: "على المسار", en: "On track" },
  "status.watch": { ar: "مراقبة", en: "Watch" },

  "trajectory.title": { ar: "مسار السبرنت", en: "Sprint Trajectory" },
  "trajectory.subtitle": {
    ar: "الإنجاز الفعلي مقابل المتوقع مع نطاق ثقة للتنبؤ.",
    en: "Actual against expected progress with a forecast confidence range.",
  },
  "trajectory.actual": { ar: "الفعلي", en: "Actual" },
  "trajectory.expected": { ar: "المتوقع", en: "Expected" },
  "trajectory.forecast": { ar: "التنبؤ", en: "Forecast" },
  "trajectory.range": { ar: "نطاق الثقة", en: "Confidence range" },
  "trajectory.start": { ar: "بداية السبرنت", en: "Sprint start" },
  "trajectory.end": { ar: "نهاية السبرنت", en: "Sprint end" },
  "trajectory.forecastLabel": { ar: "الإغلاق المتوقع", en: "Forecast close" },
  "trajectory.day": { ar: "اليوم", en: "Day" },

  "risks.title": { ar: "أهم المخاطر", en: "Critical Risks" },
  "risks.subtitle": { ar: "مرتّبة حسب الأثر على تاريخ التسليم.", en: "Ordered by impact on the delivery date." },
  "risks.owner": { ar: "المسؤول", en: "Owner" },
  "risks.age": { ar: "العمر", en: "Age" },
  "risks.days": { ar: "{a} يوم", en: "{a} days" },
  "risks.items": { ar: "عناصر متأثرة", en: "Affected items" },
  "risks.why": { ar: "سبب الخطر", en: "Why this is a risk" },
  "risks.action": { ar: "الإجراء الموصى به", en: "Recommended action" },
  "risks.openAdo": { ar: "فتح في Azure DevOps", en: "Open in Azure DevOps" },
  "risks.adoDisabled": {
    ar: "سيتاح بعد ربط Azure DevOps",
    en: "Available after Azure DevOps is connected",
  },
  "risks.viewAll": { ar: "عرض كل المخاطر", en: "View all risks" },
  "risks.adoSoon": {
    ar: "الربط مع Azure DevOps يفعّل هذا الرابط لاحقاً.",
    en: "This link activates once Azure DevOps is connected.",
  },

  "funnel.title": { ar: "مسار التسليم", en: "Delivery Funnel" },
  "funnel.subtitle": { ar: "توزيع عناصر العمل على مراحل التنفيذ.", en: "Work item distribution across execution stages." },
  "funnel.backlog": { ar: "قائمة الأعمال", en: "Backlog" },
  "funnel.ready": { ar: "جاهز", en: "Ready" },
  "funnel.development": { ar: "التطوير", en: "Development" },
  "funnel.review": { ar: "المراجعة", en: "Review" },
  "funnel.testing": { ar: "الاختبار", en: "Testing" },
  "funnel.done": { ar: "مكتمل", en: "Done" },
  "funnel.items": { ar: "عنصر", en: "items" },
  "funnel.aging": { ar: "متوسط المكوث", en: "Avg. time in stage" },

  "team.title": { ar: "حِمل الفريق", en: "Team Load" },
  "team.subtitle": {
    ar: "توزيع العمل مقابل السعة المتاحة، دون ترتيب للأفراد.",
    en: "Work distribution against available capacity, with no individual ranking.",
  },
  "team.member": { ar: "عضو الفريق", en: "Team member" },
  "team.capacity": { ar: "السعة", en: "Capacity" },
  "team.assigned": { ar: "المُسند", en: "Assigned" },
  "team.active": { ar: "قيد العمل", en: "Active" },
  "team.blocked": { ar: "متوقف", en: "Blocked" },
  "team.utilization": { ar: "مؤشر الاستخدام", en: "Utilization" },
  "team.role": { ar: "الدور", en: "Role" },
  "team.signal.over": { ar: "فوق السعة", en: "Over capacity" },
  "team.signal.balanced": { ar: "متوازن", en: "Balanced" },
  "team.signal.under": { ar: "دون السعة", en: "Under capacity" },
  "team.hours": { ar: "ساعة", en: "h" },

  "eng.title": { ar: "الصحة الهندسية", en: "Engineering Health" },
  "eng.subtitle": { ar: "إشارات المراجعة والبناء والنشر.", en: "Review, build, and deployment signals." },
  "eng.activePrs": { ar: "طلبات الدمج النشطة", en: "Active pull requests" },
  "eng.stalePrs": { ar: "طلبات دمج راكدة", en: "Stale pull requests" },
  "eng.reviewTime": { ar: "وسيط زمن المراجعة", en: "Median review time" },
  "eng.buildRate": { ar: "نجاح عمليات البناء", en: "Build success rate" },
  "eng.failedTests": { ar: "اختبارات فاشلة", en: "Failed tests" },
  "eng.deployment": { ar: "حالة النشر", en: "Deployment status" },
  "eng.deploy.blocked": { ar: "النشر متوقف", en: "Deployment blocked" },
  "eng.deploy.note": { ar: "آخر نشر ناجح إلى بيئة الاختبار قبل ١٩ ساعة.", en: "Last successful staging deploy 19 hours ago." },
  "eng.hours": { ar: "ساعة", en: "h" },

  "actions.title": { ar: "الإجراءات الموصى بها", en: "Recommended Actions" },
  "actions.subtitle": { ar: "مرتّبة حسب الأثر المتوقع على السبرنت.", en: "Ranked by expected impact on the sprint." },
  "actions.impact": { ar: "الأثر المتوقع", en: "Expected impact" },
  "actions.reason": { ar: "السبب", en: "Reason" },
  "actions.items": { ar: "عناصر مرتبطة", en: "Related items" },
  "actions.accept": { ar: "إضافة إلى خطة اليوم", en: "Add to today’s plan" },
  "actions.dismiss": { ar: "إخفاء الاقتراح", en: "Hide suggestion" },
  "actions.inspect": { ar: "فحص التفاصيل", en: "Inspect details" },
  "actions.accepted": { ar: "أُضيف الاقتراح إلى خطة اليوم", en: "Added to today’s plan" },
  "actions.dismissed": { ar: "أُخفي الاقتراح", en: "Suggestion hidden" },
  "actions.notSynced": {
    ar: "التغيير محفوظ محلياً فقط ولم يُزامن مع Azure DevOps بعد.",
    en: "Saved locally only; not yet synchronized with Azure DevOps.",
  },
  "actions.empty": { ar: "لا توجد إجراءات معلّقة الآن.", en: "No pending actions right now." },
  "actions.priority": { ar: "الأولوية {a}", en: "Priority {a}" },

  "state.loading": { ar: "جارٍ تحميل البيانات", en: "Loading data" },
  "state.empty.title": { ar: "لا توجد بيانات لعرضها", en: "Nothing to show yet" },
  "state.empty.body": {
    ar: "غيّر عوامل التصفية أو انتظر المزامنة القادمة.",
    en: "Adjust the filters or wait for the next synchronization.",
  },
  "state.error.title": { ar: "تعذّر تحميل هذا القسم", en: "This section failed to load" },
  "state.error.body": {
    ar: "حدث خطأ أثناء قراءة بيانات التسليم. حاول التحديث.",
    en: "Something went wrong while reading delivery data. Try refreshing.",
  },
  "state.retry": { ar: "إعادة المحاولة", en: "Retry" },
  "state.stale.title": { ar: "البيانات المعروضة قديمة", en: "You are viewing stale data" },
  "state.stale.body": {
    ar: "آخر مزامنة ناجحة قبل {a}. القيم قد لا تعكس الوضع الحالي.",
    en: "Last successful sync was {a} ago. Values may not reflect the current state.",
  },
  "state.partial.title": { ar: "بيانات جزئية", en: "Partial data" },
  "state.partial.body": {
    ar: "بعض مصادر الاختبار لم تُزامن بعد، لذلك جاهزية الإصدار تقديرية.",
    en: "Some test sources have not synced, so release readiness is an estimate.",
  },
  "state.mock": { ar: "بيانات تجريبية", en: "Mock data" },

  "placeholder.badge": { ar: "قيد الإعداد", en: "In progress" },
  "placeholder.body": {
    ar: "هذه المساحة جاهزة هيكلياً وستُملأ بعد اكتمال ربط Azure DevOps.",
    en: "The structure is in place and will be populated once Azure DevOps is connected.",
  },
  "placeholder.planned": { ar: "المخطط لهذه الصفحة", en: "Planned for this page" },

  "delivery.title": { ar: "التسليم", en: "Delivery" },
  "delivery.subtitle": { ar: "تتبّع النطاق والتدفق والالتزامات عبر السبرنتات.", en: "Track scope, flow, and commitments across sprints." },
  "delivery.p1": { ar: "تحليل تدفّق العمل وزمن الدورة", en: "Flow and cycle-time analysis" },
  "delivery.p2": { ar: "سجل تغيّرات النطاق", en: "Scope change ledger" },
  "delivery.p3": { ar: "التزامات الإصدار والمعالم", en: "Release and milestone commitments" },

  "teamPage.title": { ar: "الفريق", en: "Team" },
  "teamPage.subtitle": { ar: "السعة والتوزيع وأنماط التعاون.", en: "Capacity, distribution, and collaboration patterns." },
  "teamPage.p1": { ar: "تخطيط السعة لكل سبرنت", en: "Per-sprint capacity planning" },
  "teamPage.p2": { ar: "توزيع العمل ونقاط الاختناق", en: "Work distribution and bottlenecks" },
  "teamPage.p3": { ar: "أنماط المراجعة والتعاون", en: "Review and collaboration patterns" },

  "engPage.title": { ar: "الهندسة", en: "Engineering" },
  "engPage.subtitle": { ar: "جودة الشيفرة وخطوط البناء والنشر.", en: "Code quality, pipelines, and deployments." },
  "engPage.p1": { ar: "صحة خطوط البناء", en: "Pipeline health" },
  "engPage.p2": { ar: "زمن مراجعة طلبات الدمج", en: "Pull request review latency" },
  "engPage.p3": { ar: "استقرار الاختبارات والانحدار", en: "Test stability and regressions" },

  "intel.title": { ar: "الذكاء التحليلي", en: "Intelligence" },
  "intel.subtitle": { ar: "تفسيرات وتنبؤات ومساعد التسليم.", en: "Explanations, forecasts, and the delivery copilot." },
  "intel.p1": { ar: "تفسير أسباب تعثّر السبرنت", en: "Root-cause explanation for sprint slippage" },
  "intel.p2": { ar: "سيناريوهات ماذا لو", en: "What-if scenarios" },
  "intel.p3": { ar: "مساعد التسليم بالحوار", en: "Conversational delivery copilot" },

  "kpi.primary": { ar: "المؤشّر الرئيسي", en: "Primary KPI" },

  "trajectory.summary": {
    ar: "في اليوم {a} من {b}: الإنجاز الفعلي {c}% مقابل خط متوقّع عند {d}%، والإغلاق المتوقّع {e}% ضمن نطاق ثقة من {f}% إلى {g}%.",
    en: "Day {a} of {b}: actual completion {c}% against an expected line of {d}%; forecast close {e}% within a confidence range of {f}% to {g}%.",
  },
  "trajectory.today": { ar: "اليوم الحالي", en: "Today" },
  "trajectory.chartLabel": { ar: "رسم بياني لمسار السبرنت", en: "Sprint trajectory chart" },

  "dev.state": { ar: "حالة العرض", en: "Interface state" },
  "dev.state.normal": { ar: "عادي", en: "Normal" },
  "dev.state.loading": { ar: "تحميل", en: "Loading" },
  "dev.state.empty": { ar: "فارغ", en: "Empty" },
  "dev.state.error": { ar: "خطأ", en: "Error" },
  "dev.state.stale": { ar: "بيانات قديمة", en: "Stale data" },
  "dev.state.partial": { ar: "بيانات جزئية", en: "Partial data" },
  "dev.only": { ar: "أداة تطوير فقط", en: "Development tool only" },

  "common.close": { ar: "إغلاق", en: "Close" },
  "common.viewAll": { ar: "عرض الكل", en: "View all" },
  "common.minutes": { ar: "منذ {a} دقيقة", en: "{a} min ago" },
  "common.of": { ar: "من", en: "of" },

  "nav.settings": { ar: "الإعدادات", en: "Settings" },

  "auth.title": { ar: "تسجيل الدخول", en: "Sign in" },
  "auth.subtitle": {
    ar: "الدخول مطلوب لإدارة اتصال Azure DevOps.",
    en: "Sign in to manage the Azure DevOps connection.",
  },
  "auth.email": { ar: "البريد الإلكتروني", en: "Email" },
  "auth.password": { ar: "كلمة المرور", en: "Password" },
  "auth.submit": { ar: "دخول", en: "Sign in" },
  "auth.pending": { ar: "جارٍ الدخول…", en: "Signing in…" },
  "auth.failed": { ar: "تعذّر تسجيل الدخول. تحقّق من البيانات وحاول مجددًا.", en: "Sign-in failed. Check your details and try again." },
  "auth.mode.signIn": { ar: "تسجيل الدخول", en: "Sign in" },
  "auth.mode.signUp": { ar: "إنشاء حساب", en: "Sign up" },
  "auth.signUp.submit": { ar: "إنشاء الحساب", en: "Create account" },
  "auth.signUp.pending": { ar: "جارٍ إنشاء الحساب…", en: "Creating account…" },
  "auth.signUp.subtitle": {
    ar: "أنشئ حسابك لإدارة مساحة العمل واتصال Azure DevOps.",
    en: "Create your account to manage the workspace and the Azure DevOps connection.",
  },
  "auth.signUp.checkEmail": {
    ar: "تم إرسال رسالة تأكيد إلى بريدك الإلكتروني. افتح الرابط ثم عد لتسجيل الدخول.",
    en: "A confirmation email has been sent. Open the link, then return here to sign in.",
  },
  "auth.signUp.failed": {
    ar: "تعذّر إنشاء الحساب. قد يكون البريد مستخدمًا أو كلمة المرور ضعيفة.",
    en: "Sign-up failed. The email may already be in use, or the password is too weak.",
  },
  "auth.unverified": {
    ar: "لم يتم تأكيد بريدك الإلكتروني بعد. افتح رابط التأكيد في بريدك ثم حدّث الصفحة.",
    en: "Your email is not verified yet. Open the confirmation link in your inbox, then refresh.",
  },
  "auth.signOut": { ar: "تسجيل الخروج", en: "Sign out" },

  "onboarding.title": { ar: "إنشاء مساحة العمل", en: "Create workspace" },
  "onboarding.subtitle": {
    ar: "لا توجد مساحة عمل بعد. أنشئ المساحة الأولى وستصبح مسؤولها.",
    en: "No workspace exists yet. Create the first one and you become its administrator.",
  },
  "onboarding.name": { ar: "اسم مساحة العمل", en: "Workspace name" },
  "onboarding.slug": { ar: "المعرّف المختصر", en: "Workspace slug" },
  "onboarding.slugHint": {
    ar: "حروف إنجليزية صغيرة وأرقام وشرطات فقط.",
    en: "Lowercase letters, numbers and hyphens only.",
  },
  "onboarding.submit": { ar: "إنشاء", en: "Create" },
  "onboarding.pending": { ar: "جارٍ الإنشاء…", en: "Creating…" },
  "onboarding.checking": { ar: "جارٍ التحقق…", en: "Checking…" },
  "onboarding.needsInvite": {
    ar: "حسابك يحتاج إلى دعوة من مسؤول مساحة العمل.",
    en: "Your account needs an invitation from the workspace administrator.",
  },
  "onboarding.error.tenant_exists": {
    ar: "توجد مساحة عمل بالفعل. حسابك يحتاج إلى دعوة من مسؤول مساحة العمل.",
    en: "A workspace already exists. Your account needs an invitation from the workspace administrator.",
  },
  "onboarding.error.already_member": {
    ar: "حسابك مرتبط بمساحة عمل بالفعل.",
    en: "Your account already belongs to a workspace.",
  },
  "onboarding.error.already_provisioned": {
    ar: "تم تعيين مسؤول أولي بالفعل.",
    en: "An initial administrator has already been provisioned.",
  },
  "onboarding.error.email_unverified": {
    ar: "لم يتم تأكيد بريدك الإلكتروني بعد.",
    en: "Your email is not verified yet.",
  },
  "onboarding.error.unauthenticated": {
    ar: "الجلسة غير صالحة. سجّل الدخول مجددًا.",
    en: "Invalid session. Please sign in again.",
  },
  "onboarding.error.invalid_name": { ar: "اسم غير صالح.", en: "Invalid workspace name." },
  "onboarding.error.invalid_slug": { ar: "معرّف غير صالح.", en: "Invalid workspace slug." },
  "onboarding.error.invalid_identity": { ar: "هوية غير صالحة.", en: "Invalid identity." },
  "onboarding.error.unknown": { ar: "تعذّر إكمال العملية.", en: "The operation could not be completed." },


  "azure.title": { ar: "اتصال Azure DevOps", en: "Azure DevOps Connection" },
  "azure.subtitle": {
    ar: "تحقّق من الاتصال، واستكشف المشاريع، وشغّل مزامنة الأساس. جميع العمليات للقراءة فقط.",
    en: "Verify the connection, discover projects, and run the foundation sync. All operations are read-only.",
  },
  "azure.organization": { ar: "المؤسسة", en: "Organization" },
  "azure.status": { ar: "حالة الاتصال", en: "Connection status" },
  "azure.status.unconfigured": { ar: "غير مهيّأ", en: "Not configured" },
  "azure.status.pending": { ar: "بانتظار التحقّق", en: "Awaiting verification" },
  "azure.status.connected": { ar: "متصل", en: "Connected" },
  "azure.status.error": { ar: "يوجد خطأ", en: "Error" },
  "azure.status.disabled": { ar: "معطّل", en: "Disabled" },
  "azure.lastVerified": { ar: "آخر تحقّق", en: "Last verified" },
  "azure.never": { ar: "لم يتم بعد", en: "Never" },
  "azure.validate": { ar: "تحقّق من الاتصال", en: "Validate connection" },
  "azure.discover": { ar: "استكشاف المشاريع", en: "Discover projects" },
  "azure.sync": { ar: "تشغيل مزامنة الأساس", en: "Run foundation sync" },
  "azure.running": { ar: "جارٍ التنفيذ…", en: "Working…" },
  "azure.activeRun": { ar: "توجد مزامنة نشطة الآن.", en: "A synchronization run is already active." },
  "azure.noPermission": {
    ar: "لا تملك صلاحية تشغيل المزامنة. تواصل مع مسؤول المؤسسة.",
    en: "You are not allowed to run synchronization. Contact your tenant admin.",
  },
  "azure.notConfigured": {
    ar: "لم تُضبط بيانات الاتصال بعد على الخادم.",
    en: "Server-side Azure DevOps secrets are not configured yet.",
  },
  "azure.projects": { ar: "المشاريع المتاحة", en: "Discoverable projects" },
  "azure.projectsEmpty": { ar: "لا توجد مشاريع مقروءة بهذه الصلاحيات.", en: "No readable projects with these credentials." },
  "azure.discoveryFailed": { ar: "فشل استكشاف المشاريع", en: "Project discovery failed" },
  "azure.discoveryPartial": {
    ar: "تم عرض نتائج جزئية؛ لم تُقرأ جميع الصفحات.",
    en: "Partial results shown; not every page could be read.",
  },
  "azure.cancel": { ar: "إلغاء المزامنة", en: "Cancel sync" },
  "azure.run.queued": { ar: "المزامنة في قائمة الانتظار.", en: "Synchronization queued." },
  "azure.run.running": { ar: "المزامنة قيد التنفيذ…", en: "Synchronization running…" },
  "azure.run.succeeded": { ar: "اكتملت المزامنة بنجاح.", en: "Synchronization completed." },
  "azure.run.partial": { ar: "اكتملت المزامنة جزئيًا.", en: "Synchronization completed partially." },
  "azure.run.failed": { ar: "فشلت المزامنة.", en: "Synchronization failed." },
  "azure.run.skipped": { ar: "تم تخطي المزامنة.", en: "Synchronization skipped." },
  "azure.lastRun": { ar: "آخر تشغيل", en: "Last run" },
  "azure.domain": { ar: "النطاق", en: "Domain" },
  "azure.discovered": { ar: "مقروء", en: "Read" },
  "azure.inserted": { ar: "مضاف", en: "Inserted" },
  "azure.updated": { ar: "محدّث", en: "Updated" },
  "azure.missing": { ar: "مفقود", en: "Missing" },
  "azure.failed": { ar: "فشل", en: "Failed" },
  "azure.complete": { ar: "مكتمل", en: "Complete" },
  "azure.partial": { ar: "جزئي", en: "Partial" },
  "azure.freshness": { ar: "حداثة البيانات", en: "Freshness" },
  "azure.domain.organization": { ar: "المؤسسة", en: "Organization" },
  "azure.domain.projects": { ar: "المشاريع", en: "Projects" },
  "azure.domain.teams": { ar: "الفرق", en: "Teams" },
  "azure.domain.iterations": { ar: "السبرنتات", en: "Iterations" },
  "azure.domain.teamIterations": { ar: "سبرنتات الفرق", en: "Team iterations" },
  "azure.domain.members": { ar: "الأعضاء", en: "Members" },
  "azure.domain.teamMemberships": { ar: "عضويات الفرق", en: "Team memberships" },
  "azure.next.none": { ar: "لا يلزم أي إجراء.", en: "No action needed." },
  "azure.next.retry_sync": { ar: "أعد تشغيل المزامنة.", en: "Re-run the synchronization." },
  "azure.next.fix_credentials": { ar: "راجع بيانات الاعتماد على الخادم.", en: "Review the server-side credentials." },
  "azure.next.wait_and_retry": { ar: "انتظر قليلًا ثم أعد المحاولة.", en: "Wait a moment, then retry." },
  "azure.next.contact_admin": { ar: "تواصل مع مسؤول المؤسسة.", en: "Contact your tenant admin." },
  "azure.error.not_configured": { ar: "لم تُضبط بيانات الاتصال.", en: "The connection is not configured." },
  "azure.error.invalid_credentials": { ar: "رفض Azure DevOps بيانات الاعتماد.", en: "Azure DevOps rejected the credentials." },
  "azure.error.insufficient_permissions": { ar: "الصلاحيات غير كافية للقراءة.", en: "The credentials lack the required read scopes." },
  "azure.error.organization_not_found": { ar: "تعذّر العثور على المؤسسة.", en: "The organization was not found." },
  "azure.error.throttled": { ar: "تم تقييد الطلبات مؤقتًا.", en: "Requests are being throttled." },
  "azure.error.timeout": { ar: "انتهت مهلة الطلب.", en: "The request timed out." },
  "azure.error.unavailable": { ar: "الخدمة غير متاحة حاليًا.", en: "The service is temporarily unavailable." },
  "azure.error.partial_sync": { ar: "اكتملت المزامنة جزئيًا.", en: "The synchronization completed partially." },
  "azure.error.conflict": { ar: "توجد مزامنة نشطة بالفعل.", en: "Another run is already active." },
  "azure.error.forbidden": { ar: "غير مصرّح لك بهذه العملية.", en: "You are not authorized for this operation." },
  "azure.error.missing_configuration": { ar: "لم تُضبط بيانات الاتصال.", en: "The connection is not configured." },
  "azure.error.invalid_configuration": { ar: "قيمة اسم المؤسسة غير صالحة.", en: "The configured organization value is invalid." },
  "azure.error.request_timeout": { ar: "انتهت مهلة الطلب.", en: "The request timed out." },
  "azure.error.network_unreachable": { ar: "تعذّر الوصول إلى Azure DevOps من الخادم.", en: "Azure DevOps could not be reached from the server." },
  "azure.error.provider_unavailable": { ar: "الخدمة غير متاحة حاليًا.", en: "The service is temporarily unavailable." },
  "azure.error.unknown": { ar: "حدث خطأ غير متوقع.", en: "An unexpected error occurred." },
} satisfies Dict;


export type TKey = keyof typeof dictionary;

type Ctx = {
  locale: Locale;
  dir: "rtl" | "ltr";
  setLocale: (l: Locale) => void;
  t: (key: TKey, vars?: Record<string, string | number>) => string;
  n: (value: number, opts?: Intl.NumberFormatOptions) => string;
  days: (value: number) => string;
  hours: (value: number) => string;
};

/** Arabic-aware day count: يوم / يومان / أيام / يوماً. */
export function formatDays(value: number, locale: Locale) {
  if (locale === "en") return `${value} ${value === 1 ? "day" : "days"}`;
  if (value === 1) return "يوم واحد";
  if (value === 2) return "يومان";
  if (value >= 3 && value <= 10) return `${value} أيام`;
  return `${value} يوماً`;
}

/** Arabic-aware hour count with a real space before the unit. */
export function formatHours(value: number, locale: Locale) {
  if (locale === "en") return `${value}h`;
  if (value === 1) return "ساعة واحدة";
  if (value === 2) return "ساعتان";
  if (value >= 3 && value <= 10) return `${value} ساعات`;
  return `${value} ساعة`;
}

const LocaleContext = createContext<Ctx | null>(null);

const STORAGE_KEY = "matn.locale";

export function LocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>("ar");

  useEffect(() => {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (stored === "ar" || stored === "en") setLocaleState(stored);
  }, []);

  useEffect(() => {
    const dir = locale === "ar" ? "rtl" : "ltr";
    document.documentElement.setAttribute("dir", dir);
    document.documentElement.setAttribute("lang", locale);
  }, [locale]);

  const setLocale = useCallback((l: Locale) => {
    setLocaleState(l);
    window.localStorage.setItem(STORAGE_KEY, l);
  }, []);

  const t = useCallback(
    (key: TKey, vars?: Record<string, string | number>) => {
      let out = dictionary[key]?.[locale] ?? String(key);
      if (vars) {
        for (const [k, v] of Object.entries(vars)) {
          out = out.replaceAll(`{${k}}`, String(v));
        }
      }
      return out;
    },
    [locale],
  );

  const n = useCallback(
    (value: number, opts?: Intl.NumberFormatOptions) =>
      new Intl.NumberFormat("en-US", opts).format(value),
    [],
  );

  const days = useCallback((v: number) => formatDays(v, locale), [locale]);
  const hours = useCallback((v: number) => formatHours(v, locale), [locale]);

  const value = useMemo(
    () => ({
      locale,
      dir: (locale === "ar" ? "rtl" : "ltr") as "rtl" | "ltr",
      setLocale,
      t,
      n,
      days,
      hours,
    }),
    [locale, setLocale, t, n, days, hours],
  );

  return <LocaleContext.Provider value={value}>{children}</LocaleContext.Provider>;
}

export function useI18n() {
  const ctx = useContext(LocaleContext);
  if (!ctx) throw new Error("useI18n must be used inside LocaleProvider");
  return ctx;
}
