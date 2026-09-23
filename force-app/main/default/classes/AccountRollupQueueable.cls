public with sharing class AccountRollupQueueable implements Queueable {

    private Set<Id> loanIds;

    public AccountRollupQueueable(Set<Id> loanIds) {
        this.loanIds = loanIds;
    }

    public static void enqueueForLoans(Set<Id> loanIds) {
        if (loanIds == null || loanIds.isEmpty() || Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(new AccountRollupQueueable(loanIds));
    }

    public void execute(QueueableContext qc) {
        // 1. Find which Accounts are affected by these loans
        Set<Id> accountIds = new Set<Id>();
        for (Loan__c loan : [SELECT Id, Client__c FROM Loan__c WHERE Id IN :loanIds]) {
            if (loan.Client__c != null) {
                accountIds.add(loan.Client__c);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }

        // 2. Recalculate totals for those accounts (ONE query, no loop)
        Map<Id, Integer> loanCountByAccount = new Map<Id, Integer>();
        Map<Id, Decimal> outstandingByAccount = new Map<Id, Decimal>();

        for (Loan__c loan : [
            SELECT Id, Client__c, Outstanding_Amount__c
            FROM Loan__c
            WHERE Client__c IN :accountIds
        ]) {
            Integer count = loanCountByAccount.containsKey(loan.Client__c)
                    ? loanCountByAccount.get(loan.Client__c) : 0;
            loanCountByAccount.put(loan.Client__c, count + 1);

            Decimal outstanding = outstandingByAccount.containsKey(loan.Client__c)
                    ? outstandingByAccount.get(loan.Client__c) : 0;
            outstandingByAccount.put(loan.Client__c, outstanding + nz(loan.Outstanding_Amount__c));
        }

        // 3. Update the Accounts (ONE DML)
        List<Account> toUpdate = new List<Account>();
        for (Id accId : accountIds) {
            toUpdate.add(new Account(
                Id = accId,
                Total_Loans__c = loanCountByAccount.containsKey(accId) ? loanCountByAccount.get(accId) : 0,
                Total_Outstanding__c = outstandingByAccount.containsKey(accId) ? outstandingByAccount.get(accId) : 0
            ));
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private static Decimal nz(Decimal value) {
        return (value == null) ? 0 : value;
    }
}