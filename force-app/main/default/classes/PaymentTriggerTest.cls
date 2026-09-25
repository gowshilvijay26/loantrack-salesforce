@isTest
private class PaymentTriggerTest {

    @isTest
    static void testFullPayment_MarksInstallmentPaid() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');
        List<Installment__c> installments = [
            SELECT Id, EMI_Amount__c FROM Installment__c
            WHERE Loan__c = :loan.Id ORDER BY Installment_Number__c
        ];

        Test.startTest();
        TestDataFactory.insertPayment(loan.Id, installments[0].Id, installments[0].EMI_Amount__c);
        Test.stopTest();

        Installment__c updated = [
            SELECT Amount_Paid__c, Status__c, Balance_Due__c
            FROM Installment__c WHERE Id = :installments[0].Id
        ];
        System.assertEquals('Paid', updated.Status__c,
            'A payment equal to the full EMI should mark the installment as Paid');
        System.assertEquals(0, updated.Balance_Due__c,
            'Balance due should be zero after a full payment');
    }

    @isTest
    static void testPartialPayment_MarksPartiallyPaid() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');
        List<Installment__c> installments = [
            SELECT Id, EMI_Amount__c FROM Installment__c
            WHERE Loan__c = :loan.Id ORDER BY Installment_Number__c
        ];

        Test.startTest();
        TestDataFactory.insertPayment(loan.Id, installments[0].Id, 400);
        Test.stopTest();

        Installment__c updated = [
            SELECT Amount_Paid__c, Status__c FROM Installment__c WHERE Id = :installments[0].Id
        ];
        System.assertEquals('Partially Paid', updated.Status__c,
            'A payment less than the EMI amount should mark the installment as Partially Paid');
        System.assertEquals(400, updated.Amount_Paid__c,
            'Amount paid should reflect exactly what was paid');
    }

    @isTest
    static void testSpillOverPayment_AppliesToNextInstallment() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');

        Test.startTest();
        // Pay more than one installment's EMI, with no installment specified - oldest-first allocation
        TestDataFactory.insertPayment(loan.Id, null, 1500);
        Test.stopTest();

        List<Installment__c> updated = [
            SELECT Installment_Number__c, Status__c, Amount_Paid__c
            FROM Installment__c WHERE Loan__c = :loan.Id ORDER BY Installment_Number__c
        ];
        System.assertEquals('Paid', updated[0].Status__c,
            'The oldest installment should be fully paid first');
        System.assertEquals('Partially Paid', updated[1].Status__c,
            'The remaining amount should spill over and partially pay the next installment');
        System.assertEquals(500, updated[1].Amount_Paid__c,
            'The second installment should receive exactly the leftover 500');
    }

    @isTest
    static void testLoanClosesWhenFullyPaid() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');

        Test.startTest();
        TestDataFactory.insertPayment(loan.Id, null, 3000);
        Test.stopTest();

        Loan__c updatedLoan = [SELECT Status__c FROM Loan__c WHERE Id = :loan.Id];
        System.assertEquals('Closed', updatedLoan.Status__c,
            'A loan should automatically close when every installment is fully paid');
    }

    // ---------- NEGATIVE TESTS ----------

    @isTest
    static void testNegativeCase_PaymentExceedsOutstanding() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');

        Test.startTest();
        Payment__c payment = TestDataFactory.createPayment(loan.Id, null, 5000);
        Database.SaveResult result = Database.insert(payment, false);
        Test.stopTest();

        System.assert(!result.isSuccess(),
            'A payment larger than the total outstanding balance should be rejected');
        System.assert(result.getErrors()[0].getMessage().contains('outstanding'),
            'Error message should explain the payment exceeds the outstanding balance');
    }

    @isTest
    static void testNegativeCase_ZeroAmountPayment() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');

        Test.startTest();
        Payment__c payment = TestDataFactory.createPayment(loan.Id, null, 0);
        Database.SaveResult result = Database.insert(payment, false);
        Test.stopTest();

        System.assert(!result.isSuccess(), 'A payment of 0 should be rejected');
    }

    @isTest
    static void testNegativeCase_LoanWithNoSchedule() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 100000, 12, 12, 'Draft'); // no installments exist

        Test.startTest();
        Payment__c payment = TestDataFactory.createPayment(loan.Id, null, 1000);
        Database.SaveResult result = Database.insert(payment, false);
        Test.stopTest();

        System.assert(!result.isSuccess(),
            'A payment on a loan with no installment schedule should be rejected');
        System.assert(result.getErrors()[0].getMessage().contains('Activate'),
            'Error message should tell the user to activate the loan first');
    }

    // ---------- BULK TEST ----------

    @isTest
    static void testBulk_200Payments_AcrossManyLoans() {
        Account acc = TestDataFactory.insertAccount();

        // Build all 200 Draft loans first, then flip to Active and insert ONCE
        List<Loan__c> loans = TestDataFactory.createLoans(acc.Id, 200, 1000, 0, 1, 'Draft');
        for (Loan__c loan : loans) {
            loan.Status__c = 'Active';
            loan.Disbursement_Date__c = Date.today();
            loan.First_EMI_Date__c = Date.today().addMonths(1);
        }
        insert loans; // ONE DML - LoanTrigger creates 1 installment per loan (tenure = 1)

        Map<Id, Installment__c> installmentByLoan = new Map<Id, Installment__c>();
        for (Installment__c inst : [
            SELECT Id, Loan__c, EMI_Amount__c FROM Installment__c WHERE Loan__c IN :loans
        ]) {
            installmentByLoan.put(inst.Loan__c, inst);
        }

        List<Payment__c> payments = new List<Payment__c>();
        for (Loan__c loan : loans) {
            Installment__c inst = installmentByLoan.get(loan.Id);
            payments.add(TestDataFactory.createPayment(loan.Id, inst.Id, inst.EMI_Amount__c));
        }

        Test.startTest();
        insert payments; // ONE DML for all 200 payments
        Test.stopTest();

        List<Installment__c> paidInstallments = [
            SELECT Id FROM Installment__c WHERE Status__c = 'Paid' AND Loan__c IN :loans
        ];
        System.assertEquals(200, paidInstallments.size(),
            'All 200 installments across 200 different loans should be marked Paid in a single bulk payment run');
    }
}