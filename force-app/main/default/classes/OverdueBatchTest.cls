@isTest
private class OverdueBatchTest {

    @testSetup
    static void setup() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');

        // Trigger already created 3 installments; push their due dates into the past
        List<Installment__c> installments = [
            SELECT Id FROM Installment__c WHERE Loan__c = :loan.Id
        ];
        for (Installment__c inst : installments) {
            inst.Due_Date__c = Date.today().addDays(-30);
        }
        update installments;
    }

    @isTest
    static void testBatch_MarksInstallmentsOverdue() {
        Test.startTest();
        Database.executeBatch(new OverdueInstallmentBatch(), 200);
        Test.stopTest();

        List<Installment__c> installments = [
            SELECT Status__c, Late_Fee__c FROM Installment__c
        ];
        for (Installment__c inst : installments) {
            System.assertEquals('Overdue', inst.Status__c,
                'Installments past their due date plus grace period should be marked Overdue');
            System.assert(inst.Late_Fee__c > 0,
                'A late fee should be added to each overdue installment');
        }
    }

    @isTest
    static void testBatch_DefaultsLoanAfterThreshold() {
        Test.startTest();
        Database.executeBatch(new OverdueInstallmentBatch(), 200);
        Test.stopTest();

        List<Loan__c> loans = [SELECT Status__c FROM Loan__c];
        System.assertEquals(1, loans.size(), 'Test setup should have created exactly one loan');
        System.assertEquals('Defaulted', loans[0].Status__c,
            'A loan with all 3 installments overdue should exceed the default threshold and become Defaulted');
    }

    @isTest
    static void testBatch_NoOverdueInstallments_NoChange() {
        // Bring the installments back to a future due date - nothing should become Overdue
        List<Installment__c> installments = [SELECT Id FROM Installment__c];
        for (Installment__c inst : installments) {
            inst.Due_Date__c = Date.today().addDays(30);
        }
        update installments;

        Test.startTest();
        Database.executeBatch(new OverdueInstallmentBatch(), 200);
        Test.stopTest();

        List<Installment__c> unchanged = [SELECT Status__c FROM Installment__c];
        for (Installment__c inst : unchanged) {
            System.assertEquals('Pending', inst.Status__c,
                'Installments with a future due date should remain Pending, not become Overdue');
        }
    }
}