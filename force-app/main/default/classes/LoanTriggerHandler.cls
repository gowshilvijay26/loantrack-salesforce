public with sharing class LoanTriggerHandler {

    // Recursion guard: loans already processed in this transaction
    private static Set<Id> processedLoanIds = new Set<Id>();

    // ---------- BEFORE: validate + calculate EMI ----------
    public static void beforeSave(List<Loan__c> newLoans, Map<Id, Loan__c> oldMap) {
        for (Loan__c loan : newLoans) {
            if (!becameActive(loan, oldMap)) {
                continue;
            }
            if (loan.First_EMI_Date__c == null) {
                loan.addError('First EMI Date is required to activate the loan.');
                continue;
            }
            try {
                Integer tenure = (loan.Tenure_Months__c == null) ? null : loan.Tenure_Months__c.intValue();
                loan.EMI_Amount__c = EmiCalculator.calculateEmi(
                    loan.Principal_Amount__c, loan.Interest_Rate__c, tenure);
            } catch (EmiCalculator.EmiException e) {
                loan.addError(e.getMessage());
            }
        }
    }

    // ---------- AFTER: create the Installment schedule ----------
    public static void afterSave(List<Loan__c> newLoans, Map<Id, Loan__c> oldMap) {
        List<Loan__c> toProcess = new List<Loan__c>();
        Set<Id> loanIds = new Set<Id>();

        for (Loan__c loan : newLoans) {
            if (becameActive(loan, oldMap) && !processedLoanIds.contains(loan.Id)) {
                toProcess.add(loan);
                loanIds.add(loan.Id);
                processedLoanIds.add(loan.Id);
            }
        }
        if (toProcess.isEmpty()) {
            return;
        }

        // Safety: skip loans that already have a schedule (one query, outside any loop)
        Set<Id> alreadyScheduled = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Loan__c FROM Installment__c WHERE Loan__c IN :loanIds GROUP BY Loan__c
        ]) {
            alreadyScheduled.add((Id) ar.get('Loan__c'));
        }

        List<Installment__c> allRows = new List<Installment__c>();
        for (Loan__c loan : toProcess) {
            if (!alreadyScheduled.contains(loan.Id)) {
                allRows.addAll(buildSchedule(loan));
            }
        }

        if (!allRows.isEmpty()) {
            insert allRows; // ONE DML for all loans
        }
    }

    // ---------- helpers ----------
    private static Boolean becameActive(Loan__c loan, Map<Id, Loan__c> oldMap) {
        if (loan.Status__c != 'Active') {
            return false;
        }
        return oldMap == null || oldMap.get(loan.Id).Status__c != 'Active';
    }

    private static List<Installment__c> buildSchedule(Loan__c loan) {
        List<Installment__c> rows = new List<Installment__c>();

        Decimal r = EmiCalculator.monthlyRate(loan.Interest_Rate__c);
        Integer n = loan.Tenure_Months__c.intValue();
        Decimal balance = loan.Principal_Amount__c;
        Decimal emi = loan.EMI_Amount__c;

        for (Integer i = 1; i <= n; i++) {
            Decimal interest = (balance * r).setScale(2, RoundingMode.HALF_UP);
            Decimal principalPart;
            Decimal emiThisMonth;

            if (i == n) {
                // Last row: clear the whole remaining balance so it ends at exactly 0
                principalPart = balance;
                emiThisMonth = principalPart + interest;
            } else {
                principalPart = emi - interest;
                emiThisMonth = emi;
            }
            balance = balance - principalPart;

            rows.add(new Installment__c(
                Loan__c = loan.Id,
                Installment_Number__c = i,
                Due_Date__c = loan.First_EMI_Date__c.addMonths(i - 1),
                EMI_Amount__c = emiThisMonth,
                Principal_Component__c = principalPart,
                Interest_Component__c = interest,
                Amount_Paid__c = 0,
                Late_Fee__c = 0,
                Status__c = 'Pending'
            ));
        }
        return rows;
    }
}