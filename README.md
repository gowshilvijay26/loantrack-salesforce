# LoanTrack — Loan & Repayment Management on Salesforce

LoanTrack is an end-to-end loan management solution built on Salesforce, covering the full lifecycle of a loan: **Enquiry → Client → Loan Deal → Loan → Approval → Disbursement → EMI Schedule → Payments → Overdue Tracking → Reports & Dashboards.**

It was built as a portfolio project to demonstrate hands-on Salesforce development skills: custom data modeling, Apex (triggers, batch, scheduled, queueable, REST), Flow automation, Lightning Web Components, integration, security, testing, reporting, and an Agentforce AI agent.

> **Note:** This project uses dummy data only. No real client or financial data is stored in this org or repository.

---

## Table of Contents

- [Business Flow](#business-flow)
- [Architecture Overview](#architecture-overview)
- [Entity Relationship Diagram](#entity-relationship-diagram)
- [Feature List](#feature-list)
- [Tech Stack](#tech-stack)
- [Setup & Deployment](#setup--deployment)
- [Testing](#testing)
- [Known Limitations & Next Steps](#known-limitations--next-steps)

---

## Business Flow

```mermaid
flowchart LR
    A["Enquiry (Lead)"] --> B["Client (Account)"]
    B --> C["Loan Deal (Opportunity)"]
    C -->|Closed Won| D["Loan (Draft)"]
    D --> E["Approval Process"]
    E --> F["Disbursement (Screen Flow)"]
    F --> G["EMI Schedule (Installments)"]
    G --> H["Payments"]
    H --> I["Overdue Tracking (Batch and Scheduler)"]
    I --> J["Reports and Dashboards"]
```

1. A **Lead** enquires about a loan (via Web-to-Lead or manual entry).
2. The Lead is converted into an **Account** (client) and an **Opportunity** (loan deal).
3. When the Opportunity is marked **Closed Won**, a Record-Triggered Flow automatically creates a **Draft Loan**.
4. The Loan goes through a two-step **Approval Process** (Manager, then Senior for large loans).
5. Once approved, the officer runs the **Disburse Loan** screen flow, which activates the loan.
6. Activating the loan triggers Apex to calculate the EMI and generate the full **Installment schedule**.
7. Clients make **Payments**, which are automatically allocated to installments (oldest due first).
8. A nightly **Batch job** marks missed installments **Overdue**, adds late fees, and marks chronically overdue loans **Defaulted**.
9. **Reports and a Dashboard** give the business a live view of the loan portfolio.
10. An **Agentforce agent** answers natural-language questions about loan status directly inside the app.

---

## Architecture Overview

```mermaid
flowchart TB
    subgraph UI["Lightning Experience"]
        LWC1["loanCalculator"]
        LWC2["loanSummaryCard"]
        LWC3["installmentSchedule"]
        Flow1["Disburse Loan Screen Flow"]
        Agent["Agentforce: Loan Status Assistant"]
    end

    subgraph Automation["Declarative Automation"]
        ApprovalProc["Approval Process"]
        ClosedWonFlow["Closed Won to Loan Flow"]
        ReminderFlow["EMI Reminder Scheduled Flow"]
    end

    subgraph ApexLayer["Apex Layer"]
        LoanTrigger["LoanTrigger and Handler"]
        PaymentTrigger["PaymentTrigger and Handler"]
        EmiCalc["EmiCalculator"]
        Batch["OverdueInstallmentBatch"]
        Scheduler["OverdueScheduler"]
        Queueable["AccountRollupQueueable"]
        RestApi["LoanStatusService REST Resource"]
        SummaryCtrl["LoanSummaryController"]
        ScheduleCtrl["InstallmentScheduleController"]
    end

    subgraph Data["Data Model"]
        Loan[("Loan__c")]
        Installment[("Installment__c")]
        Payment[("Payment__c")]
        Account[("Account")]
    end

    subgraph ExternalSys["External Systems"]
        Client["External Client via REST API"]
        Webhook["webhook.site Outbound Alerts"]
    end

    LWC2 -->|wire cacheable Apex| SummaryCtrl
    LWC3 -->|imperative Apex| ScheduleCtrl
    Agent -->|reads live data| Loan
    Flow1 --> Loan
    ClosedWonFlow --> Loan
    ApprovalProc --> Loan
    Loan --> LoanTrigger
    LoanTrigger --> EmiCalc
    LoanTrigger --> Installment
    Payment --> PaymentTrigger
    PaymentTrigger --> Installment
    PaymentTrigger --> Queueable
    Queueable --> Account
    Scheduler --> Batch
    Batch --> Installment
    Batch --> Loan
    Batch --> Queueable
    Client --> RestApi
    RestApi --> Loan
    Batch -.->|Overdue alert| Webhook
```

**Design principles followed throughout:**
- **Bulkified Apex** — every trigger handler processes collections, never single records in a loop; one SOQL query and one DML statement per method.
- **Separation of concerns** — triggers only delegate to handler classes; calculation logic (`EmiCalculator`) is isolated and reusable across triggers, LWC, and the REST API.
- **Configuration over hardcoding** — grace days, late fee %, approval threshold, and default-after-overdue-count all live in a **Custom Metadata Type**, editable by an admin without a deployment.
- **Recursion guards** on triggers to prevent duplicate processing.
- **Governor-limit awareness** — Batch Apex is used for anything that could scale to large data volumes; Queueable is used for background work that reads and writes across objects.

---

## Entity Relationship Diagram

```mermaid
erDiagram
    LEAD ||--o{ OPPORTUNITY : converts_to
    ACCOUNT ||--o{ OPPORTUNITY : has
    ACCOUNT ||--o{ LOAN : borrows
    OPPORTUNITY ||--o| LOAN : becomes_on_closed_won
    LOAN ||--o{ INSTALLMENT : has_schedule_of
    LOAN ||--o{ PAYMENT : receives
    INSTALLMENT ||--o{ PAYMENT : is_paid_by

    LOAN {
        string Name
        string Client
        string Source_Opportunity
        number Principal_Amount
        number Interest_Rate
        number Tenure_Months
        date Disbursement_Date
        date First_EMI_Date
        string Status
        number EMI_Amount
        date Maturity_Date
        number Total_Payable
        number Total_Interest
        number Total_Paid
        number Overdue_Installments
        number Outstanding_Amount
        number Repayment_Progress
    }

    INSTALLMENT {
        string Name
        string Loan
        number Installment_Number
        date Due_Date
        number EMI_Amount
        number Principal_Component
        number Interest_Component
        number Amount_Paid
        date Paid_Date
        number Late_Fee
        number Balance_Due
        string Status
    }

    PAYMENT {
        string Name
        string Loan
        string Installment
        number Amount
        date Payment_Date
        string Payment_Mode
        string Reference_Number
    }
```

`Loan_Setting_mdt__mdt` (Custom Metadata Type) stores the business rules that the Apex and Flow layers read at runtime: Late Fee %, Grace Days, Approval Threshold, Max Tenure, and Default-After-Overdue-Count.

---

## Feature List

### Data Model & Security
- Custom objects: `Loan__c`, `Installment__c` (master-detail), `Payment__c` (master-detail), and a `Loan_Setting_mdt__mdt` Custom Metadata Type for business rules.
- Standard object extensions on Lead, Opportunity, and Account.
- Private OWD on Loan with role hierarchy (Loan Manager above Loan Officer), custom Permission Sets, Field-Level Security (only managers can edit Interest Rate), and a criteria-based sharing rule that shares Defaulted loans with a Collections public group.

### Sales Cloud
- Lead Assignment Rule routing enquiries to a Loan Officers queue.
- Web-to-Lead capture form.
- Lead-to-Opportunity field mapping.
- Custom Opportunity Sales Path.
- Record-Triggered Flow that creates a Draft Loan automatically when an Opportunity is marked Closed Won.

### Core Apex (Business Logic)
- `EmiCalculator` — pure calculation class implementing the standard EMI formula, with a dedicated 0%-interest path and correct rounding.
- `LoanTrigger` / `LoanTriggerHandler` — bulkified and recursion-guarded; generates the full installment schedule (principal/interest split, last-installment rounding correction) the moment a loan becomes Active.
- `PaymentTrigger` / `PaymentTriggerHandler` — allocates a payment across installments (oldest due first, with spill-over to the next installment), and automatically closes a loan once every installment is paid.
- Validation Rules enforcing data integrity: positive principal, rate bounds, tenure capped via Custom Metadata, terms locked once Active, and no future-dated payments.

### Approval Process & Flow Automation
- Two-step Approval Process (Manager, then a Senior approver for loans above a configurable threshold).
- Screen Flow "Disburse Loan" that captures disbursement details and activates the loan.
- Scheduled Flow that emails clients a reminder 3 days before their EMI is due.

### Asynchronous Apex
- `OverdueInstallmentBatch` (Batchable) — finds installments past their due date plus grace period, marks them Overdue, applies a late fee, and defaults loans that cross an overdue-count threshold. All values come from Custom Metadata.
- `OverdueScheduler` (Schedulable) — runs the batch daily.
- `AccountRollupQueueable` (Queueable) — recalculates each client's Total Loans and Total Outstanding, triggered from payments and from the nightly batch.

### Integration
- **Inbound:** `LoanStatusService`, an `@RestResource` endpoint (`/loanstatus/*`) that returns loan status, EMI, outstanding amount, and next due date as JSON, secured with OAuth through a Connected App.
- **Outbound:** Named Credential and External Credential pointing to a test endpoint, with a callout-enabled Queueable that posts a JSON alert when an installment becomes Overdue.

### Lightning Web Components
- `loanCalculator` — a standalone EMI calculator on the App Home page.
- `loanSummaryCard` — outstanding amount, repayment progress bar, next due date, and overdue count, powered by `@wire` and a cacheable Apex method.
- `installmentSchedule` — a `lightning-datatable` with color-coded status badges and a "Record Payment" row action that opens a modal, creates the Payment, and refreshes the table with `refreshApex`.
- A custom Loan Record Page combining a Status Path, both record components, and related lists.

### Reports & Dashboards
- Custom Report Type: Loans with Installments and Payments.
- Reports: Loans by Status, Overdue Installments, Collections This Month, Lead Conversion Funnel.
- Loan Portfolio Dashboard (total disbursed, total outstanding, collected vs due, top overdue clients), placed on the app Home page.

### Agentforce (AI Agent Integration)
- Built an **Agentforce Employee Agent** ("Loan Status Assistant") available inside the Loan Tracker app, answering natural-language questions about loan status, overdue accounts, and outstanding balances.
- The agent asks for the user's role (System Admin, Loan Officer, or Loan Manager) before answering, in line with the role-based sharing model used across the org.
- The agent is grounded in live Salesforce data (Loan and Installment records) rather than static or mocked responses.

**Example interaction:**

> **User:** Summarize overdue loans
>
> **Agent:** To help you summarize overdue loans, please let me know your role. Are you a System Admin, Loan Officer, or Loan Manager?
>
> **User:** system admin
>
> **Agent:** There is 1 overdue loan found: Loan ID: LN-0019, Outstanding Amount: $0. Would you like to check another loan category (Pending Approval, Defaulted, Not Yet Disbursed) or end the session?

### Testing
- `TestDataFactory` for consistent, reusable test data.
- Positive, negative, and 200-record bulk tests for both triggers.
- Dedicated tests for the batch, scheduler, queueable, and REST classes, plus the LWC Apex controllers.
- **42 test methods, 100% pass rate, 86% org-wide code coverage.**

---

## Tech Stack

| Layer | Technology |
|---|---|
| Data & Automation | Custom Objects, Custom Metadata Types, Validation Rules, Flow, Approval Process |
| Apex | Triggers, Batch Apex, Schedulable, Queueable, `@RestResource` |
| Frontend | Lightning Web Components, Lightning App Builder |
| Integration | REST API (inbound), Named and External Credentials with callouts (outbound), OAuth 2.0 |
| AI | Agentforce (Employee Agent) |
| Security | Profiles, Permission Sets, Role Hierarchy, Sharing Rules, Field-Level Security |
| Testing | Apex unit tests (`@isTest`) |
| Tooling | Salesforce CLI (`sf`), VS Code, Git/GitHub |

---

## Setup & Deployment

### Prerequisites
- A Salesforce Developer Edition org ([sign up free](https://developer.salesforce.com/signup))
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- [VS Code](https://code.visualstudio.com/) with the Salesforce Extension Pack
- Git

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/gowshilvijay26/loantrack-salesforce.git
cd loantrack-salesforce

# 2. Authorize your Salesforce org
sf org login web --alias loantrackerOrg --set-default

# 3. Deploy all metadata to your org
sf project deploy start --source-dir force-app

# 4. Run the full test suite and check coverage
sf apex run test --test-level RunLocalTests --result-format human --code-coverage

# 5. Open the org
sf org open
```

### Post-deployment configuration (one-time)
A few settings cannot be captured in metadata and need to be set once per org:
1. **Custom Metadata values** — Setup → Custom Metadata Types → Loan Setting → Manage Records. Set Grace Days, Late Fee %, Approval Threshold, Max Tenure, and Default-After-Overdue-Count.
2. **Schedule the nightly batch** — Setup → Apex Classes → Schedule Apex. Class: `OverdueScheduler`, Frequency: Daily.
3. **Connected App** — create one under Setup → App Manager to test the inbound REST API with OAuth.
4. **Named Credential** — point the outbound alert Queueable at your own test endpoint, for example a fresh [webhook.site](https://webhook.site) URL.
5. **Permission Sets** — assign `Loan_Officer` or `Loan_Manager` to any test users you create.
6. **Agentforce (optional)** — the agent needs Data Cloud and Einstein Generative AI turned on (Setup → Einstein Setup), the agent activated, and users given access through its permission set.
7. **Sample data** — load a handful of dummy Accounts and Loans with the Data Import Wizard or an anonymous Apex script.

---

## Testing

Run the full suite locally at any time:

```bash
sf apex run test --test-level RunLocalTests --result-format human --code-coverage
```

**Latest results:**

| Metric | Value |
|---|---|
| Tests run | 42 |
| Pass rate | 100% |
| Org-wide coverage | 86% |

<!--
SCREENSHOTS (uncomment after adding PNG files to docs/screenshots/)

## Screenshots

| Loan Record Page | Loan Portfolio Dashboard |
|---|---|
| ![Loan record page](docs/screenshots/loan-record-page.png) | ![Dashboard](docs/screenshots/loan-portfolio-dashboard.png) |

| Approval Process | Agentforce Loan Status Assistant |
|---|---|
| ![Approval history](docs/screenshots/approval-history.png) | ![Agentforce agent](docs/screenshots/agentforce-loan-status-assistant.png) |
-->

---

## Known Limitations & Next Steps

- Payments are handled on `after insert` only. Editing or deleting a payment does not reverse the installment allocation; a production system would need explicit reversal logic.
- The outbound overdue alert posts to a generic test endpoint (webhook.site). In production it would point to a real downstream system with proper authentication. A dedicated `HttpCalloutMock` test for this callout is a planned addition.
- Stretch feature not yet implemented: an Interest-Only repayment type (monthly interest, principal paid at maturity).
- Jest tests for the LWC components are a natural next step.

---

## Author

Built by Gowshil Narmadha V as an end-to-end Salesforce portfolio project covering data modeling, Apex, Flow automation, LWC, integration, security, testing, reporting, and Agentforce.