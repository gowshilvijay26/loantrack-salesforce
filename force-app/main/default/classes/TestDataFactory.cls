@isTest
public class TestDataFactory {

    // ---------- ACCOUNTS ----------
    public static List<Account> createAccounts(Integer count) {
        List<Account> accs = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accs.add(new Account(
                Name = 'Test Client ' + i,
                Primary_Email__c = 'testclient' + i + '@loantrackdemo.test'
            ));
        }
        return accs;
    }

    public static List<Account> insertAccounts(Integer count) {
        List<Account> accs = createAccounts(count);
        insert accs;
        return accs;
    }

    public static Account insertAccount() {
        return insertAccounts(1)[0];
    }

    // ---------- LOANS ----------
    public static Loan__c createLoan(Id accountId, Decimal principal, Decimal rate, Integer tenure, String status) {
        Loan__c loan = new Loan__c(
            Client__c = accountId,
            Principal_Amount__c = principal,
            Interest_Rate__c = rate,
            Tenure_Months__c = tenure,
            Status__c = status
        );
        if (status == 'Active') {
            loan.Disbursement_Date__c = Date.today();
            loan.First_EMI_Date__c = Date.today().addMonths(1);
        }
        return loan;
    }

    public static List<Loan__c> createLoans(Id accountId, Integer count, Decimal principal, Decimal rate,
                                             Integer tenure, String status) {
        List<Loan__c> loans = new List<Loan__c>();
        for (Integer i = 0; i < count; i++) {
            loans.add(createLoan(accountId, principal, rate, tenure, status));
        }
        return loans;
    }

    public static Loan__c insertLoan(Id accountId, Decimal principal, Decimal rate, Integer tenure, String status) {
        Loan__c loan = createLoan(accountId, principal, rate, tenure, status);
        insert loan;
        return loan;
    }

    public static List<Loan__c> insertLoans(Id accountId, Integer count, Decimal principal, Decimal rate,
                                             Integer tenure, String status) {
        List<Loan__c> loans = createLoans(accountId, count, principal, rate, tenure, status);
        insert loans;
        return loans;
    }

    // ---------- INSTALLMENTS ----------
    // Note: Installment__c is Master-Detail to Loan__c, so the Loan just needs to
    // exist (any status) - inserting installments directly does not go through LoanTrigger.
    public static Installment__c createInstallment(Id loanId, Integer installmentNumber, Date dueDate,
                                                     Decimal emiAmount, String status) {
        return new Installment__c(
            Loan__c = loanId,
            Installment_Number__c = installmentNumber,
            Due_Date__c = dueDate,
            EMI_Amount__c = emiAmount,
            Principal_Component__c = emiAmount * 0.8,
            Interest_Component__c = emiAmount * 0.2,
            Amount_Paid__c = 0,
            Late_Fee__c = 0,
            Status__c = status
        );
    }

    public static List<Installment__c> createInstallments(Id loanId, Integer count, Date firstDueDate,
                                                            Decimal emiAmount, String status) {
        List<Installment__c> rows = new List<Installment__c>();
        for (Integer i = 1; i <= count; i++) {
            rows.add(createInstallment(loanId, i, firstDueDate.addMonths(i - 1), emiAmount, status));
        }
        return rows;
    }

    public static List<Installment__c> insertInstallments(Id loanId, Integer count, Date firstDueDate,
                                                            Decimal emiAmount, String status) {
        List<Installment__c> rows = createInstallments(loanId, count, firstDueDate, emiAmount, status);
        insert rows;
        return rows;
    }

    // ---------- PAYMENTS ----------
    public static Payment__c createPayment(Id loanId, Id installmentId, Decimal amount) {
        return new Payment__c(
            Loan__c = loanId,
            Installment__c = installmentId,
            Amount__c = amount,
            Payment_Date__c = Date.today(),
            Payment_Mode__c = 'UPI'
        );
    }

    public static Payment__c insertPayment(Id loanId, Id installmentId, Decimal amount) {
        Payment__c p = createPayment(loanId, installmentId, amount);
        insert p;
        return p;
    }
}