@isTest
private class LoanStatusServiceTest {

    @isTest
    static void testGetLoanStatus_ValidLoan_ReturnsCorrectData() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Active');

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/loanstatus/' + loan.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        LoanStatusService.getLoanStatus();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            'A valid loan Id should return HTTP 200');

        String body = RestContext.response.responseBody.toString();
        System.assert(body.contains('"status":"Active"'),
            'Response JSON should include the loan status');
        System.assert(body.contains('"emiAmount"'),
            'Response JSON should include the EMI amount');
    }

    @isTest
    static void testGetLoanStatus_BlankId_Returns400() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/loanstatus/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        LoanStatusService.getLoanStatus();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode,
            'A request with no loan Id in the URL should return HTTP 400');
    }

    @isTest
    static void testGetLoanStatus_InvalidId_Returns400() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/loanstatus/notARealId';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        LoanStatusService.getLoanStatus();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode,
            'A malformed loan Id should return HTTP 400, not throw an unhandled exception');
    }

    @isTest
    static void testGetLoanStatus_ValidIdFormatButNotFound_Returns404() {
        Account acc = TestDataFactory.insertAccount();
        Loan__c loan = TestDataFactory.insertLoan(acc.Id, 3000, 0, 3, 'Draft');
        Id fakeButValidLoanId = loan.Id;
        delete loan;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/loanstatus/' + fakeButValidLoanId;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        LoanStatusService.getLoanStatus();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode,
            'A well-formed Id that does not match any Loan record should return HTTP 404');
    }
}