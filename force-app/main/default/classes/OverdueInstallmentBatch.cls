public with sharing class OverdueInstallmentBatch implements Database.Batchable<SObject>, Database.Stateful {

    // Track which loans we touched, so we can check them in finish()
    private Set<Id> touchedLoanIds = new Set<Id>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Loan_Setting_mdt__mdt setting = Loan_Setting_mdt__mdt.getInstance('Default_Settings');
        Integer graceDays = (setting != null && setting.Grace_Days__c != null)
                ? Integer.valueOf(setting.Grace_Days__c) : 0;

        Date cutoff = Date.today().addDays(-graceDays);

        return Database.getQueryLocator([
            SELECT Id, Loan__c, Due_Date__c, EMI_Amount__c, Late_Fee__c, Status__c
            FROM Installment__c
            WHERE Status__c IN ('Pending', 'Partially Paid')
            AND Due_Date__c < :cutoff
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Installment__c> scope) {
        Loan_Setting_mdt__mdt setting = Loan_Setting_mdt__mdt.getInstance('Default_Settings');
        Decimal lateFeePercent = (setting != null && setting.Late_Fee_Percent__c != null)
                ? setting.Late_Fee_Percent__c : 0;

        List<Installment__c> toUpdate = new List<Installment__c>();

        for (Installment__c inst : scope) {
            Decimal fee = (nz(inst.EMI_Amount__c) * lateFeePercent / 100).setScale(2, RoundingMode.HALF_UP);
            toUpdate.add(new Installment__c(
                Id = inst.Id,
                Status__c = 'Overdue',
                Late_Fee__c = nz(inst.Late_Fee__c) + fee
            ));
            touchedLoanIds.add(inst.Loan__c);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (touchedLoanIds.isEmpty()) {
            return;
        }

        Loan_Setting_mdt__mdt setting = Loan_Setting_mdt__mdt.getInstance('Default_Settings');
        Integer defaultThreshold = (setting != null && setting.Default_After_Overdue_Count__c != null)
                ? Integer.valueOf(setting.Default_After_Overdue_Count__c) : 3;

        // Count current overdue installments per loan (ONE query, outside any loop)
        Map<Id, Integer> overdueCountByLoan = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Loan__c loanId, COUNT(Id) cnt
            FROM Installment__c
            WHERE Loan__c IN :touchedLoanIds AND Status__c = 'Overdue'
            GROUP BY Loan__c
        ]) {
            overdueCountByLoan.put((Id) ar.get('loanId'), (Integer) ar.get('cnt'));
        }

        Set<Id> loansToDefault = new Set<Id>();
        for (Id loanId : overdueCountByLoan.keySet()) {
            if (overdueCountByLoan.get(loanId) >= defaultThreshold) {
                loansToDefault.add(loanId);
            }
        }

        if (!loansToDefault.isEmpty()) {
            List<Loan__c> loans = [
                SELECT Id, Status__c FROM Loan__c
                WHERE Id IN :loansToDefault AND Status__c = 'Active'
            ];
            for (Loan__c loan : loans) {
                loan.Status__c = 'Defaulted';
            }
            if (!loans.isEmpty()) {
                update loans;
            }
        }

        // Refresh Account rollups for every loan we touched (Part C)
        AccountRollupQueueable.enqueueForLoans(touchedLoanIds);
    }

    private static Decimal nz(Decimal value) {
        return (value == null) ? 0 : value;
    }
}