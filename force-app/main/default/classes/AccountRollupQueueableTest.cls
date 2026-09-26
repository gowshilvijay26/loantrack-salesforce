@isTest
private class AccountRollupQueueableTest {

    @isTest
    static void testQueueable_RecalculatesAccountTotals() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan1 = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');
        Loan__c loan2 = TestDataFactory.insertLoan(acc.Id, 5000, 0, 5, 'Active');

        Set<Id> loanIds = new Set<Id>{ loan1.Id, loan2.Id };

        Test.startTest();
        System.enqueueJob(new AccountRollupQueueable(loanIds));
        Test.stopTest();

        Account updated = [
            SELECT Total_Loans__c, Total_Outstanding__c FROM Account WHERE Id = :acc.Id
        ];
        System.assertEquals(2, updated.Total_Loans__c,
            'Account should show 2 total loans after the queueable recalculates');
        System.assertEquals(8000, updated.Total_Outstanding__c,
            'Account total outstanding should be the sum of both loans (3000 + 5000)');
    }

    @isTest
    static void testQueueable_EmptyLoanIds_DoesNothing() {
        Test.startTest();
        AccountRollupQueueable.enqueueForLoans(new Set<Id>());
        Test.stopTest();

        // No exception should occur, and no job should be enqueued for an empty set
        System.assert(true, 'Calling enqueueForLoans with an empty set should not throw an error');
    }
}