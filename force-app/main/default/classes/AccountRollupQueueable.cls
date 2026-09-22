public with sharing class AccountRollupQueueable implements Queueable {
    private Set<Id> loanIds;

    public AccountRollupQueueable(Set<Id> loanIds) {
        this.loanIds = loanIds;
    }

    public static void enqueueForLoans(Set<Id> loanIds) {
        if (loanIds != null && !loanIds.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new AccountRollupQueueable(loanIds));
        }
    }

    public void execute(QueueableContext qc) {
        // Real logic comes in Part C
    }
}