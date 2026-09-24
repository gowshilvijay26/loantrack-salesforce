public with sharing class InstallmentScheduleController {

    public class InstallmentRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal installmentNumber;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal emiAmount;
        @AuraEnabled public Decimal amountPaid;
        @AuraEnabled public Decimal balanceDue;
        @AuraEnabled public String status;
        @AuraEnabled public String badgeVariant;
    }

    @AuraEnabled(cacheable=true)
    public static List<InstallmentRow> getInstallments(Id loanId) {
        List<InstallmentRow> rows = new List<InstallmentRow>();

        for (Installment__c inst : [
            SELECT Id, Name, Installment_Number__c, Due_Date__c, EMI_Amount__c,
                   Amount_Paid__c, Balance_Due__c, Status__c
            FROM Installment__c
            WHERE Loan__c = :loanId
            WITH USER_MODE
            ORDER BY Installment_Number__c ASC
        ]) {
            InstallmentRow row = new InstallmentRow();
            row.id = inst.Id;
            row.name = inst.Name;
            row.installmentNumber = inst.Installment_Number__c;
            row.dueDate = inst.Due_Date__c;
            row.emiAmount = inst.EMI_Amount__c;
            row.amountPaid = inst.Amount_Paid__c;
            row.balanceDue = inst.Balance_Due__c;
            row.status = inst.Status__c;
            row.badgeVariant = mapBadgeVariant(inst.Status__c);
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled
    public static void recordPayment(Id installmentId, Id loanId, Decimal amount, String paymentMode) {
        if (amount == null || amount <= 0) {
            throw new AuraHandledException('Payment amount must be greater than 0.');
        }

        Payment__c payment = new Payment__c(
            Loan__c = loanId,
            Installment__c = installmentId,
            Amount__c = amount,
            Payment_Date__c = Date.today(),
            Payment_Mode__c = paymentMode
        );

        try {
            insert payment;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    private static String mapBadgeVariant(String status) {
        if (status == 'Paid') return 'success';
        if (status == 'Overdue') return 'error';
        if (status == 'Partially Paid') return 'warning';
        return 'inverse'; // Pending
    }
}