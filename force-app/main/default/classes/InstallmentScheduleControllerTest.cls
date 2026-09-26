@isTest
private class InstallmentScheduleControllerTest {

    @isTest
    static void testGetInstallments_ReturnsRowsWithCorrectBadges() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');

        Test.startTest();
        List<InstallmentScheduleController.InstallmentRow> rows =
            InstallmentScheduleController.getInstallments(loan.Id);
        Test.stopTest();

        System.assertEquals(3, rows.size(), 'A 3-month loan should return 3 installment rows');
        System.assertEquals('inverse', rows[0].badgeVariant,
            'A Pending installment should map to the inverse badge variant');
    }

    @isTest
    static void testRecordPayment_CreatesPaymentAndUpdatesInstallment() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');
        Installment__c inst = [
            SELECT Id, EMI_Amount__c FROM Installment__c WHERE Loan__c = :loan.Id
            ORDER BY Installment_Number__c LIMIT 1
        ];

        Test.startTest();
        InstallmentScheduleController.recordPayment(inst.Id, loan.Id, inst.EMI_Amount__c, 'UPI');
        Test.stopTest();

        Installment__c updated = [SELECT Status__c FROM Installment__c WHERE Id = :inst.Id];
        System.assertEquals('Paid', updated.Status__c,
            'Recording a full payment through the controller should mark the installment Paid');

        List<Payment__c> payments = [SELECT Id, Amount__c FROM Payment__c WHERE Installment__c = :inst.Id];
        System.assertEquals(1, payments.size(), 'Exactly one Payment record should be created');
    }

    @isTest
    static void testRecordPayment_ZeroAmount_ThrowsError() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');
        Installment__c inst = [SELECT Id FROM Installment__c WHERE Loan__c = :loan.Id LIMIT 1];

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            InstallmentScheduleController.recordPayment(inst.Id, loan.Id, 0, 'UPI');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Recording a payment of 0 should throw an AuraHandledException');
    }
}