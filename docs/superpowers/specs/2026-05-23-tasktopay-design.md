# Task2Gain — מסמך עיצוב

**תאריך:** 2026-05-23
**שפה:** עברית (RTL)
**פלטפורמה:** אפליקציית מובייל (iOS + Android)
**אר ארכיטקטורה:** Multi-tenant SaaS

---

## 1. תקציר מנהלים

Task2Gain היא אפליקציית מובייל **בעברית** לניהול משימות משפחתיות עם מערכת תגמולים שמרגישה כמו **משחק**. הורים (אדמינים) יוצרים "קווסטים" עם ערך נקודות; ילדים מבצעים, מעלים הוכחה (לעיתים), מקבלים אישור והנקודות נכנסות לארנק שלהם. ניתן להמיר נקודות לכסף ולקנות פרסים בחנות הפנימית או להעביר לאפליקציית CashCash.

המוצר רב-משפחתי (SaaS) — כל משפחה היא tenant נפרד.

---

## 2. דרישות מפתח

### דרישות פונקציונליות
- **F1 — הרשמת הורה והזמנת בני משפחה:** הורה נרשם, מקבל קוד קידומת משפחה, ושולח הזמנות (SMS/WhatsApp) לבני המשפחה
- **F2 — יצירת/עריכת/הסרת קווסטים** ע"י אדמין בלבד; כולל נקודות, XP, דרגת קושי, סוג הוכחה, רקורנס
- **F3 — קווסטים בסיסיים מוכנים מראש** (תבניות) זמינים בכל משפחה חדשה
- **F4 — ביצוע קווסט ע"י ילד:** סימון "בוצע", העלאת תמונה אם נדרש (לפני/אחרי או רק אחרי)
- **F5 — אישור/דחיית קווסט ע"י אדמין:** רק לאחר אישור הנקודות נכנסות לארנק
- **F6 — ארנק אישי:** הצגת נקודות + כסף, היסטוריית עסקאות
- **F7 — המרת נקודות לכסף:** מינימום הניתן להגדרה, אופציית המרה אוטומטית
- **F8 — חנות פרסים:** קטלוג שאדמין מנהל (הוספה/עריכה/הסרה/מלאי)
- **F9 — מטרת חיסכון:** ילד מסמן פריט בחנות → רואה progress bar שלו לקראת המטרה
- **F10 — קנייה מחנות:** דורש אישור אדמין; מורידה כסף מהארנק
- **F11 — העברת כסף ל-CashCash:** דורש אישור אדמין
- **F12 — לוח מובילים משפחתי:** השוואה בין בני המשפחה (XP, רצף, משימות, הישגים) עם פילטרים זמניים
- **F13 — מערכת רמות + XP:** עליה ברמה מובילה לאנימציית חגיגה
- **F14 — רצפים יומיים (Streaks):** מעקב, התראות, שיא אישי
- **F15 — Badges/הישגים:** קטלוג של הישגים, נקבעים אוטומטית ע"י החוקים
- **F16 — Push notifications:** לכל אירוע משמעותי (קווסט ממתין לאישור, אישור התקבל, רמה חדשה וכו')
- **F17 — אווטרים** (preset או תמונה אישית) לכל בן משפחה

### דרישות לא-פונקציונליות
- **NF1 — Real-time:** אישור הורה נראה לילד בתוך שניות
- **NF2 — בטיחות:** ילד לא יכול לזייף נקודות; כל פעולה מובילית נכנסת דרך Cloud Functions
- **NF3 — בידוד tenants:** Firestore Security Rules מבטיחים שמשפחה לא רואה נתוני משפחה אחרת
- **NF4 — RTL מלא:** כל המסכים בעברית מימין לשמאל
- **NF5 — Game-feel:** אנימציות, סאונדים, חגיגות — לא רשימה משעממת. ראה [מסמך הזיכרון: feedback_gamified_ux](../../../memory/feedback_gamified_ux.md)
- **NF6 — נגישות:** כפתורים גדולים, ניגודיות, תמיכה ב-VoiceOver

### מחוץ ל-Scope (V1)
- מערכת תשלום אוטומטית דרך Bit/PayBox (V2 — בינתיים אישור ידני של הורה)
- אינטגרציה ישירה ל-CashCash (V1: המרה ידנית של הורה, V2: API)
- אתר אינטרנט (V2)
- ריבוי שפות (V1: עברית בלבד)
- מערכת תשלום למוצר עצמו (תכונה לפרימיום נעשה כשיגיע)

---

## 3. ארכיטקטורה

```
┌─────────────────────────────────────────┐
│      Flutter App (iOS + Android)          │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│              Firebase                    │
│  - Authentication (parents + invited)   │
│  - Firestore (multi-tenant data)        │
│  - Storage (proof photos, avatars)      │
│  - Cloud Messaging (push)               │
│  - Cloud Functions (TypeScript)         │
│    └── all sensitive ops: approvals,    │
│        point→money conversion,          │
│        transfers, invitation flow       │
└─────────────────────────────────────────┘

External: Twilio (SMS for invites in V1)
```

**עקרון יסוד:** הלקוח (אפליקציה) לא מבצע אף פעולה רגישה — קוראת לפונקציה ב-Cloud Functions שמאמתת ומבצעת.

---

## 4. מודל נתונים

### Collections עיקריים (Firestore)

```
families/{familyId}
  name, createdAt, plan ("free" | "premium")
  settings: { minPointsToConvert, pointToShekelRate, leaderboardIncludesAdmins }

users/{userId}
  familyId, role ("admin" | "kid"), displayName
  avatar: { type: "preset" | "photo", value }
  level, xp, xpToNextLevel
  streak: { current, longest, lastDate }
  badges: [{ id, earnedAt }]

tasks/{taskId}        // תבניות קווסט (לא מופע!)
  familyId, title, description, icon, category
  points, xpReward
  difficulty ("easy" | "medium" | "epic")
  proofRequired ("none" | "photo" | "before-after")
  recurrence ("daily" | "weekly" | "once")
  assignedTo, createdBy, active

questInstances/{instanceId}     // מופע ספציפי
  taskId, familyId, assignedTo
  status ("available" | "in_progress" | "submitted" | "approved" | "rejected")
  submittedAt, proofPhotos: [url]
  approvedBy, approvedAt
  pointsAwarded, xpAwarded
  rejectionReason

wallets/{userId}
  points (זמין להמרה)
  moneyILS
  lifetimeEarned: { points, money }

rewards/{rewardId}    // קטלוג חנות פרסים
  familyId, title, image, priceILS
  stock ("unlimited" | number)
  category, active, createdBy

rewardTargets/{userId}/{targetId}
  rewardId, savedAt

transactions/{txId}
  userId, familyId, type ("convert" | "purchase" | "transfer-out")
  amount, status ("pending_approval" | "approved" | "completed" | "rejected")
  approvedBy, metadata

achievements catalog (global, in code)
  id, title, description, icon, xpBonus, trigger

invitations/{inviteId}
  familyId, role, code (6 digits), phone
  status ("pending" | "accepted" | "expired"), expiresAt
```

### Firestore Security Rules — עקרונות
- כל מסמך תחת `/families/{familyId}/...` נגיש רק למשתמשים שיש להם `familyId` מתאים ב-`users/{uid}`
- כתיבה ל-`wallets`, `transactions`, `questInstances.status` חסומה ללקוח — רק דרך Cloud Functions
- אדמין יכול לכתוב ל-`tasks` ו-`rewards` בקולקציה של המשפחה שלו

---

## 5. זרימות מפתח

### 5.1 הרשמת הורה והזמנת משפחה
1. הורה מתקין → "הרשמה" → אימייל+סיסמה (Firebase Auth)
2. יצירת `family` חדשה, ה-uid הופך לאדמין
3. הורה מקיש שם, מספרי טלפון של בני המשפחה
4. Cloud Function `sendInvitations`:
   - יוצר רשומה ב-`invitations` עם קוד 6 ספרות
   - שולח SMS דרך Twilio: "הצטרף ל-Task2Gain של משפחת X! קוד: 123456 | קישור: task2gain.app/join"
5. בן משפחה מקבל: פותח אפליקציה → "יש לי קוד" → מקיש קוד → יוצר חשבון → מחובר למשפחה

### 5.2 ביצוע קווסט עם הוכחה תמונתית
1. ילד פותח דשבורד → לוחץ על קווסט "סדר את החדר"
2. מסך פרטים → "התחל קווסט" → status: `in_progress`
3. (אם before-after) צילום "לפני" → upload ל-Storage
4. ילד מבצע במציאות
5. "סיימתי" → צילום "אחרי" → upload
6. status: `submitted`, Cloud Function `notifyAdmin` שולח push להורה
7. הורה רואה התראה → פותח מסך אישור (תמונות לפני/אחרי + פרטים)
8. אישור → Cloud Function `approveQuest`:
   - `status: approved`
   - `wallet.points += task.points`, `user.xp += task.xpReward`
   - בדיקת עליית רמה ← אם כן, badge "Level Up", push notification
   - בדיקת רצף → עדכון streak
   - בדיקת achievements שננעלו → הוספה ל-`badges`
   - push לילד: "🎉 +25⭐!"

### 5.3 המרת נקודות לכסף
1. ילד לוחץ "המר נקודות" בארנק
2. Cloud Function `convertPoints`:
   - בודק שיש מספיק נקודות (`>= family.settings.minPointsToConvert`)
   - מחשב: `money = points * family.settings.pointToShekelRate`
   - `wallet.points -= used`, `wallet.moneyILS += money`
   - יוצר `transaction` (status: completed, ללא אישור נדרש)

### 5.4 קנייה מחנות פרסים
1. ילד לוחץ על פרס (יש לו מספיק כסף) → "קנה"
2. Cloud Function `purchaseReward`:
   - בודק יתרה ומלאי
   - יוצר `transaction` עם `status: pending_approval`
   - שולח push לאדמין
3. אדמין מאשר → `transaction.status: completed`, מוריד `wallet.moneyILS`, מעדכן `reward.stock`
4. אדמין דוחה → המשתמש מקבל push

### 5.5 העברת כסף ל-CashCash (V1: ידני)
1. ילד לוחץ "העבר ל-CashCash"
2. בוחר סכום → אישור → `transaction (pending)`
3. הורה רואה בתור אישורים → "מאשר" → ההורה מבצע בעצמו את ההעברה בקאש קאש → לוחץ "הסתיים" → `transaction.completed`, מוריד מהארנק

### 5.6 לוח מובילים
- מסך עם 3 פילטרים זמניים (השבוע / החודש / כל הזמנים)
- ברירת מחדל: כל בני המשפחה
- מטריקות: רמה, נקודות חיים (lifetimeEarned), משימות שבוצעו, רצף נוכחי, badges
- הורים מופיעים רק אם הם בחרו ב-settings

---

## 6. עקרונות UI/UX

- **שפת משחק:** "קווסטים" במקום "משימות", "EPIC" במקום "קשה", "XP" בנוסף לנקודות
- **חגיגות:** עליית רמה = full-screen animation + confetti + sound. סיום קווסט = haptic feedback + sound
- **גרדיאנטים, צבעים חמים** (לא ניאוטרלי תאגידי)
- **אווטרים גדולים** וצבעוניים בדשבורד
- **Progress bars בכל מקום** — XP, מטרת חיסכון, רצף, achievements
- **דשבורד הורה יותר רגוע** — אופציות מהירות לתור האישורים
- **RTL מלא** עם פונט נעים (Heebo או Rubik)

---

## 7. בדיקות

- **Unit tests:** Cloud Functions (לוגיקה עסקית — חישובי נקודות/XP, עליית רמה, חישובי רצף)
- **Integration tests:** זרימת אישור משימה end-to-end עם Firestore Emulator
- **Widget tests:** מסכים מרכזיים ב-Flutter
- **Manual smoke:** הרצה בסימולטור iPhone אחרי כל שלב משמעותי, כולל RTL ועברית

---

## 8. תוכנית התקפלות לשלבים

**Milestone 1 — תשתית (שבוע 1):**
- Flutter scaffolding, theme עברי RTL, ניווט בסיסי
- Firebase project setup
- מסך login + signup
- Multi-tenancy בסיסי (Firestore + Security Rules)

**Milestone 2 — קווסטים (שבוע 2):**
- יצירת קווסט (אדמין)
- צפייה/ביצוע קווסט (ילד)
- אישור (אדמין), Cloud Function `approveQuest`
- העלאת תמונת הוכחה

**Milestone 3 — ארנק וגיימיפיקציה (שבוע 3):**
- ארנק נקודות + כסף
- מערכת XP + רמות + אנימציות עליית רמה
- רצפים
- Badges/achievements

**Milestone 4 — חנות ומטרות (שבוע 4):**
- ניהול חנות פרסים (אדמין)
- מסך חנות (ילד) + סימון מטרה + progress
- קנייה + אישור

**Milestone 5 — לוח מובילים, הזמנות (שבוע 5):**
- לוח מובילים עם פילטרים
- מערכת הזמנות (SMS דרך Twilio)
- הצטרפות בקוד

**Milestone 6 — שיוף, סאונדים, חוויית משחק מלאה (שבוע 6):**
- אנימציות, סאונדים
- אווטרים מותאמים
- onboarding משחקי
- bug fixes
