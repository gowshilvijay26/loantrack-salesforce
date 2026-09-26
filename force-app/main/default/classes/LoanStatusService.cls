@RestResource(urlMapping='/loanstatus/*')
global with sharing class LoanStatusService {

    @HttpGet
    global static void getLoanStatus() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        // Extract the Loan Id from the URL: /loanstatus/{loanId}
        String path = req.requestURI;
        String loanId = path.substringAfterLast('/');

        if (String.isBlank(loanId)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new Map<String, String>{ 'error' => 'Loan Id is required in the URL.' })
            );
            return;
        }

                Id parsedLoanId;
        try {
            parsedLoanId = (Id) loanId;
        } catch (Exception e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new Map<String, String>{ 'error' => 'Invalid Loan Id format.' })
            );
            return;
        }

        List<Loan__c> loans = [
            SELECT Id, Name, Status__c, EMI_Amount__c, Outstanding_Amount__c
            FROM Loan__c
            WHERE Id = :parsedLoanId
            WITH USER_MODE
            LIMIT 1
        ];

        if (loans.isEmpty()) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new Map<String, String>{ 'error' => 'Loan not found.' })
            );
            return;
        }

        Loan__c loan = loans[0];

        Date nextDueDate = null;
        List<Installment__c> nextInstallments = [
            SELECT Due_Date__c
            FROM Installment__c
            WHERE Loan__c = :loan.Id AND Status__c IN ('Pending', 'Partially Paid', 'Overdue')
            WITH USER_MODE
            ORDER BY Due_Date__c ASC
            LIMIT 1
        ];
        if (!nextInstallments.isEmpty()) {
            nextDueDate = nextInstallments[0].Due_Date__c;
        }

        Map<String, Object> body = new Map<String, Object>{
            'loanName' => loan.Name,
            'status' => loan.Status__c,
            'emiAmount' => loan.EMI_Amount__c,
            'outstandingAmount' => loan.Outstanding_Amount__c,
            'nextDueDate' => nextDueDate
        };

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(body));
    }
}