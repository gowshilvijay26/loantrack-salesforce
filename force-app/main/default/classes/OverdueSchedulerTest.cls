@isTest
private class OverdueSchedulerTest {

    @isTest
    static void testSchedulerExecutesBatch() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');

        List<Installment__c> installments = [SELECT Id FROM Installment__c WHERE Loan__c = :loan.Id];
        for (Installment__c inst : installments) {
            inst.Due_Date__c = Date.today().addDays(-30);
        }
        update installments;

        Test.startTest();
        new OverdueScheduler().execute(null);
        Test.stopTest();

        List<Installment__c> updated = [SELECT Status__c FROM Installment__c WHERE Loan__c = :loan.Id];
        for (Installment__c inst : updated) {
            System.assertEquals('Overdue', inst.Status__c,
                'Calling the scheduler execute method should run the batch and mark installments Overdue');
        }
    }

    @isTest
    static void testSchedulerCanBeScheduled() {
        Test.startTest();
        String jobId = System.schedule('Daily Overdue Check Test', '0 0 2 * * ?', new OverdueScheduler());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals('0 0 2 * * ?', ct.CronExpression,
            'The scheduled job should be registered in CronTrigger with the correct cron expression');
    }
}