public with sharing class LoanSummaryController {

    public class LoanSummaryWrapper {
        @AuraEnabled public Decimal outstandingAmount;
        @AuraEnabled public Decimal totalPayable;
        @AuraEnabled public Decimal totalPaid;
        @AuraEnabled public Decimal progressPercent;
        @AuraEnabled public Date nextDueDate;
        @AuraEnabled public Integer overdueCount;
        @AuraEnabled public String status;
    }

    @AuraEnabled(cacheable=true)
    public static LoanSummaryWrapper getLoanSummary(Id loanId) {
        LoanSummaryWrapper result = new LoanSummaryWrapper();

        List<Loan__c> loans = [
            SELECT Id, Status__c, Outstanding_Amount__c, Total_Payable__c, Total_Paid__c,
                   Overdue_Installments__c
            FROM Loan__c
            WHERE Id = :loanId
            WITH USER_MODE
            LIMIT 1
        ];
        if (loans.isEmpty()) {
            return result;
        }
        Loan__c loan = loans[0];

        result.status = loan.Status__c;
        result.outstandingAmount = nz(loan.Outstanding_Amount__c);
        result.totalPayable = nz(loan.Total_Payable__c);
        result.totalPaid = nz(loan.Total_Paid__c);
        result.overdueCount = (loan.Overdue_Installments__c == null)
                ? 0 : Integer.valueOf(loan.Overdue_Installments__c);

        result.progressPercent = (result.totalPayable == 0)
                ? 0
                : (result.totalPaid / result.totalPayable * 100).setScale(0);

        List<Installment__c> nextInstallments = [
            SELECT Due_Date__c
            FROM Installment__c
            WHERE Loan__c = :loanId AND Status__c IN ('Pending', 'Partially Paid', 'Overdue')
            WITH USER_MODE
            ORDER BY Due_Date__c ASC
            LIMIT 1
        ];
        if (!nextInstallments.isEmpty()) {
            result.nextDueDate = nextInstallments[0].Due_Date__c;
        }

        return result;
    }

    private static Decimal nz(Decimal value) {
        return (value == null) ? 0 : value;
    }
}