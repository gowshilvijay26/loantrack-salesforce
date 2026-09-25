@isTest
private class LoanTriggerTest {

    @isTest
    static void testActivateLoan_CreatesInstallmentSchedule() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 100000, 12, 12, 'Draft');

        Test.startTest();
        loan.First_EMI_Date__c = Date.today().addMonths(1);
        loan.Disbursement_Date__c = Date.today();
        loan.Status__c = 'Active';
        update loan;
        Test.stopTest();

        Loan__c updatedLoan = [SELECT EMI_Amount__c FROM Loan__c WHERE Id = :loan.Id];
        System.assertEquals(8884.88, updatedLoan.EMI_Amount__c,
            'EMI should be calculated and stored on the loan when it becomes Active');

        List<Installment__c> installments = [
            SELECT Installment_Number__c, Principal_Component__c, Interest_Component__c, EMI_Amount__c
            FROM Installment__c WHERE Loan__c = :loan.Id ORDER BY Installment_Number__c
        ];
        System.assertEquals(12, installments.size(),
            'A 12-month loan should create exactly 12 installments');

        Decimal totalPrincipal = 0;
        for (Installment__c inst : installments) {
            totalPrincipal += inst.Principal_Component__c;
        }
        System.assertEquals(100000, totalPrincipal.setScale(0),
            'The sum of all principal components should equal the original loan principal (balance ends at zero)');
    }

    @isTest
    static void testActivateLoan_ZeroRate() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 120000, 0, 12, 'Draft');

        Test.startTest();
        loan.First_EMI_Date__c = Date.today().addMonths(1);
        loan.Disbursement_Date__c = Date.today();
        loan.Status__c = 'Active';
        update loan;
        Test.stopTest();

        List<Installment__c> installments = [
            SELECT EMI_Amount__c FROM Installment__c WHERE Loan__c = :loan.Id
        ];
        System.assertEquals(12, installments.size(), '0% interest loan should still create 12 installments');
        System.assertEquals(10000.00, installments[0].EMI_Amount__c,
            '0% interest EMI should be a simple division: 120000 / 12 = 10000');
    }

    @isTest
    static void testRecursionGuard_NoDuplicateSchedule() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 100000, 12, 12, 'Draft');

        Test.startTest();
        loan.First_EMI_Date__c = Date.today().addMonths(1);
        loan.Disbursement_Date__c = Date.today();
        loan.Status__c = 'Active';
        update loan;

        // Update the same already-Active loan again (different field) - schedule must not duplicate
        loan.Disbursement_Date__c = Date.today().addDays(1);
        update loan;
        Test.stopTest();

        List<Installment__c> installments = [SELECT Id FROM Installment__c WHERE Loan__c = :loan.Id];
        System.assertEquals(12, installments.size(),
            'Updating an already-Active loan again must not create a second, duplicate schedule');
    }

    // ---------- NEGATIVE TESTS ----------

    @isTest
    static void testNegativeCase_MissingFirstEmiDate() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 100000, 12, 12, 'Draft');

        Test.startTest();
        loan.Status__c = 'Active'; // First_EMI_Date__c intentionally left blank
        Database.SaveResult result = Database.update(loan, false);
        Test.stopTest();

        System.assert(!result.isSuccess(),
            'Activating a loan without a First EMI Date should fail');
        System.assert(result.getErrors()[0].getMessage().contains('First EMI Date'),
            'Error message should mention the missing First EMI Date');
    }

    @isTest
    static void testNegativeCase_PrincipalLockedAfterActive() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 100000, 12, 12, 'Draft');
        loan.First_EMI_Date__c = Date.today().addMonths(1);
        loan.Disbursement_Date__c = Date.today();
        loan.Status__c = 'Active';
        update loan;

        Test.startTest();
        loan.Principal_Amount__c = 200000;
        Database.SaveResult result = Database.update(loan, false);
        Test.stopTest();

        System.assert(!result.isSuccess(),
            'Changing the principal amount after a loan is Active should be blocked by the validation rule');
    }

    // ---------- BULK TEST ----------

    @isTest
    static void testBulk_200Loans_ActivatedTogether() {
        Account acc = TestDataFactory.insertAccount();
        List<Loan__c> loans = TestDataFactory.insertLoans(acc.Id, 200, 50000, 10, 6, 'Draft');

        for (Loan__c loan : loans) {
            loan.First_EMI_Date__c = Date.today().addMonths(1);
            loan.Disbursement_Date__c = Date.today();
            loan.Status__c = 'Active';
        }

        Test.startTest();
        update loans;
        Test.stopTest();

        List<Installment__c> allInstallments = [
            SELECT Id FROM Installment__c WHERE Loan__c IN :loans
        ];
        System.assertEquals(200 * 6, allInstallments.size(),
            'Activating 200 loans with a 6-month tenure should create exactly 1200 installments in bulk, without hitting governor limits');
    }
}