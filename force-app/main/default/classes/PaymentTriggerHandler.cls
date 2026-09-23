public with sharing class PaymentTriggerHandler {

    public static void afterInsert(List<Payment__c> payments) {

        // 1. Which loans are involved?
        Set<Id> loanIds = new Set<Id>();
        for (Payment__c p : payments) {
            loanIds.add(p.Loan__c);
        }

        // 2. ONE query: all installments of those loans, oldest due date first
        Map<Id, List<Installment__c>> scheduleByLoan = new Map<Id, List<Installment__c>>();
        for (Installment__c inst : [
            SELECT Id, Loan__c, Due_Date__c, EMI_Amount__c, Late_Fee__c,
                   Amount_Paid__c, Status__c, Paid_Date__c
            FROM Installment__c
            WHERE Loan__c IN :loanIds
            ORDER BY Loan__c, Due_Date__c, Installment_Number__c
        ]) {
            if (!scheduleByLoan.containsKey(inst.Loan__c)) {
                scheduleByLoan.put(inst.Loan__c, new List<Installment__c>());
            }
            scheduleByLoan.get(inst.Loan__c).add(inst);
        }

        // 3. Apply each payment in memory (no SOQL/DML inside this loop)
        Map<Id, Installment__c> changedInstallments = new Map<Id, Installment__c>();
        Set<Id> touchedLoanIds = new Set<Id>();

        for (Payment__c p : payments) {
            if (p.Amount__c == null || p.Amount__c <= 0) {
                p.addError('Payment amount must be greater than 0.');
                continue;
            }

            List<Installment__c> schedule = scheduleByLoan.get(p.Loan__c);
            if (schedule == null || schedule.isEmpty()) {
                p.addError('This loan has no installment schedule. Activate the loan first.');
                continue;
            }

            // Reject payments bigger than what is still owed
            Decimal outstanding = 0;
            for (Installment__c inst : schedule) {
                outstanding += balanceDue(inst);
            }
            if (p.Amount__c > outstanding) {
                p.addError('Payment is more than the outstanding balance (' + outstanding + ').');
                continue;
            }

            // Order: the chosen installment first, then the rest oldest-first
            List<Installment__c> order = new List<Installment__c>();
            if (p.Installment__c != null) {
                for (Installment__c inst : schedule) {
                    if (inst.Id == p.Installment__c) {
                        order.add(inst);
                    }
                }
                if (order.isEmpty()) {
                    p.addError('The selected installment does not belong to this loan.');
                    continue;
                }
            }
            for (Installment__c inst : schedule) {
                if (inst.Id != p.Installment__c) {
                    order.add(inst);
                }
            }

            // Allocate the money
            Decimal remaining = p.Amount__c;
            for (Installment__c inst : order) {
                if (remaining <= 0) {
                    break;
                }
                Decimal due = balanceDue(inst);
                if (due <= 0) {
                    continue;
                }
                Decimal applied = (remaining < due) ? remaining : due;
                inst.Amount_Paid__c = nz(inst.Amount_Paid__c) + applied;
                remaining -= applied;

                if (balanceDue(inst) <= 0) {
                    inst.Status__c = 'Paid';
                    inst.Paid_Date__c = (p.Payment_Date__c != null) ? p.Payment_Date__c : Date.today();
                } else {
                    inst.Status__c = 'Partially Paid';
                }
                changedInstallments.put(inst.Id, inst);
            }
            touchedLoanIds.add(p.Loan__c);
        }

        // 4. ONE update for all installments (only the 3 fields we change)
        if (!changedInstallments.isEmpty()) {
            List<Installment__c> toUpdate = new List<Installment__c>();
            for (Installment__c inst : changedInstallments.values()) {
                toUpdate.add(new Installment__c(
                    Id = inst.Id,
                    Amount_Paid__c = inst.Amount_Paid__c,
                    Status__c = inst.Status__c,
                    Paid_Date__c = inst.Paid_Date__c
                ));
            }
            try {
                update toUpdate;
            } catch (DmlException e) {
                String detail = e.getMessage();
                for (Integer i = 0; i < e.getNumDml(); i++) {
                    detail += ' | ' + e.getDmlType(i)
                            + ' | fields=' + e.getDmlFieldNames(i)
                            + ' | ' + e.getDmlMessage(i);
                }
                for (Payment__c p : payments) {
                    p.addError(detail);
                }
                return;
            }
        }

        // 5. Loans where every installment is Paid -> Closed
        Set<Id> paidOffLoanIds = new Set<Id>();
        for (Id loanId : touchedLoanIds) {
            Boolean allPaid = true;
            for (Installment__c inst : scheduleByLoan.get(loanId)) {
                if (inst.Status__c != 'Paid') {
                    allPaid = false;
                    break;
                }
            }
            if (allPaid) {
                paidOffLoanIds.add(loanId);
            }
        }
        if (!paidOffLoanIds.isEmpty()) {
            List<Loan__c> loansToClose = [
                SELECT Id, Status__c FROM Loan__c
                WHERE Id IN :paidOffLoanIds AND Status__c IN ('Active', 'Defaulted')
            ];
            for (Loan__c loan : loansToClose) {
                loan.Status__c = 'Closed';
            }
            if (!loansToClose.isEmpty()) {
                update loansToClose;
            }
        }

        // 6. Recalculate Account rollups for every loan touched by this payment run
        AccountRollupQueueable.enqueueForLoans(touchedLoanIds);
    }

    // ---------- helpers ----------
    private static Decimal nz(Decimal value) {
        return (value == null) ? 0 : value;
    }

    private static Decimal balanceDue(Installment__c inst) {
        return nz(inst.EMI_Amount__c) + nz(inst.Late_Fee__c) - nz(inst.Amount_Paid__c);
    }
}