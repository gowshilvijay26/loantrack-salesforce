@isTest
private class LoanSummaryControllerTest {

    @isTest
    static void testGetLoanSummary_ReturnsCorrectValues() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');

        Test.startTest();
        LoanSummaryController.LoanSummaryWrapper result = LoanSummaryController.getLoanSummary(loan.Id);
        Test.stopTest();

        System.assertEquals('Active', result.status, 'Status should match the loan record');
        System.assertEquals(3000, result.outstandingAmount,
            'Outstanding amount should equal the full principal before any payments');
        System.assertEquals(0, result.progressPercent,
            'Progress should be 0% before any payments are made');
        System.assertEquals(0, result.overdueCount, 'No installments should be overdue yet');
        System.assertNotEquals(null, result.nextDueDate, 'Next due date should be populated');
    }

    @isTest
    static void testGetLoanSummary_LoanNotFound_ReturnsEmptyWrapper() {
        Test.startTest();
        LoanSummaryController.LoanSummaryWrapper result =
            LoanSummaryController.getLoanSummary(null);
        Test.stopTest();

        System.assertEquals(null, result.status,
            'A null loan Id should return an empty wrapper without throwing an exception');
    }
}