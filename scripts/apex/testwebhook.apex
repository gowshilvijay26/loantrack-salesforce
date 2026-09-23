// Get one Overdue installment for testing
List<Installment__c> testInst = [
    SELECT Id FROM Installment__c WHERE Status__c = 'Overdue' LIMIT 1
];

if (!testInst.isEmpty()) {
    List<Id> ids = new List<Id>{ testInst[0].Id };
    System.enqueueJob(new OverdueAlertQueueable(ids));
    System.debug('Queueable enqueued for Installment: ' + testInst[0].Id);
} else {
    System.debug('No Overdue installment found — run OverdueInstallmentBatch first, or manually set one installment Status__c = Overdue for testing.');
}